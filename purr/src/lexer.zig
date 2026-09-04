const std = @import("std");
const diagnostics = @import("diagnostics.zig");
pub const Span = diagnostics.Span;

pub const TokenKind = enum {
    ident,
    keyword_role,
    keyword_host,
    keyword_bundle,
    keyword_preset,
    keyword_package,
    keyword_import,
    keyword_use,
    keyword_nix,
    keyword_description,
    keyword_targets,
    keyword_requires,
    keyword_conflicts,
    keyword_presets,
    keyword_tags,
    keyword_bundles,
    keyword_true,
    keyword_false,
    string_lit,
    integer,
    l_brace,
    r_brace,
    l_bracket,
    r_bracket,
    equal,
    semicolon,
    comma,
    eof,
    invalid,
};

pub const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
    span: Span,
};

pub const Lexer = struct {
    source: []const u8,
    file: []const u8,
    pos: usize,
    line: u32,
    col: u32,
    diagnostics: *diagnostics.Diagnostics,

    pub fn init(source: []const u8, file: []const u8, diag: *diagnostics.Diagnostics) Lexer {
        return .{ .source = source, .file = file, .pos = 0, .line = 1, .col = 1, .diagnostics = diag };
    }

    fn isAtEnd(self: *Lexer) bool {
        return self.pos >= self.source.len;
    }

    fn peek(self: *Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.pos];
    }

    fn peekNext(self: *Lexer) u8 {
        if (self.pos + 1 >= self.source.len) return 0;
        return self.source[self.pos + 1];
    }

    fn advance(self: *Lexer) u8 {
        const c = self.source[self.pos];
        self.pos += 1;
        if (c == '\n') {
            self.line += 1;
            self.col = 1;
        } else {
            self.col += 1;
        }
        return c;
    }

    fn makeSpan(self: *Lexer, start: usize, start_line: u32, start_col: u32, end: usize) Span {
        return .{
            .file = self.file,
            .line = start_line,
            .col = start_col,
            .len = @intCast(end - start),
            .start = start,
            .end = end,
        };
    }

    fn skipWhitespaceAndComments(self: *Lexer) void {
        while (!self.isAtEnd()) {
            const c = self.peek();
            if (c == ' ' or c == '\r' or c == '\t' or c == '\n') {
                _ = self.advance();
            } else if (c == '/' and self.peekNext() == '/') {
                // line comment
                while (!self.isAtEnd() and self.peek() != '\n') _ = self.advance();
            } else if (c == '/' and self.peekNext() == '*') {
                // block comment
                _ = self.advance();
                _ = self.advance();
                while (!self.isAtEnd()) {
                    if (self.peek() == '*' and self.peekNext() == '/') {
                        _ = self.advance();
                        _ = self.advance();
                        break;
                    }
                    _ = self.advance();
                }
            } else break;
        }
    }

    pub fn nextToken(self: *Lexer) !Token {
        self.skipWhitespaceAndComments();
        const start = self.pos;
        const start_line = self.line;
        const start_col = self.col;

        if (self.isAtEnd()) {
            return .{
                .kind = .eof,
                .lexeme = "",
                .span = self.makeSpan(start, start_line, start_col, start),
            };
        }

        const c = self.advance();
        switch (c) {
            '{' => return .{ .kind = .l_brace, .lexeme = "{", .span = self.makeSpan(start, start_line, start_col, self.pos) },
            '}' => return .{ .kind = .r_brace, .lexeme = "}", .span = self.makeSpan(start, start_line, start_col, self.pos) },
            '[' => return .{ .kind = .l_bracket, .lexeme = "[", .span = self.makeSpan(start, start_line, start_col, self.pos) },
            ']' => return .{ .kind = .r_bracket, .lexeme = "]", .span = self.makeSpan(start, start_line, start_col, self.pos) },
            '=' => return .{ .kind = .equal, .lexeme = "=", .span = self.makeSpan(start, start_line, start_col, self.pos) },
            ';' => return .{ .kind = .semicolon, .lexeme = ";", .span = self.makeSpan(start, start_line, start_col, self.pos) },
            ',' => return .{ .kind = .comma, .lexeme = ",", .span = self.makeSpan(start, start_line, start_col, self.pos) },
            '"' => {
                // string literal
                var buf: std.ArrayList(u8) = .empty;
                defer buf.deinit(self.diagnostics.allocator);
                while (!self.isAtEnd() and self.peek() != '"') {
                    if (self.peek() == '\\') {
                        _ = self.advance(); // \
                        if (self.isAtEnd()) break;
                        const esc = self.advance();
                        switch (esc) {
                            'n' => try buf.append(self.diagnostics.allocator, '\n'),
                            't' => try buf.append(self.diagnostics.allocator, '\t'),
                            '"' => try buf.append(self.diagnostics.allocator, '"'),
                            '\\' => try buf.append(self.diagnostics.allocator, '\\'),
                            else => try buf.append(self.diagnostics.allocator, esc),
                        }
                    } else {
                        try buf.append(self.diagnostics.allocator, self.advance());
                    }
                }
                if (self.isAtEnd()) {
                    try self.diagnostics.push(.{
                        .severity = .err,
                        .code = .lex_error,
                        .message = "unterminated string literal",
                        .span = self.makeSpan(start, start_line, start_col, self.pos),
                        .help = "add closing `\"`",
                    });
                    const lexeme = self.source[start..self.pos];
                    return .{ .kind = .invalid, .lexeme = lexeme, .span = self.makeSpan(start, start_line, start_col, self.pos) };
                }
                _ = self.advance(); // closing "
                const lexeme = self.source[start..self.pos];
                return .{ .kind = .string_lit, .lexeme = lexeme, .span = self.makeSpan(start, start_line, start_col, self.pos) };
            },
            '0'...'9' => {
                while (!self.isAtEnd() and std.ascii.isDigit(self.peek())) _ = self.advance();
                const lexeme = self.source[start..self.pos];
                return .{ .kind = .integer, .lexeme = lexeme, .span = self.makeSpan(start, start_line, start_col, self.pos) };
            },
            'A'...'Z', 'a'...'z', '_' => {
                while (!self.isAtEnd() and (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '_' or self.peek() == '-' or self.peek() == '.')) _ = self.advance();
                const lexeme = self.source[start..self.pos];
                const kind: TokenKind = keywordKind(lexeme) orelse .ident;
                return .{ .kind = kind, .lexeme = lexeme, .span = self.makeSpan(start, start_line, start_col, self.pos) };
            },
            else => {
                try self.diagnostics.push(.{
                    .severity = .err,
                    .code = .lex_error,
                    .message = "invalid character",
                    .span = self.makeSpan(start, start_line, start_col, self.pos),
                    .help = null,
                });
                const lexeme = self.source[start..self.pos];
                return .{ .kind = .invalid, .lexeme = lexeme, .span = self.makeSpan(start, start_line, start_col, self.pos) };
            },
        }
    }

    fn keywordKind(lexeme: []const u8) ?TokenKind {
        if (std.mem.eql(u8, lexeme, "role")) return .keyword_role;
        if (std.mem.eql(u8, lexeme, "host")) return .keyword_host;
        if (std.mem.eql(u8, lexeme, "bundle")) return .keyword_bundle;
        if (std.mem.eql(u8, lexeme, "preset")) return .keyword_preset;
        if (std.mem.eql(u8, lexeme, "package")) return .keyword_package;
        if (std.mem.eql(u8, lexeme, "import")) return .keyword_import;
        if (std.mem.eql(u8, lexeme, "use")) return .keyword_use;
        if (std.mem.eql(u8, lexeme, "nix")) return .keyword_nix;
        if (std.mem.eql(u8, lexeme, "description")) return .keyword_description;
        if (std.mem.eql(u8, lexeme, "targets")) return .keyword_targets;
        if (std.mem.eql(u8, lexeme, "requires")) return .keyword_requires;
        if (std.mem.eql(u8, lexeme, "conflicts")) return .keyword_conflicts;
        if (std.mem.eql(u8, lexeme, "presets")) return .keyword_presets;
        if (std.mem.eql(u8, lexeme, "tags")) return .keyword_tags;
        if (std.mem.eql(u8, lexeme, "bundles")) return .keyword_bundles;
        if (std.mem.eql(u8, lexeme, "true")) return .keyword_true;
        if (std.mem.eql(u8, lexeme, "false")) return .keyword_false;
        return null;
    }

    pub fn lexAll(self: *Lexer, allocator: std.mem.Allocator) ![]Token {
        var list: std.ArrayList(Token) = .empty;
        defer list.deinit(allocator);
        while (true) {
            const tok = try self.nextToken();
            try list.append(allocator, tok);
            if (tok.kind == .eof) break;
        }
        return try list.toOwnedSlice(allocator);
    }
};

test "lexer basic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var diag = diagnostics.Diagnostics.init(alloc, "test.meow", "host x270 { use desktop; }");
    var lex = Lexer.init("host x270 { use desktop; }", "test.meow", &diag);
    const toks = try lex.lexAll(alloc);
    try std.testing.expect(toks.len == 8); // host, x270, {, use, desktop, ;, }, eof
    try std.testing.expect(toks[0].kind == .keyword_host);
    try std.testing.expect(toks[1].kind == .ident);
}

test "lexer string" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var diag = diagnostics.Diagnostics.init(alloc, "test.meow", "\"hello\"");
    var lex = Lexer.init("\"hello\"", "test.meow", &diag);
    const tok = try lex.nextToken();
    try std.testing.expect(tok.kind == .string_lit);
}

test "lexer comments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var diag = diagnostics.Diagnostics.init(alloc, "test.meow", "host // comment\n x270");
    var lex = Lexer.init("host // comment\n x270", "test.meow", &diag);
    const t1 = try lex.nextToken();
    const t2 = try lex.nextToken();
    try std.testing.expect(t1.kind == .keyword_host);
    try std.testing.expect(t2.kind == .ident);
}
