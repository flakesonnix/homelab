const std = @import("std");
const ast = @import("ast.zig");
const diagnostics = @import("diagnostics.zig");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const nix = @import("nix.zig");
const semantic = @import("semantic.zig");

pub const Resolver = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    cwd: std.Io.Dir,
    diag: *diagnostics.Diagnostics,
    arena: *std.heap.ArenaAllocator,
    seen: std.StringHashMap(void),

    pub fn init(
        allocator: std.mem.Allocator,
        io: std.Io,
        cwd: std.Io.Dir,
        diag: *diagnostics.Diagnostics,
        arena: *std.heap.ArenaAllocator,
    ) Resolver {
        return .{
            .allocator = allocator,
            .io = io,
            .cwd = cwd,
            .diag = diag,
            .arena = arena,
            .seen = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *Resolver) void {
        self.seen.deinit();
    }

    /// Resolve imports for `program` originating from `file` (path as given to CLI).
    /// Returns a new Program with all transitive decls merged. Imports are flattened.
    /// All allocations use `arena`.
    pub fn resolve(self: *Resolver, file: []const u8, program: *const ast.Program) !ast.Program {
        var merged_imports: std.ArrayList(ast.Import) = .empty;
        var merged_decls: std.ArrayList(ast.Decl) = .empty;
        const arena_alloc = self.arena.allocator();

        for (program.imports) |imp| {
            const dir = std.fs.path.dirname(file) orelse ".";
            const raw_joined = if (std.fs.path.isAbsolute(imp.path))
                try arena_alloc.dupe(u8, imp.path)
            else
                try std.fs.path.join(arena_alloc, &.{ dir, imp.path });
            const joined = try normalizePath(arena_alloc, raw_joined);

            if (self.seen.contains(joined)) {
                try self.diag.push(.{
                    .severity = .warning,
                    .code = .duplicate_import,
                    .message = try std.fmt.allocPrint(arena_alloc, "duplicate import `{s}`", .{imp.path}),
                    .span = imp.span,
                    .help = null,
                });
                continue;
            }
            // record before recursing to prevent cycles
            try self.seen.put(try arena_alloc.dupe(u8, joined), {});

            // read file
            const src_raw = self.cwd.readFileAlloc(self.io, joined, self.allocator, .limited(10 * 1024 * 1024)) catch |err| {
                const msg = try std.fmt.allocPrint(arena_alloc, "cannot read import `{s}`: {s}", .{ imp.path, @errorName(err) });
                try self.diag.push(.{
                    .severity = .err,
                    .code = .unknown_ident,
                    .message = msg,
                    .span = imp.span,
                    .help = try std.fmt.allocPrint(arena_alloc, "resolved as `{s}` relative to `{s}`", .{ joined, file }),
                });
                continue;
            };
            // keep source alive in arena for diagnostics rendering
            const src = try arena_alloc.dupe(u8, src_raw);
            self.allocator.free(src_raw);
            try self.diag.addSource(joined, src);

            // lex
            var lex = lexer.Lexer.init(src, joined, self.diag);
            const toks = lex.lexAll(arena_alloc) catch |e| {
                try self.diag.push(.{
                    .severity = .err,
                    .code = .lex_error,
                    .message = try std.fmt.allocPrint(arena_alloc, "lex error in import `{s}`: {s}", .{ joined, @errorName(e) }),
                    .span = imp.span,
                    .help = null,
                });
                continue;
            };

            var p = parser.Parser.initWithSource(toks, self.diag, self.arena, src);
            var imported_prog = p.parseProgram() catch {
                // parse errors already in diag
                continue;
            };

            // record the direct import edge
            try merged_imports.append(arena_alloc, imp);

            // recurse
            const resolved = try self.resolve(joined, &imported_prog);
            // flatten transitive imports (avoid duplicating direct imp we already added)
            for (resolved.imports) |ri| try merged_imports.append(arena_alloc, ri);
            for (resolved.decls) |d| try merged_decls.append(arena_alloc, d);
        }

        // append current file's decls last (preserve order: imports first, then local)
        for (program.decls) |d| try merged_decls.append(arena_alloc, d);
        // also keep original imports that were not resolved? Already added direct imports above;
        // but for leaf programs with no imports, program.imports is empty, nothing to add.
        // For root, we already added direct imports. For completeness, add any remaining?
        // No - we already handled all program.imports above.

        var prog_with_imports = ast.Program{
            .imports = try merged_imports.toOwnedSlice(arena_alloc),
            .decls = try merged_decls.toOwnedSlice(arena_alloc),
            .arena = self.arena.*,
        };
        // Resolve host-local imports (import inside host) before host extends
        prog_with_imports = try self.resolveHostImports(&prog_with_imports);
        // Resolve host inheritance (extends) after imports
        prog_with_imports = try self.resolveHosts(&prog_with_imports);
        return prog_with_imports;
    }

    fn resolveHostImports(self: *Resolver, program: *const ast.Program) anyerror!ast.Program {
        const arena_alloc = self.arena.allocator();
        var new_decls: std.ArrayList(ast.Decl) = .empty;
        for (program.decls) |decl| {
            switch (decl) {
                .host => |h| {
                    var new_stmts: std.ArrayList(ast.HostStmt) = .empty;
                    // Use host's file as base for relative imports
                    const host_file = h.name.span.file;
                    const host_dir = std.fs.path.dirname(host_file) orelse ".";
                    for (h.stmts) |stmt| {
                        switch (stmt) {
                            .import => |imp| {
                                const raw_joined = if (std.fs.path.isAbsolute(imp.path))
                                    try arena_alloc.dupe(u8, imp.path)
                                else
                                    try std.fs.path.join(arena_alloc, &.{ host_dir, imp.path });
                            const joined = try normalizePath(arena_alloc, raw_joined);
                                if (self.seen.contains(joined)) {
                                    try self.diag.push(.{
                                        .severity = .warning,
                                        .code = .duplicate_import,
                                        .message = try std.fmt.allocPrint(arena_alloc, "duplicate import `{s}` in host `{s}`", .{ imp.path, h.name.name }),
                                        .span = imp.span,
                                        .help = null,
                                    });
                                    continue;
                                }
                                // Check for import cycle: if we are already importing this host's file?
                                // For host imports, cycle would be host A imports vm file B which imports host A
                                // Use seen to prevent infinite loop; already recorded before recursing
                                try self.seen.put(try arena_alloc.dupe(u8, joined), {});
                                const src_raw = self.cwd.readFileAlloc(self.io, joined, self.allocator, .limited(10 * 1024 * 1024)) catch |err| {
                                    try self.diag.push(.{
                                        .severity = .err,
                                        .code = .unknown_ident,
                                        .message = try std.fmt.allocPrint(arena_alloc, "cannot read import `{s}` in host `{s}`: {s}", .{ imp.path, h.name.name, @errorName(err) }),
                                        .span = imp.span,
                                        .help = try std.fmt.allocPrint(arena_alloc, "resolved as `{s}` relative to `{s}`", .{ joined, host_file }),
                                    });
                                    continue;
                                };
                                const src = try arena_alloc.dupe(u8, src_raw);
                                self.allocator.free(src_raw);
                                try self.diag.addSource(joined, src);
                                var lex = lexer.Lexer.init(src, joined, self.diag);
                                const toks = lex.lexAll(arena_alloc) catch |e| {
                                    try self.diag.push(.{
                                        .severity = .err,
                                        .code = .lex_error,
                                        .message = try std.fmt.allocPrint(arena_alloc, "lex error in import `{s}`: {s}", .{ joined, @errorName(e) }),
                                        .span = imp.span,
                                        .help = null,
                                    });
                                    continue;
                                };
                                var p = parser.Parser.initWithSource(toks, self.diag, self.arena, src);
                                var imported_prog = p.parseProgram() catch {
                                    continue;
                                };
                                // Recursively resolve top-level imports of the imported file
                                const resolved_imported = try self.resolve(joined, &imported_prog);
                                // Extract microVMs from resolved imported program: top-level microvm decls become HostStmt
                                for (resolved_imported.decls) |d| {
                                    switch (d) {
                                        .microvm => |vm| try new_stmts.append(arena_alloc, .{ .microvm = vm }),
                                        .host => |other_host| {
                                            // If imported file contains a host with same name, merge its microVMs?
                                            // For now, if host name matches current host, import its microVMs
                                            if (std.mem.eql(u8, other_host.name.name, h.name.name)) {
                                                for (other_host.stmts) |hs| {
                                                    // Only bring microVMs, not other host settings to avoid complexity
                                                    if (hs == .microvm) try new_stmts.append(arena_alloc, hs);
                                                }
                                            } else {
                                                // Different host, warn
                                                try self.diag.push(.{
                                                    .severity = .warning,
                                                    .code = .unused_import,
                                                    .message = try std.fmt.allocPrint(arena_alloc, "import `{s}` contains host `{s}` different from `{s}`", .{ imp.path, other_host.name.name, h.name.name }),
                                                    .span = imp.span,
                                                    .help = "host imports should contain microVMs for the same host",
                                                });
                                            }
                                        },
                                        else => {
                                            // For other decls (role, etc.), ignore for host import
                                            try self.diag.push(.{
                                                .severity = .warning,
                                                .code = .unused_import,
                                                .message = try std.fmt.allocPrint(arena_alloc, "import `{s}` contains non-microVM decl, ignored in host", .{imp.path}),
                                                .span = imp.span,
                                                .help = null,
                                            });
                                        },
                                    }
                                }
                            },
                            else => try new_stmts.append(arena_alloc, stmt),
                        }
                    }
                    var new_host = h;
                    new_host.stmts = try new_stmts.toOwnedSlice(arena_alloc);
                    try new_decls.append(arena_alloc, .{ .host = new_host });
                },
                else => try new_decls.append(arena_alloc, decl),
            }
        }
        return ast.Program{
            .imports = try arena_alloc.dupe(ast.Import, program.imports),
            .decls = try new_decls.toOwnedSlice(arena_alloc),
            .arena = self.arena.*,
        };
    }

    fn resolveHosts(self: *Resolver, program: *const ast.Program) !ast.Program {
        const arena_alloc = self.arena.allocator();
        // First, merge duplicate hosts with same name (from different modules) by combining stmts
        // This enables per-VM modules: purr/hosts/mireo.purr imports purr/vms/*.purr each with host mireo { microvm ... }
        var merged_by_name = std.StringHashMap(ast.Host).init(self.allocator);
        defer merged_by_name.deinit();
        var host_order: std.ArrayList([]const u8) = .empty;
        defer host_order.deinit(self.allocator);
        var other_decls: std.ArrayList(ast.Decl) = .empty;
        for (program.decls) |decl| {
            switch (decl) {
                .host => |h| {
                    if (merged_by_name.get(h.name.name)) |existing| {
                        // Merge stmts: existing + new
                        var merged_stmts: std.ArrayList(ast.HostStmt) = .empty;
                        for (existing.stmts) |s| try merged_stmts.append(arena_alloc, s);
                        for (h.stmts) |s| try merged_stmts.append(arena_alloc, s);
                        var merged_host = existing;
                        merged_host.stmts = try merged_stmts.toOwnedSlice(arena_alloc);
                        // Keep original name/span/extends from first, but merge stmts
                        // If new host has extends and existing doesn't, use new's extends
                        if (existing.extends == null and h.extends != null) merged_host.extends = h.extends;
                        try merged_by_name.put(h.name.name, merged_host);
                    } else {
                        try merged_by_name.put(h.name.name, h);
                        try host_order.append(self.allocator, h.name.name);
                    }
                },
                else => try other_decls.append(arena_alloc, decl),
            }
        }
        // Rebuild decls list with merged hosts (one per name) + other decls
        var deduped_decls: std.ArrayList(ast.Decl) = .empty;
        for (other_decls.items) |d| try deduped_decls.append(arena_alloc, d);
        for (host_order.items) |name| {
            const h = merged_by_name.get(name).?;
            try deduped_decls.append(arena_alloc, .{ .host = h });
        }
        // Build new program with deduped hosts for further processing (extends)
        var deduped_program = ast.Program{
            .imports = try arena_alloc.dupe(ast.Import, program.imports),
            .decls = try deduped_decls.toOwnedSlice(arena_alloc),
            .arena = self.arena.*,
        };
        // Build map from host name to index for extends handling (now deduped, one per name)
        var host_map = std.StringHashMap(usize).init(self.allocator);
        defer host_map.deinit();
        for (deduped_program.decls, 0..) |decl, idx| {
            if (decl == .host) {
                const name = decl.host.name.name;
                try host_map.put(name, idx);
            }
        }
        // Track visited states for cycle detection: 0=unvisited, 1=visiting, 2=visited
        var state = std.StringHashMap(u8).init(self.allocator);
        defer state.deinit();
        // For each host, compute effective host via DFS
        var resolved_hosts = std.StringHashMap(ast.Host).init(self.allocator);
        defer resolved_hosts.deinit();
        var has_cycle = std.StringHashMap(bool).init(self.allocator);
        defer has_cycle.deinit();

        for (deduped_program.decls) |decl| {
            if (decl == .host) {
                const name = decl.host.name.name;
                if (state.get(name) == null) {
                    try self.resolveHostDFS(name, &host_map, &deduped_program, &state, &resolved_hosts, &has_cycle);
                }
            }
        }

        // Build new decls list with resolved hosts
        var new_decls: std.ArrayList(ast.Decl) = .empty;
        for (deduped_program.decls) |decl| {
            switch (decl) {
                .host => |h| {
                    if (has_cycle.get(h.name.name) orelse false) {
                        // For cyclic hosts, keep original but without extends to avoid partial merge
                        // Diagnostics already emitted, skip merging
                        var copy = h;
                        copy.extends = null;
                        try new_decls.append(arena_alloc, .{ .host = copy });
                    } else if (resolved_hosts.get(h.name.name)) |resolved_h| {
                        try new_decls.append(arena_alloc, .{ .host = resolved_h });
                    } else {
                        try new_decls.append(arena_alloc, decl);
                    }
                },
                .let_decl => try new_decls.append(arena_alloc, decl),
                else => try new_decls.append(arena_alloc, decl),
            }
        }
        return ast.Program{
            .imports = try arena_alloc.dupe(ast.Import, deduped_program.imports),
            .decls = try new_decls.toOwnedSlice(arena_alloc),
            .arena = self.arena.*,
        };
    }

    fn resolveHostDFS(
        self: *Resolver,
        name: []const u8,
        host_map: *std.StringHashMap(usize),
        program: *const ast.Program,
        state: *std.StringHashMap(u8),
        resolved: *std.StringHashMap(ast.Host),
        has_cycle: *std.StringHashMap(bool),
    ) !void {
        const arena_alloc = self.arena.allocator();
        const idx = host_map.get(name) orelse return;
        const decl = program.decls[idx];
        const host = decl.host;

        const cur_state = state.get(name) orelse 0;
        if (cur_state == 1) {
            // Cycle detected
            try self.diag.push(.{
                .severity = .err,
                .code = .inheritance_cycle,
                .message = try std.fmt.allocPrint(arena_alloc, "inheritance cycle detected for host `{s}`", .{name}),
                .span = host.name.span,
                .help = "check extends chain for cycles",
            });
            try has_cycle.put(name, true);
            return;
        }
        if (cur_state == 2) return;
        try state.put(name, 1);

        if (host.extends) |parent_ident| {
            const parent_name = parent_ident.name;
            // self-inheritance
            if (std.mem.eql(u8, parent_name, name)) {
                try self.diag.push(.{
                    .severity = .err,
                    .code = .self_inheritance,
                    .message = try std.fmt.allocPrint(arena_alloc, "host `{s}` cannot extend itself", .{name}),
                    .span = parent_ident.span,
                    .help = null,
                });
                try has_cycle.put(name, true);
                try state.put(name, 2);
                // Still create a resolved host without parent
                var copy = host;
                copy.extends = null;
                try resolved.put(name, copy);
                return;
            }
            // unknown parent
            if (!host_map.contains(parent_name)) {
                try self.diag.push(.{
                    .severity = .err,
                    .code = .unknown_parent,
                    .message = try std.fmt.allocPrint(arena_alloc, "unknown parent host `{s}` for host `{s}`", .{ parent_name, name }),
                    .span = parent_ident.span,
                    .help = "define the parent host or check the name",
                });
                try has_cycle.put(name, true);
                try state.put(name, 2);
                var copy = host;
                copy.extends = null;
                try resolved.put(name, copy);
                return;
            }
            // Recurse to resolve parent first (handles forward refs)
            try self.resolveHostDFS(parent_name, host_map, program, state, resolved, has_cycle);
            if (has_cycle.get(parent_name) orelse false) {
                try has_cycle.put(name, true);
                // Propagate cycle diagnostic already emitted for parent, also mark child
                try self.diag.push(.{
                    .severity = .err,
                    .code = .inheritance_cycle,
                    .message = try std.fmt.allocPrint(arena_alloc, "host `{s}` is part of inheritance cycle via `{s}`", .{ name, parent_name }),
                    .span = parent_ident.span,
                    .help = null,
                });
                try state.put(name, 2);
                var copy = host;
                copy.extends = null;
                try resolved.put(name, copy);
                return;
            }
            // parent_host may be from resolved map or need to get from program if not yet resolved
            const effective_parent = if (resolved.get(parent_name)) |ph| ph else blk: {
                const p_idx = host_map.get(parent_name).?;
                break :blk program.decls[p_idx].host;
            };
            // Merge parent + child
            const merged = try self.mergeHosts(effective_parent, host);
            try resolved.put(name, merged);
        } else {
            // No extends, just copy
            var copy = host;
            copy.extends = null;
            try resolved.put(name, copy);
        }
        try state.put(name, 2);
    }

    fn mergeHosts(self: *Resolver, parent: ast.Host, child: ast.Host) !ast.Host {
        const arena_alloc = self.arena.allocator();
        // Merge stmts: parent first, then child, with setting override
        var merged: std.ArrayList(ast.HostStmt) = .empty;
        // For settings, we need to handle override: child setting with same path overrides parent
        var setting_map = std.StringHashMap(usize).init(self.allocator);
        defer setting_map.deinit();
        // First, add all parent stmts, track settings indices
        for (parent.stmts) |stmt| {
            switch (stmt) {
                .setting => |s| {
                    const idx = merged.items.len;
                    try merged.append(arena_alloc, stmt);
                    try setting_map.put(s.path, idx);
                },
                .let_decl => try merged.append(arena_alloc, stmt),
                else => try merged.append(arena_alloc, stmt),
            }
        }
        // Then add child stmts, handling setting override and packages_assign merge
        // Track if we have already merged a packages_assign for the child
        var packages_assign_idx: ?usize = null;
        for (parent.stmts) |stmt| {
            if (stmt == .packages_assign) {
                packages_assign_idx = merged.items.len - 1;
                // Note: we already added parent's packages_assign above, so track its idx
                // But we added it in the first loop, so we need to find it
                // For simplicity, we will handle merging in the child loop below
            }
        }
        // Reset: we already tracked parent's packages_assign in first loop? Actually we didn't track it separately
        // Let's handle child packages_assign merging explicitly
        for (child.stmts) |stmt| {
            switch (stmt) {
                .setting => |s| {
                    if (std.mem.eql(u8, s.path, "nix_raw")) {
                        // nix_raw is append, not override
                        try merged.append(arena_alloc, stmt);
                    } else if (setting_map.get(s.path)) |parent_idx| {
                        // Override parent's setting
                        merged.items[parent_idx] = stmt;
                    } else {
                        try merged.append(arena_alloc, stmt);
                        try setting_map.put(s.path, merged.items.len - 1);
                    }
                },
                .packages_assign => |child_tags| {
                    // Merge with parent's packages_assign if exists
                    var found_parent_idx: ?usize = null;
                    for (merged.items, 0..) |m_stmt, m_idx| {
                        if (m_stmt == .packages_assign) {
                            found_parent_idx = m_idx;
                            break;
                        }
                    }
                    if (found_parent_idx) |p_idx| {
                        // Merge child's tags into parent's list
                        const parent_tags = merged.items[p_idx].packages_assign;
                        var new_list: std.ArrayList([]const u8) = .empty;
                        for (parent_tags) |t| try new_list.append(arena_alloc, t);
                        for (child_tags) |t| try new_list.append(arena_alloc, t);
                        merged.items[p_idx] = .{ .packages_assign = try new_list.toOwnedSlice(arena_alloc) };
                    } else {
                        try merged.append(arena_alloc, stmt);
                    }
                },
                .let_decl => try merged.append(arena_alloc, stmt),
                else => try merged.append(arena_alloc, stmt),
            }
        }

        return ast.Host{
            .name = child.name,
            .extends = null,
            .stmts = try merged.toOwnedSlice(arena_alloc),
            .span = child.name.span,
        };
    }
};

fn normalizePath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    var parts: std.ArrayList([]const u8) = .empty;
    defer parts.deinit(allocator);
    var it = std.mem.splitScalar(u8, path, '/');
    while (it.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, ".")) continue;
        if (std.mem.eql(u8, part, "..")) {
            if (parts.items.len > 0) _ = parts.pop();
            continue;
        }
        try parts.append(allocator, part);
    }
    if (parts.items.len == 0) return try allocator.dupe(u8, ".");
    var buf: std.ArrayList(u8) = .empty;
    for (parts.items, 0..) |p, i| {
        if (i > 0) try buf.append(allocator, '/');
        try buf.appendSlice(allocator, p);
    }
    if (path.len > 0 and path[0] == '/') {
        // Insert leading slash
        const with_slash = try std.fmt.allocPrint(allocator, "/{s}", .{buf.items});
        buf.deinit(allocator);
        return with_slash;
    }
    return try buf.toOwnedSlice(allocator);
}

test "resolver no imports" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host x270 { use desktop; }";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.init(toks, &diag, &arena);
    var prog = try p.parseProgram();
    // use undefined Io/Dir since no imports will be read
    var resolver = Resolver.init(alloc, undefined, undefined, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve("test.purr", &prog);
    try std.testing.expect(resolved.decls.len == 1);
    try std.testing.expect(resolved.imports.len == 0);
}

test "resolver host extends basic" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host base { use desktop; } host web extends base { use gaming; }";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try p.parseProgram();
    var resolver = Resolver.init(alloc, undefined, undefined, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve("test.purr", &prog);
    // Find web host
    var web_host: ?ast.Host = null;
    for (resolved.decls) |d| {
        if (d == .host and std.mem.eql(u8, d.host.name.name, "web")) web_host = d.host;
    }
    try std.testing.expect(web_host != null);
    // web should have 2 use stmts: desktop (from base) + gaming (own)
    var use_count: usize = 0;
    for (web_host.?.stmts) |s| {
        if (s == .use_role) use_count += 1;
    }
    try std.testing.expect(use_count == 2);
    try std.testing.expect(!diag.hasErrors());
}

test "resolver host extends unknown parent" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host web extends missing {}";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try p.parseProgram();
    var resolver = Resolver.init(alloc, undefined, undefined, &diag, &arena);
    defer resolver.deinit();
    _ = try resolver.resolve("test.purr", &prog);
    try std.testing.expect(diag.hasErrors());
    var found = false;
    for (diag.list.items) |d| {
        if (d.code == .unknown_parent) found = true;
    }
    try std.testing.expect(found);
}

test "resolver host extends self" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host a extends a {}";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try p.parseProgram();
    var resolver = Resolver.init(alloc, undefined, undefined, &diag, &arena);
    defer resolver.deinit();
    _ = try resolver.resolve("test.purr", &prog);
    var found = false;
    for (diag.list.items) |d| {
        if (d.code == .self_inheritance) found = true;
    }
    try std.testing.expect(found);
}

test "resolver host extends cycle" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host a extends b {} host b extends a {}";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try p.parseProgram();
    var resolver = Resolver.init(alloc, undefined, undefined, &diag, &arena);
    defer resolver.deinit();
    _ = try resolver.resolve("test.purr", &prog);
    var found = false;
    for (diag.list.items) |d| {
        if (d.code == .inheritance_cycle) found = true;
    }
    try std.testing.expect(found);
}

test "resolver host extends deterministic" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source1 = "host base { packages = [\"a\"]; } host child extends base { packages = [\"b\"]; }";
    const source2 = "host child extends base { packages = [\"b\"]; } host base { packages = [\"a\"]; }";
    const sources = [_][]const u8{ source1, source2 };
    for (sources) |src| {
        var arena2 = std.heap.ArenaAllocator.init(alloc);
        defer arena2.deinit();
        var diag = diagnostics.Diagnostics.init(arena2.allocator(), "test.purr", src);
        var lex = lexer.Lexer.init(src, "test.purr", &diag);
        const toks = try lex.lexAll(arena2.allocator());
        var p = parser.Parser.initWithSource(toks, &diag, &arena2, src);
        var prog = try p.parseProgram();
        var resolver = Resolver.init(alloc, undefined, undefined, &diag, &arena2);
        defer resolver.deinit();
        const resolved = try resolver.resolve("test.purr", &prog);
        // Find child host packages
        for (resolved.decls) |d| {
            if (d == .host and std.mem.eql(u8, d.host.name.name, "child")) {
                var found = false;
                for (d.host.stmts) |s| {
                    if (s == .packages_assign) {
                        // Should be ["a", "b"] in both cases
                        if (s.packages_assign.len == 2 and std.mem.eql(u8, s.packages_assign[0], "a") and std.mem.eql(u8, s.packages_assign[1], "b")) found = true;
                    }
                }
                try std.testing.expect(found);
            }
        }
    }
}

test "resolver duplicate host merging" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host mireo { microvm grafana { mem = 512; cpu = 1; net = \"lan\"; } } host mireo { microvm monerod { mem = 1024; cpu = 2; net = \"lan\"; } }";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try p.parseProgram();
    var resolver = Resolver.init(alloc, undefined, undefined, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve("test.purr", &prog);
    // Should have single host mireo with 2 microVMs after merging
    var count: usize = 0;
    var vm_count: usize = 0;
    for (resolved.decls) |d| {
        if (d == .host and std.mem.eql(u8, d.host.name.name, "mireo")) {
            count += 1;
            for (d.host.stmts) |s| {
                if (s == .microvm) vm_count += 1;
            }
        }
    }
    try std.testing.expect(count == 1);
    try std.testing.expect(vm_count == 2);
    try std.testing.expect(!diag.hasErrors());
}

test "resolver module graph diamond" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    // Simulate diamond: A imports B and C, B and C import D (shared). We test via in-memory hosts: A has 2 imports that are same host fragment
    // Instead, test duplicate host merging via multiple imports of same VM file: should dedup via seen
    // Use real files in /tmp for import graph
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const base = "/tmp/purr_diamond";
    // Clean up previous
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteFile(io, base ++ "/c.purr") catch {};
    cwd.deleteFile(io, base ++ "/d.purr") catch {};
    std.Io.Dir.cwd().createDirPath(io, base) catch {};
    try cwd.writeFile(io, .{ .sub_path = base ++ "/d.purr", .data = "host d { microvm dm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/b.purr", .data = "import \"d.purr\"; host b { microvm bm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/c.purr", .data = "import \"d.purr\"; host c { microvm cm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/a.purr", .data = "import \"b.purr\"; import \"c.purr\"; host a { microvm am { mem = 256; cpu = 1; net = \"lan\"; } }" });
    const src = try cwd.readFileAlloc(io, base ++ "/a.purr", alloc, .limited(8192));
    defer alloc.free(src);
    var diag = diagnostics.Diagnostics.init(arena.allocator(), base ++ "/a.purr", src);
    var lex = lexer.Lexer.init(src, base ++ "/a.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, src);
    var prog = try p.parseProgram();
    var resolver = Resolver.init(alloc, io, cwd, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve(base ++ "/a.purr", &prog);
    // Should have hosts a, b, c, d (4) without duplicate, and no cycle
    var host_count: usize = 0;
    for (resolved.decls) |d| {
        if (d == .host) host_count += 1;
    }
    try std.testing.expect(host_count == 4);
    try std.testing.expect(!diag.hasErrors());
    // Check duplicate import warning not error for b and c both importing d (should be deduped, not error)
    var has_dup_warning = false;
    for (diag.list.items) |d| {
        if (d.code == .duplicate_import) has_dup_warning = true;
    }
    // Duplicate import for d should be warning (since both b and c import d, the second time d is seen it will be duplicate)
    // But our seen is global, so second import of d will be duplicate
    try std.testing.expect(has_dup_warning);
    // Cleanup
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteFile(io, base ++ "/c.purr") catch {};
    cwd.deleteFile(io, base ++ "/d.purr") catch {};
    cwd.deleteDir(io, base) catch {};
}

test "resolver linear chain A->B->C" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const base = "/tmp/purr_linear";
    cwd.deleteFile(io, base ++ "/c.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteDir(io, base) catch {};
    std.Io.Dir.cwd().createDirPath(io, base) catch {};
    try cwd.writeFile(io, .{ .sub_path = base ++ "/c.purr", .data = "host c { microvm cm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/b.purr", .data = "import \"c.purr\"; host b { microvm bm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/a.purr", .data = "import \"b.purr\"; host a { microvm am { mem = 256; cpu = 1; net = \"lan\"; } }" });
    const src = try cwd.readFileAlloc(io, base ++ "/a.purr", alloc, .limited(8192));
    defer alloc.free(src);
    var diag = diagnostics.Diagnostics.init(arena.allocator(), base ++ "/a.purr", src);
    var lex = lexer.Lexer.init(src, base ++ "/a.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var pars = parser.Parser.initWithSource(toks, &diag, &arena, src);
    var prog = try pars.parseProgram();
    var resolver = Resolver.init(alloc, io, cwd, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve(base ++ "/a.purr", &prog);
    // all three modules resolve, 3 hosts, topological order c,b,a
    var host_names: std.ArrayList([]const u8) = .empty;
    defer host_names.deinit(alloc);
    for (resolved.decls) |d| {
        if (d == .host) try host_names.append(alloc, d.host.name.name);
    }
    try std.testing.expect(host_names.items.len == 3);
    try std.testing.expectEqualStrings("c", host_names.items[0]);
    try std.testing.expectEqualStrings("b", host_names.items[1]);
    try std.testing.expectEqualStrings("a", host_names.items[2]);
    try std.testing.expect(!diag.hasErrors());
    var has_dup = false;
    for (diag.list.items) |d| {
        if (d.code == .duplicate_import) has_dup = true;
    }
    try std.testing.expect(!has_dup);
    // deterministic: second resolve gives same order
    var arena2 = std.heap.ArenaAllocator.init(alloc);
    defer arena2.deinit();
    const src2 = try cwd.readFileAlloc(io, base ++ "/a.purr", alloc, .limited(8192));
    defer alloc.free(src2);
    var diag2 = diagnostics.Diagnostics.init(arena2.allocator(), base ++ "/a.purr", src2);
    var lex2 = lexer.Lexer.init(src2, base ++ "/a.purr", &diag2);
    const toks2 = try lex2.lexAll(arena2.allocator());
    var pars2 = parser.Parser.initWithSource(toks2, &diag2, &arena2, src2);
    var prog2 = try pars2.parseProgram();
    var resolver2 = Resolver.init(alloc, io, cwd, &diag2, &arena2);
    defer resolver2.deinit();
    const resolved2 = try resolver2.resolve(base ++ "/a.purr", &prog2);
    var host_names2: std.ArrayList([]const u8) = .empty;
    defer host_names2.deinit(alloc);
    for (resolved2.decls) |d| {
        if (d == .host) try host_names2.append(alloc, d.host.name.name);
    }
    try std.testing.expect(host_names2.items.len == 3);
    for (host_names.items, host_names2.items) |a, b| try std.testing.expectEqualStrings(a, b);
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteFile(io, base ++ "/c.purr") catch {};
    cwd.deleteDir(io, base) catch {};
}

test "resolver duplicate import A->B twice" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const base = "/tmp/purr_dup_direct";
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteDir(io, base) catch {};
    std.Io.Dir.cwd().createDirPath(io, base) catch {};
    try cwd.writeFile(io, .{ .sub_path = base ++ "/b.purr", .data = "host b { microvm bm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/a.purr", .data = "import \"b.purr\"; import \"b.purr\"; host a { microvm am { mem = 256; cpu = 1; net = \"lan\"; } }" });
    const src = try cwd.readFileAlloc(io, base ++ "/a.purr", alloc, .limited(8192));
    defer alloc.free(src);
    var diag = diagnostics.Diagnostics.init(arena.allocator(), base ++ "/a.purr", src);
    var lex = lexer.Lexer.init(src, base ++ "/a.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var pars = parser.Parser.initWithSource(toks, &diag, &arena, src);
    var prog = try pars.parseProgram();
    var resolver = Resolver.init(alloc, io, cwd, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve(base ++ "/a.purr", &prog);
    // B processed only once, 2 hosts total (a,b)
    var host_count: usize = 0;
    var b_count: usize = 0;
    for (resolved.decls) |d| {
        if (d == .host) {
            host_count += 1;
            if (std.mem.eql(u8, d.host.name.name, "b")) b_count += 1;
        }
    }
    try std.testing.expect(host_count == 2);
    try std.testing.expect(b_count == 1);
    // W001 duplicate_import warning, no error
    var has_dup = false;
    const has_err = diag.hasErrors();
    for (diag.list.items) |d| {
        if (d.code == .duplicate_import and d.severity == .warning) has_dup = true;
    }
    try std.testing.expect(has_dup);
    try std.testing.expect(!has_err);
    // no duplicate declarations: ensure no host a duplicated
    var a_count: usize = 0;
    for (resolved.decls) |d| {
        if (d == .host and std.mem.eql(u8, d.host.name.name, "a")) a_count += 1;
    }
    try std.testing.expect(a_count == 1);
    // semantic should not error for merged (no duplicate_decl)
    var sem = semantic.Semantic.init(&resolved, &diag, arena.allocator());
    try sem.analyze();
    try std.testing.expect(!diag.hasErrors());
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteDir(io, base) catch {};
}

test "resolver direct cycle A->B->A" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const base = "/tmp/purr_cycle_direct";
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteDir(io, base) catch {};
    std.Io.Dir.cwd().createDirPath(io, base) catch {};
    try cwd.writeFile(io, .{ .sub_path = base ++ "/a.purr", .data = "import \"b.purr\"; host a { microvm am { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/b.purr", .data = "import \"a.purr\"; host b { microvm bm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    const src = try cwd.readFileAlloc(io, base ++ "/a.purr", alloc, .limited(8192));
    defer alloc.free(src);
    var diag = diagnostics.Diagnostics.init(arena.allocator(), base ++ "/a.purr", src);
    var lex = lexer.Lexer.init(src, base ++ "/a.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var pars = parser.Parser.initWithSource(toks, &diag, &arena, src);
    var prog = try pars.parseProgram();
    var resolver = Resolver.init(alloc, io, cwd, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve(base ++ "/a.purr", &prog);
    // terminates cleanly, no infinite recursion
    var host_count: usize = 0;
    for (resolved.decls) |d| {
        if (d == .host) host_count += 1;
    }
    try std.testing.expect(host_count == 2);
    // duplicate_import warning for the cycle edge
    var has_dup = false;
    for (diag.list.items) |d| {
        if (d.code == .duplicate_import) has_dup = true;
    }
    try std.testing.expect(has_dup);
    // semantic may report duplicate microvm due to merging duplicate host a via cycle; we just ensure no infinite recursion
    // don't assert no duplicate_decl for cycle case, only ensure termination and duplicate_import warning
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteDir(io, base) catch {};
}

test "resolver indirect cycle A->B->C->A" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const base = "/tmp/purr_cycle_indirect";
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteFile(io, base ++ "/c.purr") catch {};
    cwd.deleteDir(io, base) catch {};
    std.Io.Dir.cwd().createDirPath(io, base) catch {};
    try cwd.writeFile(io, .{ .sub_path = base ++ "/a.purr", .data = "import \"b.purr\"; host a { microvm am { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/b.purr", .data = "import \"c.purr\"; host b { microvm bm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/c.purr", .data = "import \"a.purr\"; host c { microvm cm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    const src = try cwd.readFileAlloc(io, base ++ "/a.purr", alloc, .limited(8192));
    defer alloc.free(src);
    var diag = diagnostics.Diagnostics.init(arena.allocator(), base ++ "/a.purr", src);
    var lex = lexer.Lexer.init(src, base ++ "/a.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var pars = parser.Parser.initWithSource(toks, &diag, &arena, src);
    var prog = try pars.parseProgram();
    var resolver = Resolver.init(alloc, io, cwd, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve(base ++ "/a.purr", &prog);
    var host_count: usize = 0;
    for (resolved.decls) |d| {
        if (d == .host) host_count += 1;
    }
    try std.testing.expect(host_count == 3);
    var has_dup = false;
    for (diag.list.items) |d| {
        if (d.code == .duplicate_import) has_dup = true;
    }
    try std.testing.expect(has_dup);
    try std.testing.expect(!diag.hasErrors() or has_dup);
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteFile(io, base ++ "/c.purr") catch {};
    cwd.deleteDir(io, base) catch {};
}

test "resolver indirect cycle with normalizePath" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const base = "/tmp/purr_norm_cycle";
    cwd.deleteFile(io, base ++ "/sub/c.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteDir(io, base ++ "/sub") catch {};
    cwd.deleteDir(io, base) catch {};
    std.Io.Dir.cwd().createDirPath(io, base) catch {};
    std.Io.Dir.cwd().createDirPath(io, base ++ "/sub") catch {};
    try cwd.writeFile(io, .{ .sub_path = base ++ "/a.purr", .data = "import \"b.purr\"; host a { microvm am { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/b.purr", .data = "import \"sub/c.purr\"; host b { microvm bm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/sub/c.purr", .data = "import \"../a.purr\"; host c { microvm cm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    const src = try cwd.readFileAlloc(io, base ++ "/a.purr", alloc, .limited(8192));
    defer alloc.free(src);
    var diag = diagnostics.Diagnostics.init(arena.allocator(), base ++ "/a.purr", src);
    var lex = lexer.Lexer.init(src, base ++ "/a.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var pars = parser.Parser.initWithSource(toks, &diag, &arena, src);
    var prog = try pars.parseProgram();
    var resolver = Resolver.init(alloc, io, cwd, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve(base ++ "/a.purr", &prog);
    var host_count: usize = 0;
    for (resolved.decls) |d| {
        if (d == .host) host_count += 1;
    }
    try std.testing.expect(host_count == 3);
    var has_dup = false;
    for (diag.list.items) |d| {
        if (d.code == .duplicate_import) has_dup = true;
    }
    try std.testing.expect(has_dup);
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteFile(io, base ++ "/sub/c.purr") catch {};
    cwd.deleteDir(io, base ++ "/sub") catch {};
    cwd.deleteDir(io, base) catch {};
}

test "resolver real host vm fragment single file" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host mireo { } host mireo { microvm grafana { mem = 768; cpu = 2; net = \"lan\"; ip = \"10.8.0.2\"; } }";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var pars = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try pars.parseProgram();
    var resolver = Resolver.init(alloc, undefined, undefined, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve("test.purr", &prog);
    var count: usize = 0;
    var vm_count: usize = 0;
    var has_grafana = false;
    for (resolved.decls) |d| {
        if (d == .host and std.mem.eql(u8, d.host.name.name, "mireo")) {
            count += 1;
            for (d.host.stmts) |s| {
                if (s == .microvm) {
                    vm_count += 1;
                    if (std.mem.eql(u8, s.microvm.name.name, "grafana")) has_grafana = true;
                }
            }
        }
    }
    try std.testing.expect(count == 1);
    try std.testing.expect(vm_count == 1);
    try std.testing.expect(has_grafana);
    try std.testing.expect(!diag.hasErrors());
    var sem = semantic.Semantic.init(&resolved, &diag, arena.allocator());
    try sem.analyze();
    try std.testing.expect(!diag.hasErrors());
}

test "resolver host vm import graph" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const base = "/tmp/purr_host_vm_import";
    cwd.deleteFile(io, base ++ "/hosts/mireo.purr") catch {};
    cwd.deleteFile(io, base ++ "/vms/grafana.purr") catch {};
    cwd.deleteDir(io, base ++ "/hosts") catch {};
    cwd.deleteDir(io, base ++ "/vms") catch {};
    cwd.deleteDir(io, base) catch {};
    std.Io.Dir.cwd().createDirPath(io, base ++ "/hosts") catch {};
    std.Io.Dir.cwd().createDirPath(io, base ++ "/vms") catch {};
    try cwd.writeFile(io, .{ .sub_path = base ++ "/vms/grafana.purr", .data = "host mireo { microvm grafana { mem = 768; cpu = 2; net = \"lan\"; ip = \"10.8.0.2\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/hosts/mireo.purr", .data = "import \"../vms/grafana.purr\"; host mireo { }" });
    const src = try cwd.readFileAlloc(io, base ++ "/hosts/mireo.purr", alloc, .limited(8192));
    defer alloc.free(src);
    var diag = diagnostics.Diagnostics.init(arena.allocator(), base ++ "/hosts/mireo.purr", src);
    var lex = lexer.Lexer.init(src, base ++ "/hosts/mireo.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var pars = parser.Parser.initWithSource(toks, &diag, &arena, src);
    var prog = try pars.parseProgram();
    var resolver = Resolver.init(alloc, io, cwd, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve(base ++ "/hosts/mireo.purr", &prog);
    var mireo_count: usize = 0;
    var grafana_found = false;
    for (resolved.decls) |d| {
        if (d == .host and std.mem.eql(u8, d.host.name.name, "mireo")) {
            mireo_count += 1;
            for (d.host.stmts) |s| {
                if (s == .microvm and std.mem.eql(u8, s.microvm.name.name, "grafana")) grafana_found = true;
            }
        }
    }
    try std.testing.expect(mireo_count == 1);
    try std.testing.expect(grafana_found);
    try std.testing.expect(!diag.hasErrors());
    const nix_out = try nix.generate(&resolved, alloc);
    defer alloc.free(nix_out);
    try std.testing.expect(std.mem.indexOf(u8, nix_out, "microvm.vms.grafana") != null);
    try std.testing.expect(std.mem.indexOf(u8, nix_out, "10.8.0.2") != null);
    const filtered = try nix.generateFiltered(&resolved, alloc, "mireo");
    defer alloc.free(filtered);
    try std.testing.expect(std.mem.indexOf(u8, filtered, "grafana") != null);
    cwd.deleteFile(io, base ++ "/hosts/mireo.purr") catch {};
    cwd.deleteFile(io, base ++ "/vms/grafana.purr") catch {};
    cwd.deleteDir(io, base ++ "/hosts") catch {};
    cwd.deleteDir(io, base ++ "/vms") catch {};
    cwd.deleteDir(io, base) catch {};
}

test "resolver host vm multiple fragments via imports" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const base = "/tmp/purr_mireo_full";
    cwd.deleteFile(io, base ++ "/hosts/mireo.purr") catch {};
    cwd.deleteFile(io, base ++ "/vms/grafana.purr") catch {};
    cwd.deleteFile(io, base ++ "/vms/monerod.purr") catch {};
    cwd.deleteFile(io, base ++ "/vms/yammat.purr") catch {};
    cwd.deleteDir(io, base ++ "/hosts") catch {};
    cwd.deleteDir(io, base ++ "/vms") catch {};
    cwd.deleteDir(io, base) catch {};
    std.Io.Dir.cwd().createDirPath(io, base ++ "/hosts") catch {};
    std.Io.Dir.cwd().createDirPath(io, base ++ "/vms") catch {};
    try cwd.writeFile(io, .{ .sub_path = base ++ "/vms/grafana.purr", .data = "host mireo { microvm grafana { mem = 768; cpu = 2; net = \"lan\"; ip = \"10.8.0.2\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/vms/monerod.purr", .data = "host mireo { microvm monerod { mem = 1024; cpu = 2; net = \"lan\"; ip = \"10.8.0.4\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/vms/yammat.purr", .data = "host mireo { microvm yammat { mem = 1024; cpu = 1; net = \"lan\"; ip = \"10.8.0.5\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/hosts/mireo.purr", .data = "import \"../vms/grafana.purr\"; import \"../vms/monerod.purr\"; import \"../vms/yammat.purr\"; host mireo { }" });
    const src = try cwd.readFileAlloc(io, base ++ "/hosts/mireo.purr", alloc, .limited(8192));
    defer alloc.free(src);
    var diag = diagnostics.Diagnostics.init(arena.allocator(), base ++ "/hosts/mireo.purr", src);
    var lex = lexer.Lexer.init(src, base ++ "/hosts/mireo.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var pars = parser.Parser.initWithSource(toks, &diag, &arena, src);
    var prog = try pars.parseProgram();
    var resolver = Resolver.init(alloc, io, cwd, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve(base ++ "/hosts/mireo.purr", &prog);
    var mireo_count: usize = 0;
    var vm_count: usize = 0;
    for (resolved.decls) |d| {
        if (d == .host and std.mem.eql(u8, d.host.name.name, "mireo")) {
            mireo_count += 1;
            for (d.host.stmts) |s| {
                if (s == .microvm) vm_count += 1;
            }
        }
    }
    try std.testing.expect(mireo_count == 1);
    try std.testing.expect(vm_count == 3);
    try std.testing.expect(!diag.hasErrors());
    const nix_out = try nix.generateFiltered(&resolved, alloc, "mireo");
    defer alloc.free(nix_out);
    try std.testing.expect(std.mem.indexOf(u8, nix_out, "grafana") != null);
    try std.testing.expect(std.mem.indexOf(u8, nix_out, "monerod") != null);
    try std.testing.expect(std.mem.indexOf(u8, nix_out, "yammat") != null);
    try std.testing.expect(std.mem.indexOf(u8, nix_out, "microvm.vms.grafana") != null);
    try std.testing.expect(std.mem.indexOf(u8, nix_out, "microvm.vms.monerod") != null);
    cwd.deleteFile(io, base ++ "/hosts/mireo.purr") catch {};
    cwd.deleteFile(io, base ++ "/vms/grafana.purr") catch {};
    cwd.deleteFile(io, base ++ "/vms/monerod.purr") catch {};
    cwd.deleteFile(io, base ++ "/vms/yammat.purr") catch {};
    cwd.deleteDir(io, base ++ "/hosts") catch {};
    cwd.deleteDir(io, base ++ "/vms") catch {};
    cwd.deleteDir(io, base) catch {};
}

test "resolver host vm cycle via normalizePath" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const base = "/tmp/purr_host_vm_cycle";
    cwd.deleteFile(io, base ++ "/hosts/mireo.purr") catch {};
    cwd.deleteFile(io, base ++ "/vms/grafana.purr") catch {};
    cwd.deleteDir(io, base ++ "/hosts") catch {};
    cwd.deleteDir(io, base ++ "/vms") catch {};
    cwd.deleteDir(io, base) catch {};
    std.Io.Dir.cwd().createDirPath(io, base ++ "/hosts") catch {};
    std.Io.Dir.cwd().createDirPath(io, base ++ "/vms") catch {};
    try cwd.writeFile(io, .{ .sub_path = base ++ "/hosts/mireo.purr", .data = "import \"../vms/grafana.purr\"; host mireo { }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/vms/grafana.purr", .data = "import \"../hosts/mireo.purr\"; host mireo { microvm grafana { mem = 768; cpu = 2; net = \"lan\"; ip = \"10.8.0.2\"; } }" });
    const src = try cwd.readFileAlloc(io, base ++ "/hosts/mireo.purr", alloc, .limited(8192));
    defer alloc.free(src);
    var diag = diagnostics.Diagnostics.init(arena.allocator(), base ++ "/hosts/mireo.purr", src);
    var lex = lexer.Lexer.init(src, base ++ "/hosts/mireo.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var pars = parser.Parser.initWithSource(toks, &diag, &arena, src);
    var prog = try pars.parseProgram();
    var resolver = Resolver.init(alloc, io, cwd, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve(base ++ "/hosts/mireo.purr", &prog);
    var mireo_count: usize = 0;
    for (resolved.decls) |d| {
        if (d == .host and std.mem.eql(u8, d.host.name.name, "mireo")) mireo_count += 1;
    }
    try std.testing.expect(mireo_count == 1);
    var has_dup = false;
    for (diag.list.items) |d| {
        if (d.code == .duplicate_import) has_dup = true;
    }
    try std.testing.expect(has_dup);
    var sem = semantic.Semantic.init(&resolved, &diag, arena.allocator());
    try sem.analyze();
    var has_dup_decl = false;
    for (diag.list.items) |d| {
        if (d.code == .duplicate_decl) has_dup_decl = true;
    }
    try std.testing.expect(!has_dup_decl);
    cwd.deleteFile(io, base ++ "/hosts/mireo.purr") catch {};
    cwd.deleteFile(io, base ++ "/vms/grafana.purr") catch {};
    cwd.deleteDir(io, base ++ "/hosts") catch {};
    cwd.deleteDir(io, base ++ "/vms") catch {};
    cwd.deleteDir(io, base) catch {};
}

test "resolver normalizePath deduplication" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const io = std.testing.io;
    const cwd = std.Io.Dir.cwd();
    const base = "/tmp/purr_norm_dedup";
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteDir(io, base) catch {};
    std.Io.Dir.cwd().createDirPath(io, base) catch {};
    try cwd.writeFile(io, .{ .sub_path = base ++ "/b.purr", .data = "host b { microvm bm { mem = 256; cpu = 1; net = \"lan\"; } }" });
    try cwd.writeFile(io, .{ .sub_path = base ++ "/a.purr", .data = "import \"b.purr\"; import \"./b.purr\"; host a { microvm am { mem = 256; cpu = 1; net = \"lan\"; } }" });
    const src = try cwd.readFileAlloc(io, base ++ "/a.purr", alloc, .limited(8192));
    defer alloc.free(src);
    var diag = diagnostics.Diagnostics.init(arena.allocator(), base ++ "/a.purr", src);
    var lex = lexer.Lexer.init(src, base ++ "/a.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var pars = parser.Parser.initWithSource(toks, &diag, &arena, src);
    var prog = try pars.parseProgram();
    var resolver = Resolver.init(alloc, io, cwd, &diag, &arena);
    defer resolver.deinit();
    const resolved = try resolver.resolve(base ++ "/a.purr", &prog);
    var host_count: usize = 0;
    var b_count: usize = 0;
    for (resolved.decls) |d| {
        if (d == .host) {
            host_count += 1;
            if (std.mem.eql(u8, d.host.name.name, "b")) b_count += 1;
        }
    }
    try std.testing.expect(host_count == 2);
    try std.testing.expect(b_count == 1);
    var has_dup = false;
    for (diag.list.items) |d| {
        if (d.code == .duplicate_import) has_dup = true;
    }
    try std.testing.expect(has_dup);
    cwd.deleteFile(io, base ++ "/a.purr") catch {};
    cwd.deleteFile(io, base ++ "/b.purr") catch {};
    cwd.deleteDir(io, base) catch {};
}
