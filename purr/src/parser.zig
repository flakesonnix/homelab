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

    pub fn init(tokens: []lexer.Token, diag: *diagnostics.Diagnostics, arena: *std.heap.ArenaAllocator) Parser {
        return .{
            .tokens = tokens,
            .pos = 0,
            .diag = diag,
            .arena = arena,
            .allocator = arena.allocator(),
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
                .keyword_role, .keyword_host, .keyword_bundle, .keyword_preset, .keyword_package, .keyword_nix => {
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
        return k == .keyword_role or k == .keyword_host or k == .keyword_bundle or k == .keyword_preset or k == .keyword_package or k == .keyword_import or k == .keyword_use or k == .keyword_nix or k == .keyword_description or k == .keyword_targets;
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

    fn parseHost(self: *Parser) !ast.Host {
        const kw = try self.expect(.keyword_host);
        const name = try self.parseIdent();
        _ = try self.expect(.l_brace);
        var stmts: std.ArrayList(ast.HostStmt) = .empty;
        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
            switch (self.peekKind()) {
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
                    // packages = [...] or setting
                    const ident_tok = self.peek();
                    // lookahead for =
                    if (self.pos + 1 < self.tokens.len and self.tokens[self.pos + 1].kind == .equal) {
                        _ = self.advance();
                        _ = self.advance(); // =
                        if (std.mem.eql(u8, ident_tok.lexeme, "packages")) {
                            const list = try self.parseStringList();
                            _ = try self.expect(.semicolon);
                            try stmts.append(self.allocator, .{ .packages_assign = list });
                        } else {
                            // generic setting with value
                            const val = try self.parseValue();
                            _ = try self.expect(.semicolon);
                            const path = try self.dup(ident_tok.lexeme);
                            try stmts.append(self.allocator, .{ .setting = .{ .path = path, .value = val, .span = ident_tok.span } });
                        }
                    } else {
                        const t = self.advance();
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .parse_error,
                            .message = try std.fmt.allocPrint(self.allocator, "unexpected `{s}` in host", .{t.lexeme}),
                            .span = t.span,
                            .help = null,
                        });
                        return error.ParseError;
                    }
                },
                .keyword_nix => {
                    const nix_block = try self.parseNix();
                    try stmts.append(self.allocator, .{ .setting = .{ .path = "nix_raw", .value = .{ .string = nix_block.content }, .span = nix_block.span } });
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
        return .{ .name = name, .stmts = try stmts.toOwnedSlice(self.allocator), .span = kw.span };
    }

    fn parseValue(self: *Parser) anyerror!ast.Value {
        const t = self.peek();
        switch (t.kind) {
            .string_lit => {
                _ = self.advance();
                const s = try self.unquote(t.lexeme);
                return .{ .string = s };
            },
            .integer => {
                _ = self.advance();
                const v = try std.fmt.parseInt(i64, t.lexeme, 10);
                return .{ .integer = v };
            },
            .keyword_true => {
                _ = self.advance();
                return .{ .boolean = true };
            },
            .keyword_false => {
                _ = self.advance();
                return .{ .boolean = false };
            },
            .l_bracket => {
                const list = try self.parseValueList();
                return .{ .list = list };
            },
            .ident => {
                _ = self.advance();
                const id = ast.Ident{ .name = try self.dup(t.lexeme), .span = t.span };
                return .{ .ident = id };
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

    fn parseValueList(self: *Parser) anyerror![]ast.Value {
        _ = try self.expect(.l_bracket);
        var list: std.ArrayList(ast.Value) = .empty;
        while (self.peekKind() != .r_bracket and !self.isAtEnd()) {
            const v = try self.parseValue();
            try list.append(self.allocator, v);
            _ = self.consumeIf(.comma);
        }
        _ = try self.expect(.r_bracket);
        return try list.toOwnedSlice(self.allocator);
    }

    fn parseBundle(self: *Parser) !ast.Bundle {
        const kw = try self.expect(.keyword_bundle);
        const name = try self.parseIdent();
        _ = try self.expect(.l_brace);
        // simplified: just parse ignored content until }
        const pkg_toggles: std.ArrayList([]const u8) = .empty;
        _ = pkg_toggles;
        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
            const t = self.advance();
            _ = t;
            // skip
            if (self.peekKind() == .semicolon) _ = self.advance();
        }
        _ = try self.expect(.r_brace);
        return .{ .name = name, .description = null, .programs = &.{}, .package_toggles = &.{}, .span = kw.span };
    }

    fn parsePreset(self: *Parser) !ast.Preset {
        const kw = try self.expect(.keyword_preset);
        const name = try self.parseIdent();
        _ = try self.expect(.l_brace);
        var flags: std.ArrayList(ast.Setting) = .empty;
        while (self.peekKind() != .r_brace and !self.isAtEnd()) {
            // parse flags block simplified
            _ = self.advance();
        }
        _ = try self.expect(.r_brace);
        return .{ .name = name, .description = null, .flags = try flags.toOwnedSlice(self.allocator), .span = kw.span };
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
        // capture raw until matching }
        var depth: usize = 1;
        const start_pos = self.tokens[self.pos - 1].span.end; // after {
        // we need source slice: reconstruct from tokens? Instead capture from source via span positions
        // For now, collect lexemes
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
        if (depth != 0) {
            try self.diag.push(.{
                .severity = .err,
                .code = .parse_error,
                .message = "unterminated nix block",
                .span = l.span,
                .help = null,
            });
            return error.ParseError;
        }
        const content = try buf.toOwnedSlice(self.allocator);
        _ = start_pos;
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
