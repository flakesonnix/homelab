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

            var p = parser.Parser.init(toks, self.diag, self.arena);
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

        return ast.Program{
            .imports = try merged_imports.toOwnedSlice(arena_alloc),
            .decls = try merged_decls.toOwnedSlice(arena_alloc),
            .arena = self.arena.*,
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
