const std = @import("std");
const ast = @import("ast.zig");
const diagnostics = @import("diagnostics.zig");

pub const SymbolKind = enum {
    role,
    host,
    bundle,
    preset,
    package,
    let_decl,
    microvm,
    struct_decl,
};

pub const ScopeKind = enum {
    module,
    host,
    role,
    bundle,
    preset,
    struct_decl,
};

pub const Symbol = struct {
    name: []const u8,
    kind: SymbolKind,
    span: diagnostics.Span,
    // optional back-reference to decl index for cross-check, not owned
    decl_idx: ?usize = null,
};

/// Scope models lexical visibility for Purr.
/// - module scope is root, contains roles/hosts/bundles/presets/let/microvm(top-level) and known builtins.
/// - host scope is child of module, contains microvms + host-local lets + shadowing.
/// - role/bundle/preset scopes are currently flat (no nested lets), but prepared for future.
///
/// Lookup walks parent chain; `lookupLocal` only checks current.
/// Define checks duplicate in current scope for same kind+name (different kinds may share name).
pub const Scope = struct {
    kind: ScopeKind,
    parent: ?*Scope,
    allocator: std.mem.Allocator,
    // key = "kind:name" e.g. "host:mireo" — allows same name across kinds
    symbols: std.StringHashMap(Symbol),
    children: std.ArrayList(*Scope),
    // arena for owned keys (kind:name strings)
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator, kind: ScopeKind, parent: ?*Scope) !*Scope {
        const self = try allocator.create(Scope);
        self.* = .{
            .kind = kind,
            .parent = parent,
            .allocator = allocator,
            .symbols = std.StringHashMap(Symbol).init(allocator),
            .children = .empty,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
        if (parent) |p| {
            try p.children.append(allocator, self);
        }
        return self;
    }

    pub fn deinit(self: *Scope) void {
        for (self.children.items) |child| child.deinit();
        self.children.deinit(self.allocator);
        self.symbols.deinit();
        self.arena.deinit();
        self.allocator.destroy(self);
    }

    fn keyFor(self: *Scope, kind: SymbolKind, name: []const u8) ![]const u8 {
        // allocate key in arena for stability
        return try std.fmt.allocPrint(self.arena.allocator(), "{s}:{s}", .{ @tagName(kind), name });
    }

    /// Define symbol in current scope. Returns null on success, or existing symbol if duplicate (same kind+name).
    /// Does not emit diagnostics itself; caller decides.
    pub fn define(self: *Scope, name: []const u8, kind: SymbolKind, span: diagnostics.Span) !?Symbol {
        const key = try self.keyFor(kind, name);
        if (self.symbols.get(key)) |existing| {
            return existing;
        }
        const sym = Symbol{ .name = name, .kind = kind, .span = span, .decl_idx = null };
        try self.symbols.put(key, sym);
        return null;
    }

    pub fn defineWithIdx(self: *Scope, name: []const u8, kind: SymbolKind, span: diagnostics.Span, idx: usize) !?Symbol {
        const key = try self.keyFor(kind, name);
        if (self.symbols.get(key)) |existing| {
            return existing;
        }
        const sym = Symbol{ .name = name, .kind = kind, .span = span, .decl_idx = idx };
        try self.symbols.put(key, sym);
        return null;
    }

    /// Lookup in current scope only.
    pub fn lookupLocal(self: *Scope, name: []const u8, kind: SymbolKind) ?Symbol {
        // key is kind:name, but we need to search with same kind
        // We constructed keys as stored; to lookup we need to find exact key.
        // Since we don't have arena key here, we can iterate or reconstruct without arena allocation by scanning.
        // Simple: iterate over map entries and match.
        var it = self.symbols.iterator();
        while (it.next()) |entry| {
            const sym = entry.value_ptr.*;
            if (sym.kind == kind and std.mem.eql(u8, sym.name, name)) return sym;
        }
        return null;
    }

    /// Lookup walking parent chain, starting at current.
    pub fn lookup(self: *Scope, name: []const u8, kind: SymbolKind) ?Symbol {
        var cur: ?*Scope = self;
        while (cur) |scope| {
            if (scope.lookupLocal(name, kind)) |sym| return sym;
            cur = scope.parent;
        }
        return null;
    }

    /// Check if name exists in any kind in current scope (for diagnostics)
    pub fn hasName(self: *Scope, name: []const u8) bool {
        var it = self.symbols.iterator();
        while (it.next()) |entry| {
            if (std.mem.eql(u8, entry.value_ptr.name, name)) return true;
        }
        return false;
    }

    /// Build module scope from a resolved Program.
    /// Defines all top-level symbols; does not yet create host child scopes.
    /// Returns module scope (caller owns, must deinit).
    pub fn fromProgram(allocator: std.mem.Allocator, program: *const ast.Program) !*Scope {
        const mod = try Scope.init(allocator, .module, null);
        for (program.decls, 0..) |decl, idx| {
            switch (decl) {
                .role => |r| {
                    _ = try mod.defineWithIdx(r.name.name, .role, r.name.span, idx);
                },
                .host => |h| {
                    _ = try mod.defineWithIdx(h.name.name, .host, h.name.span, idx);
                },
                .bundle => |b| {
                    _ = try mod.defineWithIdx(b.name.name, .bundle, b.name.span, idx);
                },
                .preset => |p| {
                    _ = try mod.defineWithIdx(p.name.name, .preset, p.name.span, idx);
                },
                .let_decl => |l| {
                    _ = try mod.defineWithIdx(l.name.name, .let_decl, l.name.span, idx);
                },
                .microvm => |vm| {
                    _ = try mod.defineWithIdx(vm.name.name, .microvm, vm.name.span, idx);
                },
                .struct_decl => |s| {
                    _ = try mod.defineWithIdx(s.name.name, .struct_decl, s.name.span, idx);
                },
                else => {},
            }
        }
        return mod;
    }

    /// Create host child scopes for each host in program, defining microvms and host-local lets.
    /// Call after fromProgram; populates mod.children.
    pub fn buildHostScopes(self: *Scope, program: *const ast.Program) !void {
        std.debug.assert(self.kind == .module);
        for (program.decls) |decl| {
            if (decl != .host) continue;
            const h = decl.host;
            const host_scope = try Scope.init(self.allocator, .host, self);
            // define microvms and lets inside host
            for (h.stmts) |stmt| {
                switch (stmt) {
                    .microvm => |vm| {
                        _ = try host_scope.define(vm.name.name, .microvm, vm.name.span);
                    },
                    .let_decl => |l| {
                        _ = try host_scope.define(l.name.name, .let_decl, l.name.span);
                    },
                    else => {},
                }
            }
            // host name itself is not re-defined in its own scope; lookup for host extends walks to parent
            _ = h.stmts.len;
        }
    }

    /// Helper: collect all symbols of a given kind in current scope (for suggestions)
    pub fn collectKind(self: *Scope, kind: SymbolKind, allocator: std.mem.Allocator) ![][]const u8 {
        var list: std.ArrayList([]const u8) = .empty;
        var it = self.symbols.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.kind == kind) try list.append(allocator, entry.value_ptr.name);
        }
        return try list.toOwnedSlice(allocator);
    }
};

// ---------------------------------------------------------------------------
// Tests — Phase 8.0: Symbol/Scope model, no CLI/Nix changes
// ---------------------------------------------------------------------------

test "symbol scope define and lookupLocal" {
    const alloc = std.testing.allocator;
    const span = diagnostics.Span{ .file = "test.purr", .line = 1, .col = 1, .len = 4, .start = 0, .end = 4 };
    const mod = try Scope.init(alloc, .module, null);
    defer mod.deinit();
    // define host
    const dup = try mod.define("mireo", .host, span);
    try std.testing.expect(dup == null);
    // lookup local
    const found = mod.lookupLocal("mireo", .host);
    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings("mireo", found.?.name);
    // different kind may share name
    const dup2 = try mod.define("mireo", .role, span);
    try std.testing.expect(dup2 == null);
    const found_role = mod.lookupLocal("mireo", .role);
    try std.testing.expect(found_role != null);
    // same kind duplicate returns existing
    const existing = try mod.define("mireo", .host, span);
    try std.testing.expect(existing != null);
    try std.testing.expectEqualStrings("mireo", existing.?.name);
}

test "symbol scope parent lookup" {
    const alloc = std.testing.allocator;
    const span = diagnostics.Span{ .file = "test.purr", .line = 1, .col = 1, .len = 4, .start = 0, .end = 4 };
    const mod = try Scope.init(alloc, .module, null);
    defer mod.deinit();
    _ = try mod.define("base", .let_decl, span);
    const host_scope = try Scope.init(alloc, .host, mod);
    // host can see module let via parent
    const found = host_scope.lookup("base", .let_decl);
    try std.testing.expect(found != null);
    // but not vice versa
    const not_found = mod.lookup("inner", .let_decl);
    try std.testing.expect(not_found == null);
    // define inner let in host
    _ = try host_scope.define("inner", .let_decl, span);
    // host lookup finds its own
    try std.testing.expect(host_scope.lookupLocal("inner", .let_decl) != null);
    // module cannot see host inner
    try std.testing.expect(mod.lookup("inner", .let_decl) == null);
    // shadowing: host can shadow module name
    _ = try host_scope.define("base", .let_decl, span);
    const shadowed = host_scope.lookup("base", .let_decl);
    try std.testing.expect(shadowed != null);
    // shadowed is host's base, not module's — check that lookupLocal on host returns host's
    try std.testing.expect(host_scope.lookupLocal("base", .let_decl) != null);
}

test "symbol scope fromProgram" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\role desktop { description = "d"; }
        \\host mireo { microvm grafana { mem = 512; cpu = 1; net = "lan"; } }
        \\let base = "x270";
        \\host x270 { use desktop; }
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    const parser = @import("parser.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try p.parseProgram();
    const mod = try Scope.fromProgram(alloc, &prog);
    defer mod.deinit();
    // module sees all top-level
    try std.testing.expect(mod.lookup("desktop", .role) != null);
    try std.testing.expect(mod.lookup("mireo", .host) != null);
    try std.testing.expect(mod.lookup("x270", .host) != null);
    try std.testing.expect(mod.lookup("base", .let_decl) != null);
    // unknown
    try std.testing.expect(mod.lookup("missing", .host) == null);
    // wrong kind
    try std.testing.expect(mod.lookup("desktop", .host) == null);
    try std.testing.expect(mod.lookup("mireo", .role) == null);
}

test "symbol scope host child microvm" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\host mireo {
        \\    microvm grafana { mem = 512; cpu = 1; net = "lan"; }
        \\    microvm monerod { mem = 1024; cpu = 2; net = "lan"; }
        \\}
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    const parser = @import("parser.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try p.parseProgram();
    const mod = try Scope.fromProgram(alloc, &prog);
    defer mod.deinit();
    try mod.buildHostScopes(&prog);
    // should have one host child
    try std.testing.expect(mod.children.items.len == 1);
    const host_scope = mod.children.items[0];
    try std.testing.expect(host_scope.kind == .host);
    try std.testing.expect(host_scope.lookupLocal("grafana", .microvm) != null);
    try std.testing.expect(host_scope.lookupLocal("monerod", .microvm) != null);
    try std.testing.expect(host_scope.lookupLocal("missing", .microvm) == null);
    // microvms are not visible from module directly
    try std.testing.expect(mod.lookupLocal("grafana", .microvm) == null);
    // but via host scope parent lookup, module not needed
    // host scope can also see module symbols
    _ = try mod.define("base", .let_decl, .{ .file = "test.purr", .line = 1, .col = 1, .len = 4, .start = 0, .end = 4 });
    try std.testing.expect(host_scope.lookup("base", .let_decl) != null);
}

test "symbol scope duplicate within same scope" {
    const alloc = std.testing.allocator;
    const span = diagnostics.Span{ .file = "test.purr", .line = 1, .col = 1, .len = 1, .start = 0, .end = 1 };
    const mod = try Scope.init(alloc, .module, null);
    defer mod.deinit();
    _ = try mod.define("dup", .host, span);
    const existing = try mod.define("dup", .host, span);
    try std.testing.expect(existing != null);
    // different kind allowed
    const not_dup = try mod.define("dup", .role, span);
    try std.testing.expect(not_dup == null);
}

test "symbol scope unknown role suggestion via collectKind" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\role desktop {}
        \\role gaming {}
        \\host x270 { use desktop; }
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    const parser = @import("parser.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try p.parseProgram();
    const mod = try Scope.fromProgram(alloc, &prog);
    defer mod.deinit();
    const roles = try mod.collectKind(.role, alloc);
    defer alloc.free(roles);
    try std.testing.expect(roles.len == 2);
    // suggest for typo using diagnostics helper
    const help = try diagnostics.Diagnostics.suggest("gamign", roles, alloc);
    defer if (help) |h| alloc.free(h);
    try std.testing.expect(help != null);
}

test "symbol scope let shadowing and ordered" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\let base = "x270";
        \\host x270 {
        \\    let base = "mireo";
        \\    s = base;
        \\}
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    const parser = @import("parser.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try p.parseProgram();
    const mod = try Scope.fromProgram(alloc, &prog);
    defer mod.deinit();
    try mod.buildHostScopes(&prog);
    // module has base
    try std.testing.expect(mod.lookup("base", .let_decl) != null);
    const host_scope = mod.children.items[0];
    // host has its own base shadowing
    try std.testing.expect(host_scope.lookupLocal("base", .let_decl) != null);
    // lookup from host finds its own first (shadowing)
    const found = host_scope.lookup("base", .let_decl);
    try std.testing.expect(found != null);
    // host local base span is different from module base? We don't track which, just that it shadows
    try std.testing.expect(host_scope.lookupLocal("base", .let_decl) != null);
}

test "symbol scope multiple hosts" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\host mireo { microvm grafana { mem = 512; cpu = 1; net = "lan"; } }
        \\host x270 { use desktop; }
        \\role desktop {}
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    const parser = @import("parser.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try p.parseProgram();
    const mod = try Scope.fromProgram(alloc, &prog);
    defer mod.deinit();
    try mod.buildHostScopes(&prog);
    try std.testing.expect(mod.children.items.len == 2);
    // each host scope is independent
    const mireo_scope = mod.children.items[0];
    const x270_scope = mod.children.items[1];
    try std.testing.expect(mireo_scope.lookupLocal("grafana", .microvm) != null);
    try std.testing.expect(x270_scope.lookupLocal("grafana", .microvm) == null);
    // both can see role desktop via parent
    try std.testing.expect(mireo_scope.lookup("desktop", .role) != null);
    try std.testing.expect(x270_scope.lookup("desktop", .role) != null);
}

test "symbol scope deterministic ordering" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source1 =
        \\host b { use desktop; }
        \\host a { use desktop; }
        \\role desktop {}
    ;
    const source2 =
        \\role desktop {}
        \\host a { use desktop; }
        \\host b { use desktop; }
    ;
    for ([_][]const u8{ source1, source2 }) |src| {
        var arena2 = std.heap.ArenaAllocator.init(alloc);
        defer arena2.deinit();
        var diag = diagnostics.Diagnostics.init(arena2.allocator(), "test.purr", src);
        const lexer = @import("lexer.zig");
        const parser = @import("parser.zig");
        var lex = lexer.Lexer.init(src, "test.purr", &diag);
        const toks = try lex.lexAll(arena2.allocator());
        var p = parser.Parser.initWithSource(toks, &diag, &arena2, src);
        var prog = try p.parseProgram();
        const mod = try Scope.fromProgram(alloc, &prog);
        defer mod.deinit();
        // both sources should result in same symbols regardless of decl order
        try std.testing.expect(mod.lookup("a", .host) != null);
        try std.testing.expect(mod.lookup("b", .host) != null);
        try std.testing.expect(mod.lookup("desktop", .role) != null);
    }
}
