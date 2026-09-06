const std = @import("std");
const ast = @import("ast.zig");
const diagnostics = @import("diagnostics.zig");
const fmt = @import("fmt.zig");

pub const Lint = struct {
    original: *const ast.Program,
    resolved: *const ast.Program,
    source: []const u8,
    file: []const u8,
    diag: *diagnostics.Diagnostics,
    allocator: std.mem.Allocator,

    pub fn init(
        original: *const ast.Program,
        resolved: *const ast.Program,
        source: []const u8,
        file: []const u8,
        diag: *diagnostics.Diagnostics,
        allocator: std.mem.Allocator,
    ) Lint {
        return .{
            .original = original,
            .resolved = resolved,
            .source = source,
            .file = file,
            .diag = diag,
            .allocator = allocator,
        };
    }

    pub fn run(self: *Lint) !void {
        try self.checkDuplicateImports();
        try self.checkUnusedImports();
        try self.checkEmptyDecls();
        try self.checkUnusedLets();
        try self.checkFormatting();
        // deterministic ordering: sort diagnostics by file, line, col
        // we sort only the lint warnings added in this run, but for simplicity sort all
        self.sortDiagnostics();
    }

    fn checkDuplicateImports(self: *Lint) !void {
        // Check for duplicate import paths in original program
        var seen = std.StringHashMap(diagnostics.Span).init(self.allocator);
        defer seen.deinit();
        for (self.original.imports) |imp| {
            if (seen.get(imp.path)) |prev| {
                // Only emit if not already reported by resolver? For now emit anyway with lint code
                // To avoid double, check if diag already has duplicate_import for this span
                var already_reported = false;
                for (self.diag.list.items) |d| {
                    if (d.code == .duplicate_import and d.span != null and d.span.?.start == imp.span.start) {
                        already_reported = true;
                        break;
                    }
                }
                if (already_reported) continue;
                try self.diag.push(.{
                    .severity = .warning,
                    .code = .duplicate_import,
                    .message = try std.fmt.allocPrint(self.allocator, "duplicate import `{s}`", .{imp.path}),
                    .span = imp.span,
                    .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.file, prev.line, prev.col }),
                });
            } else {
                try seen.put(imp.path, imp.span);
            }
        }
    }

    fn checkUnusedImports(self: *Lint) !void {
        // For each direct import in original, check if any decl from that file is referenced
        // Collect all `use` references in resolved program
        var used_names = std.StringHashMap(void).init(self.allocator);
        defer used_names.deinit();
        for (self.resolved.decls) |decl| {
            switch (decl) {
                .host => |h| {
                    for (h.stmts) |stmt| {
                        switch (stmt) {
                            .use_role => |ident| try used_names.put(ident.name, {}),
                            else => {},
                        }
                    }
                },
                else => {},
            }
        }
        // Also collect bundle/preset uses? For now only role uses are considered for unused import
        // An import is unused if none of the roles/bundles/presets it defines are used
        for (self.original.imports) |imp| {
            const dir = std.fs.path.dirname(self.file) orelse ".";
            const joined = if (std.fs.path.isAbsolute(imp.path))
                try self.allocator.dupe(u8, imp.path)
            else if (std.mem.eql(u8, dir, "."))
                try self.allocator.dupe(u8, imp.path)
            else
                try std.fs.path.join(self.allocator, &.{ dir, imp.path });
            defer self.allocator.free(joined);
            // Find decls that came from this imported file
            var defines_any = false;
            var is_used = false;
            for (self.resolved.decls) |decl| {
                const decl_file = switch (decl) {
                    .role => |r| r.name.span.file,
                    .host => |h| h.name.span.file,
                    .bundle => |b| b.name.span.file,
                    .preset => |p| p.name.span.file,
                    .package_decl => |pkg| pkg.span.file,
                    .nix => |n| n.span.file,
                    .let_decl => |l| l.name.span.file,
                };
                if (!std.mem.eql(u8, decl_file, joined)) continue;
                defines_any = true;
                // Check if this decl's name is used
                const name = switch (decl) {
                    .role => |r| r.name.name,
                    .bundle => |b| b.name.name,
                    .preset => |p| p.name.name,
                    .let_decl => |l| l.name.name,
                    else => null,
                };
                if (name) |n| {
                    if (used_names.contains(n)) is_used = true;
                }
            }
            if (defines_any and !is_used) {
                // Also check if import is already reported as duplicate? Skip unused if duplicate
                var is_duplicate = false;
                var count: usize = 0;
                for (self.original.imports) |other| {
                    if (std.mem.eql(u8, other.path, imp.path)) count += 1;
                }
                if (count > 1) is_duplicate = true;
                if (is_duplicate) continue;
                try self.diag.push(.{
                    .severity = .warning,
                    .code = .unused_import,
                    .message = try std.fmt.allocPrint(self.allocator, "unused import `{s}`", .{imp.path}),
                    .span = imp.span,
                    .help = "remove the import or use one of its declarations",
                });
            }
        }
    }

    fn checkEmptyDecls(self: *Lint) !void {
        for (self.resolved.decls) |decl| {
            switch (decl) {
                .role => |r| {
                    const is_empty = r.description == null and r.targets.len == 0 and r.requires_host.len == 0 and r.conflicts_host.len == 0 and r.host == null and r.home == null;
                    if (is_empty) {
                        try self.diag.push(.{
                            .severity = .warning,
                            .code = .empty_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "empty role `{s}`", .{r.name.name}),
                            .span = r.name.span,
                            .help = "add description, targets, or host/home blocks",
                        });
                    }
                },
                .host => |h| {
                    if (h.stmts.len == 0) {
                        try self.diag.push(.{
                            .severity = .warning,
                            .code = .empty_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "empty host `{s}`", .{h.name.name}),
                            .span = h.name.span,
                            .help = "add use, preset, package, or setting",
                        });
                    }
                },
                .bundle => |b| {
                    const is_empty = b.description == null and b.programs.len == 0 and b.package_toggles.len == 0;
                    if (is_empty) {
                        try self.diag.push(.{
                            .severity = .warning,
                            .code = .empty_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "empty bundle `{s}`", .{b.name.name}),
                            .span = b.name.span,
                            .help = "add description, programs, or packages",
                        });
                    }
                },
                .preset => |p| {
                    const is_empty = p.description == null and p.flags.len == 0;
                    if (is_empty) {
                        try self.diag.push(.{
                            .severity = .warning,
                            .code = .empty_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "empty preset `{s}`", .{p.name.name}),
                            .span = p.name.span,
                            .help = "add description or flags { ... }",
                        });
                    }
                },
                .let_decl => {},
                else => {},
            }
        }
    }

    fn checkUnusedLets(self: *Lint) !void {
        // Collect all let names and check if used in any Expr
        var let_spans = std.StringHashMap(diagnostics.Span).init(self.allocator);
        defer let_spans.deinit();
        var used = std.StringHashMap(void).init(self.allocator);
        defer used.deinit();

        // collect lets
        for (self.resolved.decls) |decl| {
            switch (decl) {
                .let_decl => |l| try let_spans.put(l.name.name, l.name.span),
                .host => |h| for (h.stmts) |stmt| if (stmt == .let_decl) try let_spans.put(stmt.let_decl.name.name, stmt.let_decl.name.span),
                .preset => |p| for (p.flags) |f| try collectIdents(f.value, &used),
                else => {},
            }
        }
        // also need to collect idents from let values themselves? No, that's definition, not use; but if let a = b; then b is use
        for (self.resolved.decls) |decl| {
            switch (decl) {
                .let_decl => |l| try collectIdents(l.value, &used),
                .preset => |p| for (p.flags) |f| try collectIdents(f.value, &used),
                .host => |h| for (h.stmts) |stmt| switch (stmt) {
                    .let_decl => |l| try collectIdents(l.value, &used),
                    .setting => |s| try collectIdents(s.value, &used),
                    else => {},
                },
                else => {},
            }
        }
        var it = let_spans.iterator();
        while (it.next()) |entry| {
            if (!used.contains(entry.key_ptr.*)) {
                try self.diag.push(.{
                    .severity = .warning,
                    .code = .unused_let,
                    .message = try std.fmt.allocPrint(self.allocator, "unused let `{s}`", .{entry.key_ptr.*}),
                    .span = entry.value_ptr.*,
                    .help = "remove or use the binding",
                });
            }
        }
    }

    fn collectIdents(expr: ast.Expr, used: *std.StringHashMap(void)) !void {
        switch (expr.data) {
            .ident => |id| try used.put(id.name, {}),
            .binary => |b| {
                try collectIdents(b.lhs.*, used);
                try collectIdents(b.rhs.*, used);
            },
            .unary => |u| try collectIdents(u.expr.*, used),
            .paren => |p| try collectIdents(p.*, used),
            .list => |lst| for (lst) |item| try collectIdents(item, used),
            .string, .integer, .boolean => {},
        }
    }

    fn checkFormatting(self: *Lint) !void {
        // Reuse existing formatter on original program
        const formatted = fmt.format(self.original, self.allocator) catch return;
        defer self.allocator.free(formatted);
        if (!std.mem.eql(u8, formatted, self.source)) {
            // Find first differing line for span
            var line: u32 = 1;
            var col: u32 = 1;
            var idx: usize = 0;
            while (idx < self.source.len and idx < formatted.len and self.source[idx] == formatted[idx]) : (idx += 1) {
                if (self.source[idx] == '\n') {
                    line += 1;
                    col = 1;
                } else {
                    col += 1;
                }
            }
            // If source is prefix of formatted, still warn at end
            try self.diag.push(.{
                .severity = .warning,
                .code = .unformatted,
                .message = "file not formatted",
                .span = .{
                    .file = self.file,
                    .line = line,
                    .col = col,
                    .len = 1,
                    .start = idx,
                    .end = idx + 1,
                },
                .help = "run `purr fmt` to format",
            });
        }
    }

    fn sortDiagnostics(self: *Lint) void {
        const items = self.diag.list.items;
        // Simple bubble sort for deterministic ordering (few diagnostics)
        for (0..items.len) |i| {
            for (i + 1..items.len) |j| {
                const a = items[i].span orelse diagnostics.Span{ .file = "", .line = 0, .col = 0, .len = 0, .start = 0, .end = 0 };
                const b = items[j].span orelse diagnostics.Span{ .file = "", .line = 0, .col = 0, .len = 0, .start = 0, .end = 0 };
                const cmp = blk: {
                    const file_cmp = std.mem.order(u8, a.file, b.file);
                    if (file_cmp != .eq) break :blk file_cmp == .lt;
                    if (a.line != b.line) break :blk a.line < b.line;
                    break :blk a.col < b.col;
                };
                if (!cmp) {
                    const tmp = items[i];
                    items[i] = items[j];
                    items[j] = tmp;
                }
            }
        }
    }
};

test "lint clean" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\host x270 {
        \\    use desktop;
        \\}
        \\
        \\role desktop {
        \\    description = "x";
        \\}
        \\
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var lint = Lint.init(&prog, &prog, source, "test.purr", &diag, arena.allocator());
    try lint.run();
    // clean file should have no warnings
    for (diag.list.items) |d| {
        if (d.severity == .warning) {
            std.debug.print("unexpected warning: {s} {s}\n", .{ @tagName(d.code), d.message });
        }
    }
    try std.testing.expect(!hasWarning(&diag));
}

fn hasWarning(diag: *const diagnostics.Diagnostics) bool {
    for (diag.list.items) |d| {
        if (d.severity == .warning) return true;
    }
    return false;
}

test "lint empty decl" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "role empty {}";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var lint = Lint.init(&prog, &prog, source, "test.purr", &diag, arena.allocator());
    try lint.run();
    var found = false;
    for (diag.list.items) |d| {
        if (d.code == .empty_decl) found = true;
    }
    try std.testing.expect(found);
}

test "lint unused import" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    // main file imports a.purr which defines role a, but main uses desktop (not a) -> unused
    const source =
        \\import "a.purr";
        \\host x270 {
        \\    use desktop;
        \\}
        \\
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "main.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "main.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    // Simulate resolved program where a.purr defines role a, but main uses desktop
    // Create a fake resolved program with additional decl from a.purr
    var arena2 = std.heap.ArenaAllocator.init(alloc);
    defer arena2.deinit();
    const role_a_source = "role a { description = \"a\"; }";
    var diag2 = diagnostics.Diagnostics.init(arena2.allocator(), "a.purr", role_a_source);
    var lex2 = lexer.Lexer.init(role_a_source, "a.purr", &diag2);
    const toks2 = try lex2.lexAll(arena2.allocator());
    var parser2 = @import("parser.zig").Parser.initWithSource(toks2, &diag2, &arena2, role_a_source);
    const prog_a = try parser2.parseProgram();
    // Merge: for test, manually create resolved with both decls, with correct file spans
    // prog_a's role a has file "a.purr", prog's host has file "main.purr"
    var merged_decl_list: std.ArrayList(ast.Decl) = .empty;
    for (prog_a.decls) |d| try merged_decl_list.append(arena.allocator(), d);
    for (prog.decls) |d| try merged_decl_list.append(arena.allocator(), d);
    var resolved = ast.Program{
        .imports = prog.imports,
        .decls = try merged_decl_list.toOwnedSlice(arena.allocator()),
        .arena = arena,
    };
    // For unused check, need to know that a.purr defines role a, but used_names only has desktop, so unused
    var lint = Lint.init(&prog, &resolved, source, "main.purr", &diag, arena.allocator());
    try lint.run();
    var found_unused = false;
    for (diag.list.items) |d| {
        if (d.code == .unused_import) found_unused = true;
    }
    try std.testing.expect(found_unused);
}

test "lint duplicate import" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\import "a.purr";
        \\import "a.purr";
        \\host x270 {
        \\    use a;
        \\}
        \\
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var lint = Lint.init(&prog, &prog, source, "test.purr", &diag, arena.allocator());
    try lint.run();
    var found = false;
    for (diag.list.items) |d| {
        if (d.code == .duplicate_import) found = true;
    }
    try std.testing.expect(found);
}

test "lint unformatted" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host x270{use desktop;}";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var lint = Lint.init(&prog, &prog, source, "test.purr", &diag, arena.allocator());
    try lint.run();
    var found = false;
    for (diag.list.items) |d| {
        if (d.code == .unformatted) found = true;
    }
    try std.testing.expect(found);
}

test "lint multiple warnings" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\import "a.purr";
        \\import "a.purr";
        \\role empty {}
        \\host x270{use a;}
        \\
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var lint = Lint.init(&prog, &prog, source, "test.purr", &diag, arena.allocator());
    try lint.run();
    var count: usize = 0;
    for (diag.list.items) |d| {
        if (d.severity == .warning) count += 1;
    }
    try std.testing.expect(count >= 3); // duplicate, empty, unformatted
}

test "lint deterministic ordering" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\import "b.purr";
        \\import "a.purr";
        \\role empty {}
        \\role empty2 {}
        \\host x270{use a;}
        \\
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var lint = Lint.init(&prog, &prog, source, "test.purr", &diag, arena.allocator());
    try lint.run();
    // Check that diagnostics are sorted by file, line, col
    for (0..diag.list.items.len - 1) |i| {
        const a = diag.list.items[i].span orelse continue;
        const b = diag.list.items[i + 1].span orelse continue;
        const file_cmp = std.mem.order(u8, a.file, b.file);
        if (file_cmp == .eq) {
            if (a.line == b.line) {
                try std.testing.expect(a.col <= b.col);
            } else {
                try std.testing.expect(a.line <= b.line);
            }
        }
    }
}
