const std = @import("std");
const ast = @import("ast.zig");
const diagnostics = @import("diagnostics.zig");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");

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
            const joined = if (std.fs.path.isAbsolute(imp.path))
                try arena_alloc.dupe(u8, imp.path)
            else
                try std.fs.path.join(arena_alloc, &.{ dir, imp.path });

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
        // Resolve host inheritance (extends) after imports
        prog_with_imports = try self.resolveHosts(&prog_with_imports);
        return prog_with_imports;
    }

    fn resolveHosts(self: *Resolver, program: *const ast.Program) !ast.Program {
        const arena_alloc = self.arena.allocator();
        // Build map from host name to index
        var host_map = std.StringHashMap(usize).init(self.allocator);
        defer host_map.deinit();
        for (program.decls, 0..) |decl, idx| {
            if (decl == .host) {
                const name = decl.host.name.name;
                // Keep first occurrence for map (duplicates will be caught by semantic)
                if (!host_map.contains(name)) try host_map.put(name, idx);
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

        for (program.decls) |decl| {
            if (decl == .host) {
                const name = decl.host.name.name;
                if (state.get(name) == null) {
                    try self.resolveHostDFS(name, &host_map, program, &state, &resolved_hosts, &has_cycle);
                }
            }
        }

        // Build new decls list with resolved hosts
        var new_decls: std.ArrayList(ast.Decl) = .empty;
        for (program.decls) |decl| {
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
            .imports = try arena_alloc.dupe(ast.Import, program.imports),
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
