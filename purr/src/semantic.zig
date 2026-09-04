const std = @import("std");
const ast = @import("ast.zig");
const diagnostics = @import("diagnostics.zig");

pub const Semantic = struct {
    program: *const ast.Program,
    diag: *diagnostics.Diagnostics,
    allocator: std.mem.Allocator,

    // known roles for suggestions; in real use would be from data/roles
    known_roles: []const []const u8,
    known_presets: []const []const u8,

    pub fn init(program: *const ast.Program, diag: *diagnostics.Diagnostics, allocator: std.mem.Allocator) Semantic {
        return .{
            .program = program,
            .diag = diag,
            .allocator = allocator,
            .known_roles = &.{ "core", "desktop", "dev", "gaming", "llm" },
            .known_presets = &.{ "gaming-base", "gaming-performance", "gaming-steam" },
        };
    }

    pub fn analyze(self: *Semantic) !void {
        var role_names = std.StringHashMap(diagnostics.Span).init(self.allocator);
        defer role_names.deinit();
        var host_names = std.StringHashMap(diagnostics.Span).init(self.allocator);
        defer host_names.deinit();
        var bundle_names = std.StringHashMap(diagnostics.Span).init(self.allocator);
        defer bundle_names.deinit();
        var preset_names = std.StringHashMap(diagnostics.Span).init(self.allocator);
        defer preset_names.deinit();

        // first pass: collect declarations, detect duplicates
        for (self.program.decls) |decl| {
            switch (decl) {
                .role => |r| {
                    if (role_names.get(r.name.name)) |prev| {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .duplicate_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "duplicate role `{s}`", .{r.name.name}),
                            .span = r.name.span,
                            .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.file, prev.line, prev.col }),
                        });
                    } else {
                        try role_names.put(r.name.name, r.name.span);
                    }
                },
                .host => |h| {
                    if (host_names.get(h.name.name)) |prev| {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .duplicate_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "duplicate host `{s}`", .{h.name.name}),
                            .span = h.name.span,
                            .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.file, prev.line, prev.col }),
                        });
                    } else {
                        try host_names.put(h.name.name, h.name.span);
                    }
                },
                .bundle => |b| {
                    if (bundle_names.get(b.name.name)) |prev| {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .duplicate_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "duplicate bundle `{s}`", .{b.name.name}),
                            .span = b.name.span,
                            .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.file, prev.line, prev.col }),
                        });
                    } else {
                        try bundle_names.put(b.name.name, b.name.span);
                    }
                },
                .preset => |p| {
                    if (preset_names.get(p.name.name)) |prev| {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .duplicate_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "duplicate preset `{s}`", .{p.name.name}),
                            .span = p.name.span,
                            .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.file, prev.line, prev.col }),
                        });
                    } else {
                        try preset_names.put(p.name.name, p.name.span);
                    }
                },
                else => {},
            }
        }

        // second pass: validate references
        for (self.program.decls) |decl| {
            switch (decl) {
                .host => |h| {
                    for (h.stmts) |stmt| {
                        switch (stmt) {
                            .use_role => |ident| {
                                const in_declared = role_names.contains(ident.name);
                                var in_known = false;
                                for (self.known_roles) |k| {
                                    if (std.mem.eql(u8, k, ident.name)) in_known = true;
                                }
                                if (!in_declared and !in_known) {
                                    // check against known + declared for suggestion
                                    var help: ?[]const u8 = null;
                                    var candidates: std.ArrayList([]const u8) = .empty;
                                    for (self.known_roles) |k| try candidates.append(self.allocator, k);
                                    var it = role_names.keyIterator();
                                    while (it.next()) |k| try candidates.append(self.allocator, k.*);
                                    if (try diagnostics.Diagnostics.suggest(ident.name, candidates.items, self.allocator)) |s| {
                                        help = s;
                                    }
                                    const msg = try std.fmt.allocPrint(self.allocator, "unknown role `{s}`", .{ident.name});
                                    if (help == null) {
                                        const avail = try std.mem.join(self.allocator, ", ", self.known_roles);
                                        help = try std.fmt.allocPrint(self.allocator, "available roles: {s}", .{avail});
                                    }
                                    try self.diag.push(.{
                                        .severity = .err,
                                        .code = .unknown_role,
                                        .message = msg,
                                        .span = ident.span,
                                        .help = help,
                                    });
                                }
                            },
                            .preset => |ident| {
                                var found = false;
                                for (self.known_presets) |p| if (std.mem.eql(u8, p, ident.name)) {
                                    found = true;
                                    break;
                                };
                                if (!found) {
                                    // also check if preset declared in program?
                                    for (self.program.decls) |d| if (d == .preset and std.mem.eql(u8, d.preset.name.name, ident.name)) {
                                        found = true;
                                        break;
                                    };
                                }
                                if (!found) {
                                    try self.diag.push(.{
                                        .severity = .err,
                                        .code = .unknown_preset,
                                        .message = try std.fmt.allocPrint(self.allocator, "unknown preset `{s}`", .{ident.name}),
                                        .span = ident.span,
                                        .help = "available presets: gaming-base, gaming-performance, gaming-steam",
                                    });
                                }
                            },
                            else => {},
                        }
                    }
                },
                else => {},
            }
        }
    }
};

test "semantic unknown role" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "role desktop {} host x270 { use gamign; }";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.meow", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.meow", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.init(toks, &diag, &arena);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    try std.testing.expect(diag.hasErrors());
}

test "semantic duplicate host" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host x270 {} host x270 {}";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.meow", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.meow", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.init(toks, &diag, &arena);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    try std.testing.expect(diag.hasErrors());
}
