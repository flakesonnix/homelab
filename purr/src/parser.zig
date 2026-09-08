const std = @import("std");
const lexer = @import("lexer.zig");
const ast = @import("ast.zig");
const diagnostics = @import("diagnostics.zig");
const Span = diagnostics.Span;

pub const Parser = struct {
    tokens: []lexer.Token,
    pos: usize,
    diag: *diagnostics.Diagnostics,
    arena: *std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    source: []const u8,

    pub fn init(tokens: []lexer.Token, diag: *diagnostics.Diagnostics, arena: *std.heap.ArenaAllocator) Parser {
        return initWithSource(tokens, diag, arena, "");
    }

    pub fn initWithSource(tokens: []lexer.Token, diag: *diagnostics.Diagnostics, arena: *std.heap.ArenaAllocator, source: []const u8) Parser {
        return .{
            .tokens = tokens,
            .pos = 0,
            .diag = diag,
            .arena = arena,
            .allocator = arena.allocator(),
            .source = source,
        };
    }

    fn peek(self: *Parser) lexer.Token {
        if (self.pos < self.tokens.len) return self.tokens[self.pos];
        return self.tokens[self.tokens.len - 1];
    }

    fn peekKind(self: *Parser) lexer.TokenKind {
        return self.peek().kind;
    }

    fn advance(self: *Parser) lexer.Token {
        const t = self.peek();
        if (self.pos < self.tokens.len) self.pos += 1;
        return t;
    }

    fn expect(self: *Parser, kind: lexer.TokenKind) !lexer.Token {
        const t = self.peek();
        if (t.kind != kind) {
            try self.diag.push(.{
                .severity = .err,
                .code = .parse_error,
                .message = try std.fmt.allocPrint(self.allocator, "expected {s}, found {s} `{s}`", .{ @tagName(kind), @tagName(t.kind), t.lexeme }),
                .span = t.span,
                .help = null,
            });
            return error.ParseError;
        }
        return self.advance();
    }

    fn consumeIf(self: *Parser, kind: lexer.TokenKind) ?lexer.Token {
        if (self.peekKind() == kind) return self.advance();
        return null;
    }

    fn isAtEnd(self: *Parser) bool {
        return self.peekKind() == .eof;
    }

    fn dup(self: *Parser, s: []const u8) ![]const u8 {
        return try self.allocator.dupe(u8, s);
    }

    fn unquote(self: *Parser, lexeme: []const u8) ![]const u8 {
        // lexeme includes quotes: "hello"
        if (lexeme.len < 2) return try self.dup("");
        // handle escapes simply: remove outer quotes, unescape
        var buf: std.ArrayList(u8) = .empty;
        var i: usize = 1;
        while (i < lexeme.len - 1) : (i += 1) {
            if (lexeme[i] == '\\' and i + 1 < lexeme.len - 1) {
                i += 1;
                switch (lexeme[i]) {
                    'n' => try buf.append(self.allocator, '\n'),
                    't' => try buf.append(self.allocator, '\t'),
                    '"' => try buf.append(self.allocator, '"'),
                    '\\' => try buf.append(self.allocator, '\\'),
                    else => try buf.append(self.allocator, lexeme[i]),
                }
            } else {
                try buf.append(self.allocator, lexeme[i]);
            }
        }
        return try buf.toOwnedSlice(self.allocator);
    }

    pub fn parseProgram(self: *Parser) !ast.Program {
        var imports: std.ArrayList(ast.Import) = .empty;
        var decls: std.ArrayList(ast.Decl) = .empty;

        while (!self.isAtEnd()) {
            switch (self.peekKind()) {
                .keyword_import => {
                    const imp = try self.parseImport();
                    try imports.append(self.allocator, imp);
                },
                .keyword_let, .keyword_role, .keyword_host, .keyword_bundle, .keyword_preset, .keyword_package, .keyword_nix, .keyword_microvm => {
                    const decl = try self.parseDecl();
                    try decls.append(self.allocator, decl);
                },
                .eof => break,
                else => {
                    const t = self.advance();
                    try self.diag.push(.{
                        .severity = .err,
                        .code = .parse_error,
                        .message = try std.fmt.allocPrint(self.allocator, "unexpected token `{s}`", .{t.lexeme}),
                        .span = t.span,
                        .help = "expected `role`, `host`, `bundle`, `preset`, `package`, `import` or `nix`",
                    });
                    // recovery: skip to next ; or }
                    while (!self.isAtEnd() and self.peekKind() != .semicolon and self.peekKind() != .r_brace) _ = self.advance();
                    _ = self.consumeIf(.semicolon);
                },
            }
        }

        return ast.Program{
            .imports = try imports.toOwnedSlice(self.allocator),
            .decls = try decls.toOwnedSlice(self.allocator),
            .arena = self.arena.*,
        };
    }

    fn parseImport(self: *Parser) !ast.Import {
        const kw = try self.expect(.keyword_import);
        const str_tok = try self.expect(.string_lit);
        _ = try self.expect(.semicolon);
        const path = try self.unquote(str_tok.lexeme);
        return .{ .path = path, .span = kw.span };
    }

    fn parseType(self: *Parser) !ast.Type {
        const start = self.peek().span;
        const name_tok = try self.parseIdent();
        const name = name_tok.name;
        // Handle generic types like List<T>, Vec<T>, Option<T>
        if (std.mem.eql(u8, name, "List") or std.mem.eql(u8, name, "Vec") or std.mem.eql(u8, name, "Option")) {
            if (self.consumeIf(.lt) != null) {
                const inner = try self.parseType();
                _ = try self.expect(.gt);
                const inner_ptr = try self.allocator.create(ast.Type);
                inner_ptr.* = inner;
                const data: ast.Type.Data = if (std.mem.eql(u8, name, "Option")) .{ .option = inner_ptr } else .{ .list = inner_ptr };
                return .{ .span = start, .data = data };
            }
        }
        const data: ast.Type.Data = blk: {
            if (std.mem.eql(u8, name, "bool")) break :blk .bool;
            if (std.mem.eql(u8, name, "i32")) break :blk .i32;
            if (std.mem.eql(u8, name, "i64")) break :blk .i64;
            if (std.mem.eql(u8, name, "u32")) break :blk .u32;
            if (std.mem.eql(u8, name, "u64")) break :blk .u64;
            if (std.mem.eql(u8, name, "usize")) break :blk .usize;
            if (std.mem.eql(u8, name, "String") or std.mem.eql(u8, name, "string") or std.mem.eql(u8, name, "str")) break :blk .string;
            if (std.mem.eql(u8, name, "Ipv4") or std.mem.eql(u8, name, "IPv4") or std.mem.eql(u8, name, "ip")) break :blk .ipv4;
            if (std.mem.eql(u8, name, "Path")) break :blk .path;
            if (std.mem.eql(u8, name, "Duration")) break :blk .duration;
            break :blk .{ .named = try self.dup(name) };
        };
        return .{ .span = start, .data = data };
    }

    fn parseLet(self: *Parser) !ast.Let {
        const kw = try self.expect(.keyword_let);
        const name = try self.parseIdent();
        var type_annot: ?ast.Type = null;
        if (self.consumeIf(.colon) != null) {
            type_annot = try self.parseType();
        }
        _ = try self.expect(.equal);
        const value = try self.parseExpr(0);
        _ = try self.expect(.semicolon);
        return .{ .name = name, .type_annot = type_annot, .value = value, .span = kw.span };
    }

    fn parseDecl(self: *Parser) !ast.Decl {
        switch (self.peekKind()) {
            .keyword_role => return .{ .role = try self.parseRole() },
            .keyword_host => return .{ .host = try self.parseHost() },
            .keyword_bundle => return .{ .bundle = try self.parseBundle() },
            .keyword_preset => return .{ .preset = try self.parsePreset() },
            .keyword_package => {
                const pkg = try self.parsePackage();
                return .{ .package_decl = pkg };
            },
            .keyword_nix => return .{ .nix = try self.parseNix() },
            .keyword_let => return .{ .let_decl = try self.parseLet() },
            .keyword_microvm => return .{ .microvm = try self.parseMicroVM() },
            else => unreachable,
        }
    }

    fn parseIdent(self: *Parser) !ast.Ident {
        const t = self.peek();
        if (t.kind != .ident and !isKeywordIdent(t.kind)) {
            try self.diag.push(.{
                .severity = .err,
                .code = .parse_error,
                .message = try std.fmt.allocPrint(self.allocator, "expected identifier, found `{s}`", .{t.lexeme}),
                .span = t.span,
                .help = null,
            });
            return error.ParseError;
        }
        _ = self.advance();
        const name = try self.dup(t.lexeme);
        return .{ .name = name, .span = t.span };
    }

    fn isKeywordIdent(k: lexer.TokenKind) bool {
        return k == .keyword_role or k == .keyword_host or k == .keyword_bundle or k == .keyword_preset or k == .keyword_package or k == .keyword_import or k == .keyword_use or k == .keyword_nix or k == .keyword_description or k == .keyword_targets or k == .keyword_extends or k == .keyword_microvm or k == .keyword_volume;
    }

    fn parseRole(self: *Parser) !ast.Role {
        const kw = try self.expect(.keyword_role);
        const name = try self.parseIdent();
        _ = try self.expect(.l_brace);
        var description: ?[]const u8 = null;
        var targets: std.ArrayList([]const u8) = .empty;
        var requires_host: std.ArrayList([]const u8) = .empty;
        var requires_home: std.ArrayList([]const u8) = .empty;
        var conflicts_host: std.ArrayList([]const u8) = .empty;
        var conflicts_home: std.ArrayList([]const u8) = .empty;
        var host_block: ?ast.HostBlock = null;
        var home_block: ?ast.HomeBlock = null;

        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
            switch (self.peekKind()) {
                .keyword_description => {
                    _ = self.advance();
                    _ = try self.expect(.equal);
                    const s = try self.expect(.string_lit);
                    description = try self.unquote(s.lexeme);
                    _ = try self.expect(.semicolon);
                },
                .keyword_targets => {
                    _ = self.advance();
                    _ = try self.expect(.equal);
                    const list = try self.parseStringList();
                    for (list) |v| try targets.append(self.allocator, v);
                    _ = try self.expect(.semicolon);
                },
                .keyword_requires => {
                    _ = self.advance();
                    _ = try self.expect(.equal);
                    const list = try self.parseStringList();
                    for (list) |v| try requires_host.append(self.allocator, v);
                    _ = try self.expect(.semicolon);
                },
                .keyword_conflicts => {
                    _ = self.advance();
                    _ = try self.expect(.equal);
                    const list = try self.parseStringList();
                    for (list) |v| try conflicts_host.append(self.allocator, v);
                    _ = try self.expect(.semicolon);
                },
                .keyword_host => {
                    _ = self.advance();
                    const blk = try self.parseHostBlock();
                    host_block = blk;
                },
                .keyword_bundle, .ident => {
                    // home block may be `home { bundles = [...] ; }` but we simplified: `home` not keyword, treat as ident "home"
                    const t = self.peek();
                    if (std.mem.eql(u8, t.lexeme, "home")) {
                        _ = self.advance();
                        const blk = try self.parseHomeBlock();
                        home_block = blk;
                    } else {
                        const tt = self.advance();
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .parse_error,
                            .message = try std.fmt.allocPrint(self.allocator, "unexpected `{s}` in role", .{tt.lexeme}),
                            .span = tt.span,
                            .help = null,
                        });
                        return error.ParseError;
                    }
                },
                else => {
                    const t = self.advance();
                    try self.diag.push(.{
                        .severity = .err,
                        .code = .parse_error,
                        .message = try std.fmt.allocPrint(self.allocator, "unexpected `{s}` in role block", .{t.lexeme}),
                        .span = t.span,
                        .help = null,
                    });
                    // recovery
                    while (!self.isAtEnd() and self.peekKind() != .semicolon and self.peekKind() != .r_brace) _ = self.advance();
                    _ = self.consumeIf(.semicolon);
                },
            }
        }
        _ = try self.expect(.r_brace);
        return .{
            .name = name,
            .description = description,
            .targets = try targets.toOwnedSlice(self.allocator),
            .requires_host = try requires_host.toOwnedSlice(self.allocator),
            .requires_home = try requires_home.toOwnedSlice(self.allocator),
            .conflicts_host = try conflicts_host.toOwnedSlice(self.allocator),
            .conflicts_home = try conflicts_home.toOwnedSlice(self.allocator),
            .host = host_block,
            .home = home_block,
            .span = kw.span,
        };
    }

    fn parseStringList(self: *Parser) ![][]const u8 {
        _ = try self.expect(.l_bracket);
        var list: std.ArrayList([]const u8) = .empty;
        while (self.peekKind() != .r_bracket and !self.isAtEnd()) {
            const tok = self.peek();
            if (tok.kind == .string_lit) {
                _ = self.advance();
                const s = try self.unquote(tok.lexeme);
                try list.append(self.allocator, s);
            } else if (tok.kind == .ident) {
                _ = self.advance();
                const s = try self.dup(tok.lexeme);
                try list.append(self.allocator, s);
            } else {
                try self.diag.push(.{
                    .severity = .err,
                    .code = .parse_error,
                    .message = try std.fmt.allocPrint(self.allocator, "expected string in list, found `{s}`", .{tok.lexeme}),
                    .span = tok.span,
                    .help = null,
                });
                return error.ParseError;
            }
            _ = self.consumeIf(.comma);
        }
        _ = try self.expect(.r_bracket);
        return try list.toOwnedSlice(self.allocator);
    }

    fn parseHostBlock(self: *Parser) !ast.HostBlock {
        const start = try self.expect(.l_brace);
        var presets: std.ArrayList([]const u8) = .empty;
        var tags: std.ArrayList([]const u8) = .empty;
        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
            const t = self.peek();
            if (std.mem.eql(u8, t.lexeme, "presets")) {
                _ = self.advance();
                _ = try self.expect(.equal);
                const list = try self.parseStringList();
                for (list) |v| try presets.append(self.allocator, v);
                _ = try self.expect(.semicolon);
            } else if (std.mem.eql(u8, t.lexeme, "tags")) {
                _ = self.advance();
                _ = try self.expect(.equal);
                const list = try self.parseStringList();
                for (list) |v| try tags.append(self.allocator, v);
                _ = try self.expect(.semicolon);
            } else if (std.mem.eql(u8, t.lexeme, "bundles")) {
                _ = self.advance();
                _ = try self.expect(.equal);
                const list = try self.parseStringList();
                for (list) |v| try tags.append(self.allocator, v);
                _ = try self.expect(.semicolon);
            } else {
                const tt = self.advance();
                try self.diag.push(.{
                    .severity = .err,
                    .code = .parse_error,
                    .message = try std.fmt.allocPrint(self.allocator, "unexpected `{s}` in host block", .{tt.lexeme}),
                    .span = tt.span,
                    .help = null,
                });
                return error.ParseError;
            }
        }
        _ = try self.expect(.r_brace);
        return .{ .presets = try presets.toOwnedSlice(self.allocator), .tags = try tags.toOwnedSlice(self.allocator), .span = start.span };
    }

    fn parseHomeBlock(self: *Parser) !ast.HomeBlock {
        _ = try self.expect(.l_brace);
        var bundles: std.ArrayList([]const u8) = .empty;
        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
            const t = self.peek();
            if (std.mem.eql(u8, t.lexeme, "bundles")) {
                _ = self.advance();
                _ = try self.expect(.equal);
                const list = try self.parseStringList();
                for (list) |v| try bundles.append(self.allocator, v);
                _ = try self.expect(.semicolon);
            } else {
                const tt = self.advance();
                try self.diag.push(.{
                    .severity = .err,
                    .code = .parse_error,
                    .message = try std.fmt.allocPrint(self.allocator, "unexpected `{s}` in home block", .{tt.lexeme}),
                    .span = tt.span,
                    .help = null,
                });
                return error.ParseError;
            }
        }
        const end = try self.expect(.r_brace);
        return .{ .bundles = try bundles.toOwnedSlice(self.allocator), .span = end.span };
    }

    fn parseDottedPath(self: *Parser) !struct { path: []const u8, span: Span } {
        const first = try self.parseIdent();
        var buf: std.ArrayList(u8) = .empty;
        try buf.appendSlice(self.allocator, first.name);
        var span = first.span;
        while (self.peekKind() == .dot) {
            _ = self.advance();
            const next = try self.parseIdent();
            try buf.append(self.allocator, '.');
            try buf.appendSlice(self.allocator, next.name);
            span.len = @as(u32, @intCast((next.span.start + next.span.len) - span.start));
            span.end = next.span.end;
        }
        return .{ .path = try buf.toOwnedSlice(self.allocator), .span = span };
    }

    fn parseHost(self: *Parser) !ast.Host {
        const kw = try self.expect(.keyword_host);
        const name = try self.parseIdent();
        var extends: ?ast.Ident = null;
        if (self.peekKind() == .keyword_extends) {
            _ = self.advance();
            extends = try self.parseIdent();
        }
        _ = try self.expect(.l_brace);
        var stmts: std.ArrayList(ast.HostStmt) = .empty;
        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
            switch (self.peekKind()) {
                .keyword_let => {
                    const l = try self.parseLet();
                    try stmts.append(self.allocator, .{ .let_decl = l });
                },
                .keyword_use => {
                    _ = self.advance();
                    const id = try self.parseIdent();
                    _ = try self.expect(.semicolon);
                    try stmts.append(self.allocator, .{ .use_role = id });
                },
                .keyword_preset => {
                    _ = self.advance();
                    const id = try self.parseIdent();
                    _ = try self.expect(.semicolon);
                    try stmts.append(self.allocator, .{ .preset = id });
                },
                .keyword_package => {
                    _ = self.advance();
                    const s = try self.expect(.string_lit);
                    const pkg = try self.unquote(s.lexeme);
                    _ = try self.expect(.semicolon);
                    try stmts.append(self.allocator, .{ .package = pkg });
                },
                .ident => {
                    const path_info = try self.parseDottedPath();
                    if (self.peekKind() == .equal) {
                        _ = self.advance(); // =
                        if (std.mem.eql(u8, path_info.path, "packages")) {
                            const expr = try self.parseExpr(0);
                            _ = try self.expect(.semicolon);
                            if (expr.data == .ident) {
                                // preserve let ref as Setting, not stringified packages_assign
                                const path = try self.dup(path_info.path);
                                try stmts.append(self.allocator, .{ .setting = .{ .path = path, .value = expr, .span = path_info.span } });
                            } else if (expr.data == .list) {
                                // If list is all string literals, keep packages_assign for backwards compat
                                var all_strings = true;
                                for (expr.data.list) |item| {
                                    if (item.data != .string) all_strings = false;
                                }
                                if (all_strings) {
                                    var list: std.ArrayList([]const u8) = .empty;
                                    for (expr.data.list) |item| {
                                        switch (item.data) {
                                            .string => |s| try list.append(self.allocator, try self.allocator.dupe(u8, s)),
                                            else => {},
                                        }
                                    }
                                    try stmts.append(self.allocator, .{ .packages_assign = try list.toOwnedSlice(self.allocator) });
                                } else {
                                    // list contains ident/expr -> preserve as Setting with Expr
                                    const path = try self.dup(path_info.path);
                                    try stmts.append(self.allocator, .{ .setting = .{ .path = path, .value = expr, .span = path_info.span } });
                                }
                            } else {
                                // For other expr types (binary etc.), treat as setting with packages path
                                const path = try self.dup(path_info.path);
                                try stmts.append(self.allocator, .{ .setting = .{ .path = path, .value = expr, .span = path_info.span } });
                            }
                        } else {
                            const val = try self.parseExpr(0);
                            _ = try self.expect(.semicolon);
                            const path = try self.dup(path_info.path);
                            try stmts.append(self.allocator, .{ .setting = .{ .path = path, .value = val, .span = path_info.span } });
                        }
                    } else {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .parse_error,
                            .message = try std.fmt.allocPrint(self.allocator, "unexpected `{s}` in host, expected `=`", .{path_info.path}),
                            .span = path_info.span,
                            .help = null,
                        });
                        return error.ParseError;
                    }
                },
                .keyword_import => {
                    const imp = try self.parseImport();
                    try stmts.append(self.allocator, .{ .import = imp });
                },
                .keyword_microvm => {
                    const vm = try self.parseMicroVM();
                    try stmts.append(self.allocator, .{ .microvm = vm });
                },
                .keyword_nix => {
                    const nix_block = try self.parseNix();
                    try stmts.append(self.allocator, .{ .setting = .{ .path = "nix_raw", .value = .{ .span = nix_block.span, .data = .{ .string = nix_block.content } }, .span = nix_block.span } });
                },
                else => {
                    const t = self.advance();
                    try self.diag.push(.{
                        .severity = .err,
                        .code = .parse_error,
                        .message = try std.fmt.allocPrint(self.allocator, "unexpected `{s}` in host block", .{t.lexeme}),
                        .span = t.span,
                        .help = null,
                    });
                    return error.ParseError;
                },
            }
        }
        _ = try self.expect(.r_brace);
        return .{ .name = name, .extends = extends, .stmts = try stmts.toOwnedSlice(self.allocator), .span = kw.span };
    }

    fn parseMicroVM(self: *Parser) !ast.MicroVM {
        const kw = try self.expect(.keyword_microvm);
        const name = try self.parseIdent();
        _ = try self.expect(.l_brace);
        var mem: ?i64 = null;
        var mem_type: ?ast.Type = null;
        var cpu: ?i64 = null;
        var cpu_type: ?ast.Type = null;
        var net: ?[]const u8 = null;
        var net_type: ?ast.Type = null;
        var ip: ?[]const u8 = null;
        var ip_type: ?ast.Type = null;
        var volumes: std.ArrayList(ast.Volume) = .empty;
        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
            if (self.peekKind() == .keyword_volume) {
                _ = self.advance(); // volume
                var vol_name: ?ast.Ident = null;
                var vol_type: ?ast.Type = null;
                // optional volume name
                if (self.peekKind() == .ident or isKeywordIdent(self.peekKind())) {
                    // Check if next after ident is ":" or "{" — if "{" then it's name without type
                    // Save position to peek
                    const saved = self.pos;
                    const ident = try self.parseIdent();
                    if (self.peekKind() == .colon) {
                        _ = self.advance(); // :
                        if (self.peekKind() == .l_brace) {
                            // volume data {  — actually data: without type, but we consumed ":", so this is volume data: { (no type)
                            vol_name = ident;
                        } else {
                            // Try parse type
                            const maybe_type: ?ast.Type = blk: {
                                const save2 = self.pos;
                                const t = self.parseType() catch {
                                    self.pos = save2;
                                    break :blk null;
                                };
                                break :blk t;
                            };
                            if (maybe_type) |t| {
                                vol_type = t;
                                vol_name = ident;
                            } else {
                                // Not a type, backtrack — treat as no name?
                                self.pos = saved;
                            }
                        }
                    } else if (self.peekKind() == .l_brace) {
                        vol_name = ident;
                    } else {
                        // Not a volume name, backtrack
                        self.pos = saved;
                    }
                } else if (self.consumeIf(.colon) != null) {
                    vol_type = try self.parseType();
                }
                _ = try self.expect(.l_brace);
                var image: ?[]const u8 = null;
                var mountPoint: ?[]const u8 = null;
                var size: ?i64 = null;
                var user: ?[]const u8 = null;
                var group: ?[]const u8 = null;
                const vol_span = self.tokens[self.pos - 1].span;
                while (self.peekKind() != .r_brace and !self.isAtEnd()) {
                    const f_tok = self.advance();
                    if (f_tok.kind != .ident and !isKeywordIdent(f_tok.kind)) {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .parse_error,
                            .message = try std.fmt.allocPrint(self.allocator, "expected volume field, found `{s}`", .{f_tok.lexeme}),
                            .span = f_tok.span,
                            .help = "expected `image`, `mountPoint`, `size`, `user`, `group`",
                        });
                        return error.ParseError;
                    }
                    const fname = f_tok.lexeme;
                    // volume field may be `field = value;` or `field: Type = value;` or `field: value;`
                    var field_type: ?ast.Type = null;
                    if (self.consumeIf(.colon) != null) {
                        // Check if next is type or value
                        // If next is ident that is known type and after that is "=", then it's type
                        _ = blk: {
                            if (self.peekKind() != .ident and !isKeywordIdent(self.peekKind())) break :blk false;
                            const n = self.peek().lexeme;
                            const known = std.mem.eql(u8, n, "String") or std.mem.eql(u8, n, "string") or std.mem.eql(u8, n, "str") or std.mem.eql(u8, n, "bool") or std.mem.eql(u8, n, "i32") or std.mem.eql(u8, n, "i64") or std.mem.eql(u8, n, "u32") or std.mem.eql(u8, n, "u64") or std.mem.eql(u8, n, "usize") or std.mem.eql(u8, n, "Path") or std.mem.eql(u8, n, "Ipv4") or std.mem.eql(u8, n, "Duration") or std.mem.eql(u8, n, "List") or std.mem.eql(u8, n, "Vec") or std.mem.eql(u8, n, "Option");
                            if (!known) break :blk false;
                            // Look ahead after type to see if "="
                            // Save and try parse type
                            const save = self.pos;
                            const t = self.parseType() catch {
                                self.pos = save;
                                break :blk false;
                            };
                            if (self.peekKind() == .equal) {
                                field_type = t;
                                break :blk true;
                            } else {
                                self.pos = save;
                                break :blk false;
                            }
                        };
                            if (field_type == null) {
                            if (self.consumeIf(.equal) != null) {
                            } else {
                                // No "=", value follows directly after ":"
                            }
                        } else {
                            // field_type already set, now expect "="
                            if (self.consumeIf(.equal) != null) {
                            } else {
                                // For `field: Type = value`, we need "="
                                // If no "=", treat as error but allow value without "="
                            }
                        }
                    } else if (self.consumeIf(.equal) != null) {
                    } else {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .parse_error,
                            .message = try std.fmt.allocPrint(self.allocator, "expected `:` or `=` after field `{s}`", .{fname}),
                            .span = f_tok.span,
                            .help = null,
                        });
                        return error.ParseError;
                    }
                    const fval = try self.parseExpr(0);
                    _ = try self.expect(.semicolon);
                    if (std.mem.eql(u8, fname, "image")) {
                        if (fval.data == .string) image = try self.dup(fval.data.string) else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "image must be string", .span = fval.span, .help = "example: image = \"data.img\";" });
                            return error.ParseError;
                        }
                    } else if (std.mem.eql(u8, fname, "mountPoint") or std.mem.eql(u8, fname, "mount_point") or std.mem.eql(u8, fname, "mount")) {
                        if (fval.data == .string) mountPoint = try self.dup(fval.data.string) else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "mountPoint must be string", .span = fval.span, .help = "example: mountPoint = \"/var/lib/data\";" });
                            return error.ParseError;
                        }
                    } else if (std.mem.eql(u8, fname, "size")) {
                        const iv = blk: {
                            if (fval.data == .integer) break :blk fval.data.integer;
                            if (fval.data == .unary and fval.data.unary.op == .neg and fval.data.unary.expr.*.data == .integer) break :blk -fval.data.unary.expr.*.data.integer;
                            break :blk null;
                        };
                        if (iv) |v| size = v else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "size must be integer", .span = fval.span, .help = "example: size = 1024;" });
                            return error.ParseError;
                        }
                    } else if (std.mem.eql(u8, fname, "user")) {
                        if (fval.data == .string) user = try self.dup(fval.data.string) else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "user must be string", .span = fval.span, .help = null });
                            return error.ParseError;
                        }
                    } else if (std.mem.eql(u8, fname, "group")) {
                        if (fval.data == .string) group = try self.dup(fval.data.string) else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "group must be string", .span = fval.span, .help = null });
                            return error.ParseError;
                        }
                    } else {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .parse_error,
                            .message = try std.fmt.allocPrint(self.allocator, "unknown volume field `{s}`", .{fname}),
                            .span = f_tok.span,
                            .help = "expected `image`, `mountPoint`, `size`",
                        });
                        return error.ParseError;
                    }
                }
                _ = try self.expect(.r_brace);
                if (image == null) {
                    try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "volume missing `image`", .span = vol_span, .help = null });
                    return error.ParseError;
                }
                if (mountPoint == null) {
                    try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "volume missing `mountPoint`", .span = vol_span, .help = null });
                    return error.ParseError;
                }
                if (size == null) {
                    try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "volume missing `size`", .span = vol_span, .help = null });
                    return error.ParseError;
                }
                try volumes.append(self.allocator, .{
                    .name = vol_name,
                    .type_annot = vol_type,
                    .image = image.?,
                    .mountPoint = mountPoint.?,
                    .size = size.?,
                    .user = user,
                    .group = group,
                    .span = vol_span,
                });
                _ = self.consumeIf(.semicolon);
                continue;
            }
            const field_tok = self.advance();
            if (field_tok.kind != .ident and !isKeywordIdent(field_tok.kind)) {
                try self.diag.push(.{
                    .severity = .err,
                    .code = .parse_error,
                    .message = try std.fmt.allocPrint(self.allocator, "expected field name in microvm, found `{s}`", .{field_tok.lexeme}),
                    .span = field_tok.span,
                    .help = "expected `mem`, `cpu`, `net`, `ip` or `volume`",
                });
                return error.ParseError;
            }
            const field_name = field_tok.lexeme;
            var field_type: ?ast.Type = null;
            if (self.consumeIf(.colon) != null) {
                // Check if next is type
                const is_known_type = blk: {
                    if (self.peekKind() != .ident and !isKeywordIdent(self.peekKind())) break :blk false;
                    const n = self.peek().lexeme;
                    if (std.mem.eql(u8, n, "String") or std.mem.eql(u8, n, "string") or std.mem.eql(u8, n, "str") or std.mem.eql(u8, n, "bool") or std.mem.eql(u8, n, "i32") or std.mem.eql(u8, n, "i64") or std.mem.eql(u8, n, "u32") or std.mem.eql(u8, n, "u64") or std.mem.eql(u8, n, "usize") or std.mem.eql(u8, n, "Path") or std.mem.eql(u8, n, "Ipv4") or std.mem.eql(u8, n, "Duration") or std.mem.eql(u8, n, "List") or std.mem.eql(u8, n, "Vec") or std.mem.eql(u8, n, "Option")) break :blk true;
                    break :blk false;
                };
                if (is_known_type) {
                    const save = self.pos;
                    const t: ?ast.Type = blk: {
                        const tmp = self.parseType() catch {
                            self.pos = save;
                            break :blk null;
                        };
                        break :blk tmp;
                    };
                    if (t) |tt| {
                        if (self.peekKind() == .equal) {
                            field_type = tt;
                            _ = self.advance(); // consume "="
                        } else {
                            // No "=", maybe it's just `mem: 768` without type? But we parsed type, and next is not "=", so this was not type
                            self.pos = save;
                            // Then value follows directly after ":", no type
                            field_type = null;
                        }
                    }
                    if (field_type == null) {
                        // No type found, value follows after ":"
                        // Do nothing, will parse value below
                    }
                }
                if (field_type == null) {
                    // For `mem: 768` or `mem: "lan"` where no type, we already consumed ":", now parse value
                    // No "=" needed
                }
                // If we consumed "=", we already have field_type and "=", else we need to parse value
                // For `mem: u32 = 768`, we consumed ":" + type + "=", now parse value
                // For `mem: 768`, we consumed ":", now parse value
                // So if we haven't yet consumed "=", and we are in `mem: u32 =` case, we already consumed "="
                // For `mem: 768` case, we need to parse value directly
                // For `mem = 768` case (old), we wouldn't be in this branch (we would have taken equal branch)
                // So handle accordingly
                if (field_type == null) {
                    // No type, parse value after ":"
                    const val = try self.parseExpr(0);
                    _ = try self.expect(.semicolon);
                    if (std.mem.eql(u8, field_name, "mem")) {
                        const int_val = blk: {
                            if (val.data == .integer) break :blk val.data.integer;
                            if (val.data == .unary and val.data.unary.op == .neg and val.data.unary.expr.*.data == .integer) break :blk -val.data.unary.expr.*.data.integer;
                            break :blk null;
                        };
                        if (int_val) |v| {
                            mem = v;
                        } else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "mem must be integer", .span = val.span, .help = "example: mem = 512; or mem: u32 = 512;" });
                            return error.ParseError;
                        }
                    } else if (std.mem.eql(u8, field_name, "cpu") or std.mem.eql(u8, field_name, "vcpu")) {
                        const int_val = blk: {
                            if (val.data == .integer) break :blk val.data.integer;
                            if (val.data == .unary and val.data.unary.op == .neg and val.data.unary.expr.*.data == .integer) break :blk -val.data.unary.expr.*.data.integer;
                            break :blk null;
                        };
                        if (int_val) |v| {
                            cpu = v;
                        } else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "cpu must be integer", .span = val.span, .help = "example: cpu = 1;" });
                            return error.ParseError;
                        }
                    } else if (std.mem.eql(u8, field_name, "net")) {
                        if (val.data == .string) {
                            net = try self.dup(val.data.string);
                        } else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "net must be string", .span = val.span, .help = "example: net = \"lan\";" });
                            return error.ParseError;
                        }
                    } else if (std.mem.eql(u8, field_name, "ip")) {
                        if (val.data == .string) {
                            ip = try self.dup(val.data.string);
                        } else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "ip must be string", .span = val.span, .help = "example: ip = \"10.8.0.2\";" });
                            return error.ParseError;
                        }
                    } else {
                        try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = try std.fmt.allocPrint(self.allocator, "unknown microvm field `{s}`", .{field_name}), .span = field_tok.span, .help = "expected `mem`, `cpu`, `net`, `ip`, `volume`" });
                        return error.ParseError;
                    }
                    continue;
                } else {
                    // field_type is set, we already consumed "=", now parse value
                    const val = try self.parseExpr(0);
                    _ = try self.expect(.semicolon);
                    if (std.mem.eql(u8, field_name, "mem")) {
                        const int_val = blk: {
                            if (val.data == .integer) break :blk val.data.integer;
                            if (val.data == .unary and val.data.unary.op == .neg and val.data.unary.expr.*.data == .integer) break :blk -val.data.unary.expr.*.data.integer;
                            break :blk null;
                        };
                        if (int_val) |v| {
                            mem = v;
                            mem_type = field_type;
                        } else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "mem must be integer", .span = val.span, .help = "example: mem = 512; or mem: u32 = 512;" });
                            return error.ParseError;
                        }
                    } else if (std.mem.eql(u8, field_name, "cpu") or std.mem.eql(u8, field_name, "vcpu")) {
                        const int_val = blk: {
                            if (val.data == .integer) break :blk val.data.integer;
                            if (val.data == .unary and val.data.unary.op == .neg and val.data.unary.expr.*.data == .integer) break :blk -val.data.unary.expr.*.data.integer;
                            break :blk null;
                        };
                        if (int_val) |v| {
                            cpu = v;
                            cpu_type = field_type;
                        } else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "cpu must be integer", .span = val.span, .help = "example: cpu = 1;" });
                            return error.ParseError;
                        }
                    } else if (std.mem.eql(u8, field_name, "net")) {
                        if (val.data == .string) {
                            net = try self.dup(val.data.string);
                            net_type = field_type;
                        } else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "net must be string", .span = val.span, .help = "example: net = \"lan\";" });
                            return error.ParseError;
                        }
                    } else if (std.mem.eql(u8, field_name, "ip")) {
                        if (val.data == .string) {
                            ip = try self.dup(val.data.string);
                            ip_type = field_type;
                        } else {
                            try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "ip must be string", .span = val.span, .help = "example: ip = \"10.8.0.2\";" });
                            return error.ParseError;
                        }
                    } else {
                        try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = try std.fmt.allocPrint(self.allocator, "unknown microvm field `{s}`", .{field_name}), .span = field_tok.span, .help = "expected `mem`, `cpu`, `net`, `ip`, `volume`" });
                        return error.ParseError;
                    }
                    continue;
                }
            }
            // old syntax `mem = 768;` (equal without colon)
            _ = try self.expect(.equal);
            const val = try self.parseExpr(0);
            _ = try self.expect(.semicolon);
            if (std.mem.eql(u8, field_name, "mem")) {
                const int_val = blk: {
                    if (val.data == .integer) break :blk val.data.integer;
                    if (val.data == .unary and val.data.unary.op == .neg and val.data.unary.expr.*.data == .integer) break :blk -val.data.unary.expr.*.data.integer;
                    break :blk null;
                };
                if (int_val) |v| {
                    mem = v;
                } else {
                    try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "mem must be integer", .span = val.span, .help = "example: mem = 512;" });
                    return error.ParseError;
                }
            } else if (std.mem.eql(u8, field_name, "cpu") or std.mem.eql(u8, field_name, "vcpu")) {
                const int_val = blk: {
                    if (val.data == .integer) break :blk val.data.integer;
                    if (val.data == .unary and val.data.unary.op == .neg and val.data.unary.expr.*.data == .integer) break :blk -val.data.unary.expr.*.data.integer;
                    break :blk null;
                };
                if (int_val) |v| {
                    cpu = v;
                } else {
                    try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "cpu must be integer", .span = val.span, .help = "example: cpu = 1;" });
                    return error.ParseError;
                }
            } else if (std.mem.eql(u8, field_name, "net")) {
                if (val.data == .string) {
                    net = try self.dup(val.data.string);
                } else {
                    try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "net must be string", .span = val.span, .help = "example: net = \"lan\";" });
                    return error.ParseError;
                }
            } else if (std.mem.eql(u8, field_name, "ip")) {
                if (val.data == .string) {
                    ip = try self.dup(val.data.string);
                } else {
                    try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = "ip must be string", .span = val.span, .help = "example: ip = \"10.8.0.2\";" });
                    return error.ParseError;
                }
            } else {
                try self.diag.push(.{ .severity = .err, .code = .parse_error, .message = try std.fmt.allocPrint(self.allocator, "unknown microvm field `{s}`", .{field_name}), .span = field_tok.span, .help = "expected `mem`, `cpu`, `net`, `ip`, `volume`" });
                return error.ParseError;
            }
        }
        _ = try self.expect(.r_brace);
        return .{ .name = name, .mem = mem, .mem_type = mem_type, .cpu = cpu, .cpu_type = cpu_type, .net = net, .net_type = net_type, .ip = ip, .ip_type = ip_type, .volumes = try volumes.toOwnedSlice(self.allocator), .span = kw.span };
    }

    fn parseValue(self: *Parser) anyerror!ast.Expr {
        return self.parseExpr(0);
    }

    fn parseExpr(self: *Parser, min_prec: u8) anyerror!ast.Expr {
        var lhs = try self.parsePrimary();
        while (true) {
            const op_prec = self.getPrecedence(self.peekKind());
            if (op_prec == null or op_prec.? < min_prec) break;
            const op_token = self.advance();
            const op = self.tokenToBinaryOp(op_token.kind) orelse break;
            const next_min = op_prec.? + 1;
            const rhs = try self.parseExpr(next_min);
            const span: Span = .{ .file = lhs.span.file, .line = lhs.span.line, .col = lhs.span.col, .len = @as(u32, @intCast((rhs.span.end - lhs.span.start))), .start = lhs.span.start, .end = rhs.span.end };
            const lhs_ptr = try self.allocator.create(ast.Expr);
            lhs_ptr.* = lhs;
            const rhs_ptr = try self.allocator.create(ast.Expr);
            rhs_ptr.* = rhs;
            lhs = .{ .span = span, .data = .{ .binary = .{ .op = op, .lhs = lhs_ptr, .rhs = rhs_ptr, .span = span } } };
        }
        return lhs;
    }

    fn parsePrimary(self: *Parser) anyerror!ast.Expr {
        const t = self.peek();
        switch (t.kind) {
            .string_lit => {
                _ = self.advance();
                const s = try self.unquote(t.lexeme);
                return .{ .span = t.span, .data = .{ .string = s } };
            },
            .integer => {
                _ = self.advance();
                const v = try std.fmt.parseInt(i64, t.lexeme, 10);
                return .{ .span = t.span, .data = .{ .integer = v } };
            },
            .keyword_true => {
                _ = self.advance();
                return .{ .span = t.span, .data = .{ .boolean = true } };
            },
            .keyword_false => {
                _ = self.advance();
                return .{ .span = t.span, .data = .{ .boolean = false } };
            },
            .l_bracket => {
                const list = try self.parseExprList();
                return .{ .span = t.span, .data = .{ .list = list } };
            },
            .l_paren => {
                const l_span = t.span;
                _ = self.advance();
                const expr = try self.parseExpr(0);
                _ = try self.expect(.r_paren);
                const r_span = self.tokens[self.pos - 1].span;
                const span: Span = .{ .file = l_span.file, .line = l_span.line, .col = l_span.col, .len = @as(u32, @intCast((r_span.end - l_span.start))), .start = l_span.start, .end = r_span.end };
                const ptr = try self.allocator.create(ast.Expr);
                ptr.* = expr;
                return .{ .span = span, .data = .{ .paren = ptr } };
            },
            .ident => {
                _ = self.advance();
                const id = ast.Ident{ .name = try self.dup(t.lexeme), .span = t.span };
                return .{ .span = t.span, .data = .{ .ident = id } };
            },
            .bang, .minus => {
                const op_tok = self.advance();
                const op: ast.UnaryOp = if (op_tok.kind == .bang) .not else .neg;
                const expr = try self.parsePrimary();
                const span: Span = .{ .file = op_tok.span.file, .line = op_tok.span.line, .col = op_tok.span.col, .len = @as(u32, @intCast((expr.span.end - op_tok.span.start))), .start = op_tok.span.start, .end = expr.span.end };
                const ptr = try self.allocator.create(ast.Expr);
                ptr.* = expr;
                return .{ .span = span, .data = .{ .unary = .{ .op = op, .expr = ptr, .span = span } } };
            },
            else => {
                try self.diag.push(.{
                    .severity = .err,
                    .code = .parse_error,
                    .message = try std.fmt.allocPrint(self.allocator, "expected value, found `{s}`", .{t.lexeme}),
                    .span = t.span,
                    .help = null,
                });
                return error.ParseError;
            },
        }
    }

    fn getPrecedence(self: *Parser, kind: lexer.TokenKind) ?u8 {
        _ = self;
        return switch (kind) {
            .pipe_pipe => 1,
            .amp_amp => 2,
            .equal_equal, .bang_equal => 3,
            .lt, .gt, .lte, .gte => 4,
            .plus, .minus => 5,
            .star, .slash, .percent => 6,
            else => null,
        };
    }

    fn tokenToBinaryOp(self: *Parser, kind: lexer.TokenKind) ?ast.BinaryOp {
        _ = self;
        return switch (kind) {
            .plus => .add,
            .minus => .sub,
            .star => .mul,
            .slash => .div,
            .percent => .mod,
            .equal_equal => .eq,
            .bang_equal => .neq,
            .amp_amp => .logical_and,
            .pipe_pipe => .logical_or,
            .lt => .lt,
            .gt => .gt,
            .lte => .lte,
            .gte => .gte,
            else => null,
        };
    }

    fn parseExprList(self: *Parser) anyerror![]ast.Expr {
        _ = try self.expect(.l_bracket);
        var list: std.ArrayList(ast.Expr) = .empty;
        while (self.peekKind() != .r_bracket and !self.isAtEnd()) {
            const v = try self.parseExpr(0);
            try list.append(self.allocator, v);
            _ = self.consumeIf(.comma);
        }
        _ = try self.expect(.r_bracket);
        return try list.toOwnedSlice(self.allocator);
    }

    fn parseValueList(self: *Parser) anyerror![]ast.Value {
        _ = try self.expect(.l_bracket);
        var list: std.ArrayList(ast.Value) = .empty;
        while (self.peekKind() != .r_bracket and !self.isAtEnd()) {
            const v = try self.parseValue();
            const val: ast.Value = switch (v.data) {
                .string => |s| .{ .string = s },
                .integer => |i| .{ .integer = i },
                .boolean => |b| .{ .boolean = b },
                .ident => |id| .{ .ident = id },
                else => .{ .string = "" }, // fallback for binary etc.
            };
            try list.append(self.allocator, val);
            _ = self.consumeIf(.comma);
        }
        _ = try self.expect(.r_bracket);
        return try list.toOwnedSlice(self.allocator);
    }

    fn parseBundle(self: *Parser) !ast.Bundle {
        const kw = try self.expect(.keyword_bundle);
        const name = try self.parseIdent();
        _ = try self.expect(.l_brace);
        var description: ?[]const u8 = null;
        var programs: std.ArrayList([]const u8) = .empty;
        var toggles: std.ArrayList([]const u8) = .empty;
        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
            switch (self.peekKind()) {
                .keyword_description => {
                    _ = self.advance();
                    _ = try self.expect(.equal);
                    const s = try self.expect(.string_lit);
                    description = try self.unquote(s.lexeme);
                    _ = try self.expect(.semicolon);
                },
                else => {
                    const t = self.peek();
                    if (std.mem.eql(u8, t.lexeme, "programs")) {
                        _ = self.advance();
                        _ = try self.expect(.equal);
                        const list = try self.parseStringList();
                        for (list) |v| try programs.append(self.allocator, v);
                        _ = try self.expect(.semicolon);
                    } else if (std.mem.eql(u8, t.lexeme, "packages") or std.mem.eql(u8, t.lexeme, "packageToggles") or std.mem.eql(u8, t.lexeme, "toggles")) {
                        _ = self.advance();
                        _ = try self.expect(.equal);
                        const list = try self.parseStringList();
                        for (list) |v| try toggles.append(self.allocator, v);
                        _ = try self.expect(.semicolon);
                    } else {
                        const tt = self.advance();
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .parse_error,
                            .message = try std.fmt.allocPrint(self.allocator, "unexpected `{s}` in bundle", .{tt.lexeme}),
                            .span = tt.span,
                            .help = "expected `description`, `programs` or `packages`",
                        });
                        // recovery: skip to ; or }
                        while (!self.isAtEnd() and self.peekKind() != .semicolon and self.peekKind() != .r_brace) _ = self.advance();
                        _ = self.consumeIf(.semicolon);
                    }
                },
            }
        }
        _ = try self.expect(.r_brace);
        return .{
            .name = name,
            .description = description,
            .programs = try programs.toOwnedSlice(self.allocator),
            .package_toggles = try toggles.toOwnedSlice(self.allocator),
            .span = kw.span,
        };
    }

    fn parsePreset(self: *Parser) !ast.Preset {
        const kw = try self.expect(.keyword_preset);
        const name = try self.parseIdent();
        _ = try self.expect(.l_brace);
        var description: ?[]const u8 = null;
        var flags: std.ArrayList(ast.Setting) = .empty;
        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
            switch (self.peekKind()) {
                .keyword_description => {
                    _ = self.advance();
                    _ = try self.expect(.equal);
                    const s = try self.expect(.string_lit);
                    description = try self.unquote(s.lexeme);
                    _ = try self.expect(.semicolon);
                },
                else => {
                    const t = self.peek();
                    if (std.mem.eql(u8, t.lexeme, "flags")) {
                        _ = self.advance();
                        _ = try self.expect(.l_brace);
                        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
                            // flags block: setting `path = value;` with dotted path
                            const path_info = self.parseDottedPath() catch {
                                const tt = self.advance();
                                try self.diag.push(.{
                                    .severity = .err,
                                    .code = .parse_error,
                                    .message = try std.fmt.allocPrint(self.allocator, "expected setting path, found `{s}`", .{tt.lexeme}),
                                    .span = tt.span,
                                    .help = null,
                                });
                                while (!self.isAtEnd() and self.peekKind() != .semicolon and self.peekKind() != .r_brace) _ = self.advance();
                                _ = self.consumeIf(.semicolon);
                                continue;
                            };
                            _ = try self.expect(.equal);
                            const val = try self.parseValue();
                            _ = try self.expect(.semicolon);
                            const path = try self.dup(path_info.path);
                            try flags.append(self.allocator, .{ .path = path, .value = val, .span = path_info.span });
                        }
                        _ = try self.expect(.r_brace);
                    } else {
                        const tt = self.advance();
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .parse_error,
                            .message = try std.fmt.allocPrint(self.allocator, "unexpected `{s}` in preset", .{tt.lexeme}),
                            .span = tt.span,
                            .help = "expected `description` or `flags { ... }`",
                        });
                        while (!self.isAtEnd() and self.peekKind() != .semicolon and self.peekKind() != .r_brace) _ = self.advance();
                        _ = self.consumeIf(.semicolon);
                    }
                },
            }
        }
        _ = try self.expect(.r_brace);
        return .{ .name = name, .description = description, .flags = try flags.toOwnedSlice(self.allocator), .span = kw.span };
    }

    fn parsePackage(self: *Parser) !ast.Package {
        const kw = try self.expect(.keyword_package);
        const s = try self.expect(.string_lit);
        const name = try self.unquote(s.lexeme);
        _ = try self.expect(.semicolon);
        return .{ .name = name, .span = kw.span };
    }

    fn parseNix(self: *Parser) !ast.NixBlock {
        const kw = try self.expect(.keyword_nix);
        const l = try self.expect(.l_brace);
        var depth: usize = 1;
        const start_off = l.span.end; // byte offset after '{'
        var end_off: usize = start_off;
        // track depth to find matching '}' ; use token spans for raw slice if source available
        var content: []const u8 = "";
        // First, find matching brace via token walk without consuming for slice path
        const probe_pos = self.pos;
        var d: usize = 1;
        var idx = self.pos;
        while (idx < self.tokens.len and d > 0) : (idx += 1) {
            const k = self.tokens[idx].kind;
            if (k == .l_brace) d += 1 else if (k == .r_brace) {
                d -= 1;
                if (d == 0) {
                    end_off = self.tokens[idx].span.start;
                    break;
                }
            }
        }
        if (d != 0) {
            try self.diag.push(.{
                .severity = .err,
                .code = .parse_error,
                .message = "unterminated nix block",
                .span = l.span,
                .help = null,
            });
            return error.ParseError;
        }
        // If we have source, slice it directly to preserve formatting
        if (self.source.len > 0 and end_off <= self.source.len and start_off <= end_off) {
            const raw = self.source[start_off..end_off];
            content = try self.allocator.dupe(u8, raw);
        } else {
            // fallback: collect lexemes (for tests without source)
            var buf: std.ArrayList(u8) = .empty;
            while (!self.isAtEnd() and depth > 0) {
                const t = self.advance();
                if (t.kind == .l_brace) depth += 1 else if (t.kind == .r_brace) {
                    depth -= 1;
                    if (depth == 0) break;
                }
                try buf.appendSlice(self.allocator, t.lexeme);
                try buf.append(self.allocator, ' ');
            }
            content = try buf.toOwnedSlice(self.allocator);
            return .{ .content = content, .span = kw.span };
        }
        // consume tokens up to matching '}' (we probed without consuming)
        while (self.pos < idx) _ = self.advance();
        // consume the closing '}'
        _ = self.advance();
        _ = probe_pos;
        return .{ .content = content, .span = kw.span };
    }
};

test "parser host" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host x270 { use desktop; package \"git\"; }";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.meow", source);
    var lex = lexer.Lexer.init(source, "test.meow", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = Parser.init(toks, &diag, &arena);
    const prog = try parser.parseProgram();
    try std.testing.expect(prog.decls.len == 1);
    try std.testing.expect(prog.decls[0] == .host);
}

test "parser host extends" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host web extends base { use gaming; } host base { use desktop; }";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = Parser.initWithSource(toks, &diag, &arena, source);
    const prog = try parser.parseProgram();
    try std.testing.expect(prog.decls.len == 2);
    try std.testing.expect(prog.decls[0].host.extends != null);
    try std.testing.expectEqualStrings("base", prog.decls[0].host.extends.?.name);
    try std.testing.expect(prog.decls[1].host.extends == null);
}

test "parser let typed primitives" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const cases = [_]struct { src: []const u8, type_name: []const u8 }{
        .{ .src = "let x: u32 = 1;", .type_name = "u32" },
        .{ .src = "let s: String = \"foo\";", .type_name = "String" },
        .{ .src = "let b: bool = true;", .type_name = "bool" },
        .{ .src = "let v: Ipv4 = \"10.8.0.2\";", .type_name = "Ipv4" },
        .{ .src = "let p: Path = \"/var/lib/data\";", .type_name = "Path" },
    };
    for (cases) |c| {
        var arena2 = std.heap.ArenaAllocator.init(alloc);
        defer arena2.deinit();
        var diag = diagnostics.Diagnostics.init(arena2.allocator(), "test.purr", c.src);
        var lex = lexer.Lexer.init(c.src, "test.purr", &diag);
        const toks = try lex.lexAll(arena2.allocator());
        var parser = Parser.initWithSource(toks, &diag, &arena2, c.src);
        const prog = try parser.parseProgram();
        try std.testing.expect(prog.decls.len == 1);
        try std.testing.expect(prog.decls[0] == .let_decl);
        try std.testing.expect(prog.decls[0].let_decl.type_annot != null);
        try std.testing.expect(!diag.hasErrors());
    }
}

test "parser microvm typed fields" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\microvm grafana {
        \\    mem: u32 = 768;
        \\    cpu: u32 = 2;
        \\    ip: Ipv4 = "10.8.0.2";
        \\    net: String = "lan";
        \\}
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = Parser.initWithSource(toks, &diag, &arena, source);
    const prog = try parser.parseProgram();
    try std.testing.expect(prog.decls.len == 1);
    const vm = prog.decls[0].microvm;
    try std.testing.expect(vm.mem != null);
    try std.testing.expect(vm.mem.? == 768);
    try std.testing.expect(vm.mem_type != null);
    try std.testing.expect(vm.mem_type.?.data == .u32);
    try std.testing.expect(vm.cpu_type != null);
    try std.testing.expect(vm.ip_type != null);
    try std.testing.expect(vm.ip_type.?.data == .ipv4);
    try std.testing.expect(vm.net_type != null);
    try std.testing.expect(vm.net_type.?.data == .string);
    try std.testing.expect(!diag.hasErrors());
}

test "parser volume typed struct" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source =
        \\microvm grafana {
        \\    mem: u32 = 768;
        \\    volume data: Volume {
        \\        image: "grafana";
        \\        mount_point: "/var/lib/grafana";
        \\        size: 10240;
        \\    }
        \\}
    ;
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = Parser.initWithSource(toks, &diag, &arena, source);
    const prog = try parser.parseProgram();
    try std.testing.expect(prog.decls.len == 1);
    const vm = prog.decls[0].microvm;
    try std.testing.expect(vm.volumes.len == 1);
    const vol = vm.volumes[0];
    try std.testing.expect(vol.name != null);
    try std.testing.expectEqualStrings("data", vol.name.?.name);
    try std.testing.expect(vol.type_annot != null);
    try std.testing.expect(vol.type_annot.?.data == .named);
    try std.testing.expectEqualStrings("Volume", vol.type_annot.?.data.named);
    try std.testing.expectEqualStrings("grafana", vol.image);
    try std.testing.expectEqualStrings("/var/lib/grafana", vol.mountPoint);
    try std.testing.expect(vol.size == 10240);
    try std.testing.expect(!diag.hasErrors());
}

test "parser generic types List and Option" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const cases = [_]struct { src: []const u8, outer: []const u8 }{
        .{ .src = "let x: List<u32> = [1, 2, 3];", .outer = "list" },
        .{ .src = "let y: Option<String> = \"foo\";", .outer = "option" },
        .{ .src = "let z: Vec<u64> = [1];", .outer = "list" },
    };
    for (cases) |c| {
        var arena2 = std.heap.ArenaAllocator.init(alloc);
        defer arena2.deinit();
        var diag = diagnostics.Diagnostics.init(arena2.allocator(), "test.purr", c.src);
        var lex = lexer.Lexer.init(c.src, "test.purr", &diag);
        const toks = try lex.lexAll(arena2.allocator());
        var parser = Parser.initWithSource(toks, &diag, &arena2, c.src);
        const prog = try parser.parseProgram();
        try std.testing.expect(prog.decls[0] == .let_decl);
        const ty = prog.decls[0].let_decl.type_annot.?;
        if (std.mem.eql(u8, c.outer, "list")) {
            try std.testing.expect(ty.data == .list);
        } else {
            try std.testing.expect(ty.data == .option);
        }
        try std.testing.expect(!diag.hasErrors());
    }
}

test "parser typed let and microvm backward compat" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    // Old syntax without types should still parse
    const source1 = "let x = 1;";
    var diag1 = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source1);
    var lex1 = lexer.Lexer.init(source1, "test.purr", &diag1);
    const toks1 = try lex1.lexAll(arena.allocator());
    var p1 = Parser.initWithSource(toks1, &diag1, &arena, source1);
    const prog1 = try p1.parseProgram();
    try std.testing.expect(prog1.decls[0].let_decl.type_annot == null);
    try std.testing.expect(!diag1.hasErrors());

    const source2 = "microvm grafana { mem = 512; volume { image = \"a.img\"; mountPoint = \"/a\"; size = 1024; } }";
    var arena3 = std.heap.ArenaAllocator.init(alloc);
    defer arena3.deinit();
    var diag2 = diagnostics.Diagnostics.init(arena3.allocator(), "test.purr", source2);
    var lex2 = lexer.Lexer.init(source2, "test.purr", &diag2);
    const toks2 = try lex2.lexAll(arena3.allocator());
    var p2 = Parser.initWithSource(toks2, &diag2, &arena3, source2);
    const prog2 = try p2.parseProgram();
    try std.testing.expect(prog2.decls[0].microvm.mem_type == null);
    try std.testing.expect(!diag2.hasErrors());
}

test "parser typed syntax errors" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    // Missing type after colon should error
    const source = "let x: = 1;";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = Parser.initWithSource(toks, &diag, &arena, source);
    _ = parser.parseProgram() catch {};
    try std.testing.expect(diag.hasErrors());
}
