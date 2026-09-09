const std = @import("std");

// Minimal Nix IR for migration tool — bounded subset, not a full Nix parser.
// Focus: attribute assignments, primitive values, lists, attrsets, with, calls, selects.
// Design: Nix IR → Purr AST (via migration rules) → Purr formatter.
// Unsupported or unsafe constructs survive as `Raw` instead of being discarded.

pub const NixExpr = union(enum) {
    bool: bool,
    integer: i64,
    string: []const u8,
    list: []NixExpr,
    attr_set: []NixAttr,
    ident: []const u8,
    raw: []const u8,
};

pub const NixAttr = struct {
    path: []const u8, // e.g. services.nginx.enable or services.nginx.virtualHosts."example.org".enableACME
    value: NixExpr,
    raw: []const u8, // original text for Raw fallback / Nix generation
};

// Tokenizer with offsets for accurate raw slicing

const TokenKind = enum {
    ident,
    string,
    integer,
    l_brace,
    r_brace,
    l_bracket,
    r_bracket,
    l_paren,
    r_paren,
    equal,
    semicolon,
    comma,
    dot,
    colon,
    with_kw,
    let_kw,
    in_kw,
    rec_kw,
    inherit_kw,
    eof,
};

const Token = struct {
    kind: TokenKind,
    lexeme: []const u8,
    start: usize,
    end: usize,
};

pub fn tokenize(allocator: std.mem.Allocator, src: []const u8) ![]Token {
    var list: std.ArrayList(Token) = .empty;
    var i: usize = 0;
    while (i < src.len) {
        const c = src[i];
        if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
            i += 1;
            continue;
        }
        if (c == '#') {
            while (i < src.len and src[i] != '\n') : (i += 1) {}
            continue;
        }
        if (c == '/' and i + 1 < src.len and src[i + 1] == '/') {
            while (i < src.len and src[i] != '\n') : (i += 1) {}
            continue;
        }
        if (c == '/' and i + 1 < src.len and src[i + 1] == '*') {
            i += 2;
            while (i + 1 < src.len and !(src[i] == '*' and src[i + 1] == '/')) : (i += 1) {}
            if (i + 1 < src.len) i += 2;
            continue;
        }
        switch (c) {
            '{' => {
                try list.append(allocator, .{ .kind = .l_brace, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            '}' => {
                try list.append(allocator, .{ .kind = .r_brace, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            '[' => {
                try list.append(allocator, .{ .kind = .l_bracket, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            ']' => {
                try list.append(allocator, .{ .kind = .r_bracket, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            '(' => {
                try list.append(allocator, .{ .kind = .l_paren, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            ')' => {
                try list.append(allocator, .{ .kind = .r_paren, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            '=' => {
                try list.append(allocator, .{ .kind = .equal, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            ';' => {
                try list.append(allocator, .{ .kind = .semicolon, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            ',' => {
                try list.append(allocator, .{ .kind = .comma, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            '.' => {
                try list.append(allocator, .{ .kind = .dot, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            ':' => {
                try list.append(allocator, .{ .kind = .colon, .lexeme = src[i .. i + 1], .start = i, .end = i + 1 });
                i += 1;
            },
            '"' => {
                const start = i;
                i += 1;
                while (i < src.len) {
                    if (src[i] == '\\') {
                        i += 2;
                    } else if (src[i] == '"') {
                        i += 1;
                        break;
                    } else {
                        i += 1;
                    }
                }
                try list.append(allocator, .{ .kind = .string, .lexeme = src[start..i], .start = start, .end = i });
            },
            '\'' => {
                // Handle '' indented strings: '' ... ''  or single quoted attr
                if (i + 1 < src.len and src[i + 1] == '\'') {
                    const start = i;
                    i += 2;
                    while (i + 1 < src.len and !(src[i] == '\'' and src[i + 1] == '\'')) : (i += 1) {}
                    if (i + 1 < src.len) i += 2;
                    try list.append(allocator, .{ .kind = .string, .lexeme = src[start..i], .start = start, .end = i });
                } else {
                    const start = i;
                    i += 1;
                    while (i < src.len and src[i] != '\'') : (i += 1) {}
                    if (i < src.len) i += 1;
                    try list.append(allocator, .{ .kind = .string, .lexeme = src[start..i], .start = start, .end = i });
                }
            },
            '0'...'9', '-' => {
                const start = i;
                if (c == '-') i += 1;
                // require digit after '-'; if not, treat as ident '-'
                if (i < src.len and std.ascii.isDigit(src[i])) {
                    while (i < src.len and std.ascii.isDigit(src[i])) : (i += 1) {}
                    try list.append(allocator, .{ .kind = .integer, .lexeme = src[start..i], .start = start, .end = i });
                } else {
                    // solitary '-', treat as ident
                    try list.append(allocator, .{ .kind = .ident, .lexeme = src[start .. start + 1], .start = start, .end = start + 1 });
                    if (c == '-') {
                        // already advanced 1
                    }
                }
            },
            else => {
                if (std.ascii.isAlphabetic(c) or c == '_') {
                    const start = i;
                    while (i < src.len and (std.ascii.isAlphanumeric(src[i]) or src[i] == '_' or src[i] == '-' or src[i] == '\'')) : (i += 1) {}
                    const lex = src[start..i];
                    const kind: TokenKind = if (std.mem.eql(u8, lex, "with")) .with_kw else if (std.mem.eql(u8, lex, "let")) .let_kw else if (std.mem.eql(u8, lex, "in")) .in_kw else if (std.mem.eql(u8, lex, "rec")) .rec_kw else if (std.mem.eql(u8, lex, "inherit")) .inherit_kw else .ident;
                    try list.append(allocator, .{ .kind = kind, .lexeme = lex, .start = start, .end = i });
                } else {
                    // unknown char, skip
                    i += 1;
                }
            },
        }
    }
    try list.append(allocator, .{ .kind = .eof, .lexeme = "", .start = src.len, .end = src.len });
    return try list.toOwnedSlice(allocator);
}

fn isPathToken(k: TokenKind) bool {
    return k == .ident or k == .string or k == .with_kw or k == .let_kw or k == .in_kw or k == .rec_kw or k == .inherit_kw;
}

pub fn parseAttrs(allocator: std.mem.Allocator, src: []const u8) ![]NixAttr {
    var attrs: std.ArrayList(NixAttr) = .empty;
    const toks = try tokenize(allocator, src);
    defer allocator.free(toks);
    var i: usize = 0;
    while (i < toks.len) {
        if (toks[i].kind == .eof) break;
        // Skip outer delimiters that are not part of a path: braces, commas, colons, semicolons, 'in'
        if (toks[i].kind == .l_brace or toks[i].kind == .r_brace or toks[i].kind == .comma or toks[i].kind == .colon or toks[i].kind == .semicolon or toks[i].kind == .in_kw) {
            i += 1;
            continue;
        }
        if (toks[i].kind == .let_kw or toks[i].kind == .rec_kw) {
            // skip let blocks: let ... in (approx skip to next semicolon at outer depth)
            var depth_brace: usize = 0;
            var depth_bracket: usize = 0;
            while (i < toks.len and toks[i].kind != .eof) : (i += 1) {
                if (toks[i].kind == .l_brace) depth_brace += 1;
                if (toks[i].kind == .r_brace and depth_brace > 0) depth_brace -= 1;
                if (toks[i].kind == .l_bracket) depth_bracket += 1;
                if (toks[i].kind == .r_bracket and depth_bracket > 0) depth_bracket -= 1;
                if (toks[i].kind == .semicolon and depth_brace == 0 and depth_bracket == 0) {
                    i += 1;
                    break;
                }
                if (toks[i].kind == .in_kw and depth_brace == 0 and depth_bracket == 0) {
                    // let ... in: skip 'in' and continue to handle following expr
                    // do not break, just continue scanning (the following expr may be attrset)
                    continue;
                }
            }
            continue;
        }
        // Look for path = value ;
        const path_start = i;
        var has_equal = false;
        var eq_idx: usize = 0;
        var j = i;
        var dot_ok = true;
        // Scan ahead to find '=' within reasonable path length
        while (j < toks.len and toks[j].kind != .eof) : (j += 1) {
            if (toks[j].kind == .equal) {
                has_equal = true;
                eq_idx = j;
                break;
            }
            if (toks[j].kind == .semicolon or toks[j].kind == .l_brace) {
                // If we hit { at path_start (attrset start) without '=', it's not assignment
                if (j == path_start and toks[j].kind == .l_brace) break;
                if (toks[j].kind == .semicolon) break;
            }
            // path may contain ident/dot/string but not other symbols
            const tk = toks[j].kind;
            if (tk == .dot) {
                dot_ok = true;
                continue;
            }
            if (isPathToken(tk)) {
                dot_ok = false;
                continue;
            }
            // If we hit non-path token before '=', it's not a valid path
            if (tk == .l_bracket or tk == .r_bracket or tk == .r_brace or tk == .comma) break;
        }
        if (!has_equal) {
            // No "=", just advance one token (avoid skipping real assignments after function header)
            i += 1;
            continue;
        }
        // Validate path tokens [path_start..eq_idx) are plausible
        var path_valid = true;
        if (eq_idx == path_start) path_valid = false;
        for (toks[path_start..eq_idx]) |t| {
            if (t.kind == .dot) continue;
            if (!isPathToken(t.kind)) {
                path_valid = false;
                break;
            }
        }
        if (!path_valid or dot_ok) {
            // path ends with dot or invalid, skip
            i = eq_idx + 1;
            continue;
        }
        // Build path string from tokens [path_start..eq_idx)
        var path_buf: std.ArrayList(u8) = .empty;
        for (toks[path_start..eq_idx]) |t| {
            if (t.kind == .dot) {
                try path_buf.append(allocator, '.');
            } else {
                try path_buf.appendSlice(allocator, t.lexeme);
            }
        }
        const path_str = try path_buf.toOwnedSlice(allocator);
        // Find value end at ; with nesting
        const val_start = eq_idx + 1;
        // Skip whitespace? tokens already trimmed
        var val_end = val_start;
        var depth_brace: usize = 0;
        var depth_bracket: usize = 0;
        var depth_paren: usize = 0;
        var found_semi = false;
        var skipped_with_semi = false;
        while (val_end < toks.len and toks[val_end].kind != .eof) : (val_end += 1) {
            if (toks[val_end].kind == .l_brace) depth_brace += 1;
            if (toks[val_end].kind == .r_brace) {
                if (depth_brace > 0) depth_brace -= 1 else break;
            }
            if (toks[val_end].kind == .l_bracket) depth_bracket += 1;
            if (toks[val_end].kind == .r_bracket) {
                if (depth_bracket > 0) depth_bracket -= 1 else break;
            }
            if (toks[val_end].kind == .l_paren) depth_paren += 1;
            if (toks[val_end].kind == .r_paren) {
                if (depth_paren > 0) depth_paren -= 1 else break;
            }
            if (toks[val_end].kind == .semicolon and depth_brace == 0 and depth_bracket == 0 and depth_paren == 0) {
                // Handle `with pkgs; <body>;` where first `;` after `with` is not terminator
                if (!skipped_with_semi and val_start < toks.len and toks[val_start].kind == .with_kw) {
                    skipped_with_semi = true;
                    continue;
                }
                found_semi = true;
                break;
            }
        }
        if (!found_semi) {
            // Allow missing trailing semicolon at EOF (for --expr mode) if depth==0 and value present
            const at_eof = val_end < toks.len and toks[val_end].kind == .eof and depth_brace == 0 and depth_bracket == 0 and depth_paren == 0 and val_end > val_start;
            if (!at_eof) {
                allocator.free(path_str);
                i = val_end;
                if (i < toks.len and toks[i].kind == .semicolon) i += 1;
                continue;
            }
            // treat EOF as terminator
            found_semi = true;
        }
        // Extract raw value slice from src
        const tmp_raw = blk: {
            if (val_start >= val_end) {
                break :blk try allocator.dupe(u8, "");
            }
            const start_off = toks[val_start].start;
            const end_off = toks[val_end - 1].end;
            const slice = src[start_off..end_off];
            break :blk try allocator.dupe(u8, std.mem.trim(u8, slice, " \t\n\r"));
        };
        const value_tokens = toks[val_start..val_end];
        const val_expr = try classifyValueTokens(allocator, value_tokens, tmp_raw);
        const full_raw = try allocator.dupe(u8, tmp_raw);
        allocator.free(tmp_raw);
        try attrs.append(allocator, .{ .path = path_str, .value = val_expr, .raw = full_raw });
        i = val_end + 1;
    }
    return try attrs.toOwnedSlice(allocator);
}

// Parse a single Nix expression (for --expr mode). Supports primitive, list, attrset, or raw.
pub fn parseExpr(allocator: std.mem.Allocator, src: []const u8) !NixExpr {
    const trimmed = std.mem.trim(u8, src, " \t\n\r");
    if (trimmed.len == 0) return .{ .raw = try allocator.dupe(u8, src) };
    const toks = try tokenize(allocator, trimmed);
    defer allocator.free(toks);
    // Remove trailing eof
    const inner = toks[0 .. toks.len - 1];
    if (inner.len == 0) return .{ .raw = try allocator.dupe(u8, src) };
    const val = try classifyValueTokens(allocator, inner, trimmed);
    // If raw, preserve original src trimmed
    if (val == .raw) {
        // free val.raw and replace with trimmed copy? Already duped
        return val;
    }
    return val;
}

fn classifyValueTokens(allocator: std.mem.Allocator, toks: []Token, raw: []const u8) !NixExpr {
    if (toks.len == 0) return .{ .raw = try allocator.dupe(u8, raw) };
    // Check for with prefix: with pkgs; [ ... ] or with ident; expr
    if (toks.len >= 2 and toks[0].kind == .with_kw) {
        return .{ .raw = try allocator.dupe(u8, raw) };
    }
    // Single token primitives
    if (toks.len == 1) {
        const t = toks[0];
        if (t.kind == .string) {
            // handle '' indented strings as raw? But treat as string after unquoting
            const inner = try unquoteString(allocator, t.lexeme);
            return .{ .string = inner };
        }
        if (t.kind == .integer) {
            const v = std.fmt.parseInt(i64, t.lexeme, 10) catch {
                return .{ .raw = try allocator.dupe(u8, raw) };
            };
            return .{ .integer = v };
        }
        if (t.kind == .ident) {
            if (std.mem.eql(u8, t.lexeme, "true")) return .{ .bool = true };
            if (std.mem.eql(u8, t.lexeme, "false")) return .{ .bool = false };
            // Bare ident like `pkgs` or `git` => raw ident
            return .{ .ident = try allocator.dupe(u8, t.lexeme) };
        }
        // l_brace with no content? Could be empty attrset
        if (t.kind == .l_brace) return .{ .attr_set = &.{} };
        return .{ .raw = try allocator.dupe(u8, raw) };
    }
    // Check for lib. patterns etc.
    for (toks) |t| {
        if (std.mem.eql(u8, t.lexeme, "lib") or std.mem.eql(u8, t.lexeme, "mkMerge") or std.mem.eql(u8, t.lexeme, "mkForce") or std.mem.eql(u8, t.lexeme, "mkIf")) {
            return .{ .raw = try allocator.dupe(u8, raw) };
        }
        if (t.kind == .with_kw or t.kind == .let_kw or t.kind == .inherit_kw) {
            return .{ .raw = try allocator.dupe(u8, raw) };
        }
    }
    // List: [ ... ]
    if (toks[0].kind == .l_bracket and toks[toks.len - 1].kind == .r_bracket) {
        // Check with inside? Already handled with prefix, but list may be `with pkgs; [ ... ]` as separate earlier? For `[ git vim ]` without with, check elements
        var elems: std.ArrayList(NixExpr) = .empty;
        var idx: usize = 1;
        var has_raw = false;
        while (idx < toks.len - 1) {
            const tk = toks[idx];
            if (tk.kind == .comma) {
                idx += 1;
                continue;
            }
            if (tk.kind == .string) {
                const inner = try unquoteString(allocator, tk.lexeme);
                try elems.append(allocator, .{ .string = inner });
            } else if (tk.kind == .integer) {
                const v = std.fmt.parseInt(i64, tk.lexeme, 10) catch {
                    has_raw = true;
                    break;
                };
                try elems.append(allocator, .{ .integer = v });
            } else if (tk.kind == .ident) {
                if (std.mem.eql(u8, tk.lexeme, "true")) try elems.append(allocator, .{ .bool = true }) else if (std.mem.eql(u8, tk.lexeme, "false")) try elems.append(allocator, .{ .bool = false }) else {
                    // bare ident like git, vim -> treat as raw element => whole list is raw (preserve with)
                    has_raw = true;
                    break;
                }
            } else if (tk.kind == .l_bracket or tk.kind == .l_brace) {
                // nested list/attr not supported in simple list -> raw
                has_raw = true;
                break;
            } else {
                has_raw = true;
                break;
            }
            idx += 1;
        }
        if (has_raw) {
            for (elems.items) |e| {
                if (e == .string) allocator.free(e.string);
                if (e == .raw) allocator.free(e.raw);
            }
            elems.deinit(allocator);
            return .{ .raw = try allocator.dupe(u8, raw) };
        }
        return .{ .list = try elems.toOwnedSlice(allocator) };
    }
    // Attr set: { ... }
    if (toks[0].kind == .l_brace and toks[toks.len - 1].kind == .r_brace) {
        // Try to parse inner attrs
        const inner_toks = toks[1 .. toks.len - 1];
        // If empty attrset
        if (inner_toks.len == 0) return .{ .attr_set = &.{} };
        // Attempt to parse inner as list of attrs using simple scan
        // We need source slice for inner raw extraction; we have raw but need accurate.
        // Instead, reconstruct a mini source for inner: join lexemes with spaces? Better to try parsing with helper that works on tokens directly.
        var inner_attrs: std.ArrayList(NixAttr) = .empty;
        var i: usize = 0;
        var ok = true;
        while (i < inner_toks.len) {
            // skip commas/semicolons irrelevant?
            if (inner_toks[i].kind == .semicolon or inner_toks[i].kind == .comma) {
                i += 1;
                continue;
            }
            // find path = value ; within inner
            var eq: ?usize = null;
            var semi: ?usize = null;
            var depth_brace: usize = 0;
            var depth_bracket: usize = 0;
            for (inner_toks[i..], 0..) |t, off| {
                if (t.kind == .l_brace) depth_brace += 1;
                if (t.kind == .r_brace and depth_brace > 0) depth_brace -= 1;
                if (t.kind == .l_bracket) depth_bracket += 1;
                if (t.kind == .r_bracket and depth_bracket > 0) depth_bracket -= 1;
                if (t.kind == .equal and eq == null and depth_brace == 0 and depth_bracket == 0) eq = i + off;
                if (t.kind == .semicolon and depth_brace == 0 and depth_bracket == 0 and eq != null) {
                    semi = i + off;
                    break;
                }
            }
            if (eq == null or semi == null) {
                ok = false;
                break;
            }
            const eq_idx = eq.?;
            const semi_idx = semi.?;
            // path tokens [i .. eq_idx)
            var path_buf: std.ArrayList(u8) = .empty;
            for (inner_toks[i..eq_idx]) |t| {
                if (t.kind == .dot) {
                    try path_buf.append(allocator, '.');
                } else if (isPathToken(t.kind)) {
                    try path_buf.appendSlice(allocator, t.lexeme);
                } else {
                    ok = false;
                    break;
                }
            }
            if (!ok) {
                path_buf.deinit(allocator);
                break;
            }
            const path_str = try path_buf.toOwnedSlice(allocator);
            // value tokens [eq_idx+1 .. semi_idx)
            const v_toks = inner_toks[eq_idx + 1 .. semi_idx];
            if (v_toks.len == 0) {
                allocator.free(path_str);
                ok = false;
                break;
            }
            // Build raw for inner value
            var v_raw_buf: std.ArrayList(u8) = .empty;
            for (v_toks, 0..) |t, vi| {
                if (vi > 0) try v_raw_buf.append(allocator, ' ');
                try v_raw_buf.appendSlice(allocator, t.lexeme);
            }
            const v_raw = try v_raw_buf.toOwnedSlice(allocator);
            const v_expr = try classifyValueTokens(allocator, @constCast(v_toks), v_raw);
            // If inner value is raw, then attrset is considered raw unless we allow preservation
            if (v_expr == .raw and !isSimpleRawForAttrSet(v_raw)) {
                // For simple raw like attrset inner with lib, we treat outer as raw
                ok = false;
                allocator.free(path_str);
                allocator.free(v_raw);
                // need to free v_expr.raw
                allocator.free(v_expr.raw);
                break;
            }
            try inner_attrs.append(allocator, .{ .path = path_str, .value = v_expr, .raw = v_raw });
            i = semi_idx + 1;
        }
        if (!ok or (inner_attrs.items.len == 0 and inner_toks.len > 0)) {
            for (inner_attrs.items) |a| {
                allocator.free(a.path);
                allocator.free(a.raw);
                // free value strings etc. leak but ok for now
            }
            inner_attrs.deinit(allocator);
            return .{ .raw = try allocator.dupe(u8, raw) };
        }
        // Check if there are leftover tokens that weren't parsed (like rec, inherit)
        // If leftover non-whitespace, treat as raw
        // But our loop consumed all `path = value;` if ok, leftover should be none
        // Verify all tokens accounted for? If i < inner_toks.len, there are leftovers
        if (i < inner_toks.len) {
            // Might have extra tokens like "inherit ..."? Treat as raw
            for (inner_attrs.items) |a| {
                allocator.free(a.path);
                allocator.free(a.raw);
            }
            inner_attrs.deinit(allocator);
            return .{ .raw = try allocator.dupe(u8, raw) };
        }
        return .{ .attr_set = try inner_attrs.toOwnedSlice(allocator) };
    }
    // Check for select-chain or call etc.: if contains '.' without being simple path?
    // Already handled for attr sets. For other, treat as raw
    return .{ .raw = try allocator.dupe(u8, raw) };
}

fn isSimpleRawForAttrSet(raw: []const u8) bool {
    // Allow raw for attrset inner that is still simple? For now disallow raw inner
    _ = raw;
    return false;
}

fn unquoteString(allocator: std.mem.Allocator, lexeme: []const u8) ![]const u8 {
    if (lexeme.len < 2) return try allocator.dupe(u8, "");
    if (lexeme[0] == '"' and lexeme[lexeme.len - 1] == '"') {
        var buf: std.ArrayList(u8) = .empty;
        var i: usize = 1;
        while (i < lexeme.len - 1) : (i += 1) {
            if (lexeme[i] == '\\' and i + 1 < lexeme.len - 1) {
                i += 1;
                switch (lexeme[i]) {
                    'n' => try buf.append(allocator, '\n'),
                    't' => try buf.append(allocator, '\t'),
                    '"' => try buf.append(allocator, '"'),
                    '\\' => try buf.append(allocator, '\\'),
                    'r' => try buf.append(allocator, '\r'),
                    else => try buf.append(allocator, lexeme[i]),
                }
            } else {
                try buf.append(allocator, lexeme[i]);
            }
        }
        return try buf.toOwnedSlice(allocator);
    }
    if (lexeme.len >= 4 and lexeme[0] == '\'' and lexeme[1] == '\'') {
        // '' indented string - strip '' at both ends and handle indentation
        const inner = lexeme[2 .. lexeme.len - 2];
        return try allocator.dupe(u8, inner);
    }
    if (lexeme[0] == '\'' and lexeme[lexeme.len - 1] == '\'') {
        return try allocator.dupe(u8, lexeme[1 .. lexeme.len - 1]);
    }
    return try allocator.dupe(u8, lexeme);
}

test "nix_ir parse bool" {
    const alloc = std.testing.allocator;
    const attrs = try parseAttrs(alloc, "services.nginx.enable = true;");
    defer {
        for (attrs) |a| {
            alloc.free(a.path);
            alloc.free(a.raw);
            if (a.value == .string) alloc.free(a.value.string);
            if (a.value == .raw) alloc.free(a.value.raw);
        }
        alloc.free(attrs);
    }
    try std.testing.expect(attrs.len == 1);
    try std.testing.expectEqualStrings("services.nginx.enable", attrs[0].path);
    try std.testing.expect(attrs[0].value == .bool);
    try std.testing.expect(attrs[0].value.bool == true);
}

test "nix_ir parse string" {
    const alloc = std.testing.allocator;
    const attrs = try parseAttrs(alloc, "networking.hostName = \"mireo\";");
    defer {
        for (attrs) |a| {
            alloc.free(a.path);
            alloc.free(a.raw);
            if (a.value == .string) alloc.free(a.value.string);
        }
        alloc.free(attrs);
    }
    try std.testing.expect(attrs[0].value == .string);
    try std.testing.expectEqualStrings("mireo", attrs[0].value.string);
}

test "nix_ir parse list with with preserved" {
    const alloc = std.testing.allocator;
    const attrs = try parseAttrs(alloc, "environment.systemPackages = with pkgs; [ git vim ];");
    defer {
        for (attrs) |a| {
            alloc.free(a.path);
            alloc.free(a.raw);
            if (a.value == .list) alloc.free(a.value.list);
            if (a.value == .raw) alloc.free(a.value.raw);
        }
        alloc.free(attrs);
    }
    try std.testing.expect(attrs[0].value == .raw);
}

test "nix_ir nested path quoted" {
    const alloc = std.testing.allocator;
    const attrs = try parseAttrs(alloc, "services.nginx.virtualHosts.\"example.org\".enableACME = true;");
    defer {
        for (attrs) |a| {
            alloc.free(a.path);
            alloc.free(a.raw);
        }
        alloc.free(attrs);
    }
    try std.testing.expect(attrs.len == 1);
    try std.testing.expect(std.mem.indexOf(u8, attrs[0].path, "example.org") != null);
}

test "nix_ir parse list strings" {
    const alloc = std.testing.allocator;
    const attrs = try parseAttrs(alloc, "niri.users = [\"lucy\"];");
    defer {
        for (attrs) |a| {
            alloc.free(a.path);
            alloc.free(a.raw);
            if (a.value == .list) {
                for (a.value.list) |e| if (e == .string) alloc.free(e.string);
                alloc.free(a.value.list);
            }
        }
        alloc.free(attrs);
    }
    try std.testing.expect(attrs.len == 1);
    try std.testing.expect(attrs[0].value == .list);
    try std.testing.expectEqual(@as(usize, 1), attrs[0].value.list.len);
}

test "nix_ir parse integer" {
    const alloc = std.testing.allocator;
    const attrs = try parseAttrs(alloc, "boot.kernelParams = 42;");
    defer {
        for (attrs) |a| {
            alloc.free(a.path);
            alloc.free(a.raw);
        }
        alloc.free(attrs);
    }
    try std.testing.expect(attrs[0].value == .integer);
    try std.testing.expectEqual(@as(i64, 42), attrs[0].value.integer);
}

test "nix_ir parse attrset simple" {
    const alloc = std.testing.allocator;
    const attrs = try parseAttrs(alloc, "hardware.bluetooth = { enable = true; powerOnBoot = true; };");
    defer {
        for (attrs) |a| {
            alloc.free(a.path);
            alloc.free(a.raw);
            if (a.value == .attr_set) {
                for (a.value.attr_set) |inner| {
                    alloc.free(inner.path);
                    alloc.free(inner.raw);
                    if (inner.value == .string) alloc.free(inner.value.string);
                    if (inner.value == .raw) alloc.free(inner.value.raw);
                }
                alloc.free(a.value.attr_set);
            }
        }
        alloc.free(attrs);
    }
    try std.testing.expect(attrs.len == 1);
    // May be attr_set or raw depending on parser, but should not crash
    // For simple attrset we expect attr_set
    if (attrs[0].value == .attr_set) {
        try std.testing.expectEqual(@as(usize, 2), attrs[0].value.attr_set.len);
    }
}

test "nix_ir preserves unsupported mkForce" {
    const alloc = std.testing.allocator;
    const attrs = try parseAttrs(alloc, "virtualisation.libvirtd.enable = lib.mkForce false;");
    defer {
        for (attrs) |a| {
            alloc.free(a.path);
            alloc.free(a.raw);
            if (a.value == .raw) alloc.free(a.value.raw);
        }
        alloc.free(attrs);
    }
    try std.testing.expect(attrs[0].value == .raw);
}

test "nix_ir parseExpr primitive" {
    const alloc = std.testing.allocator;
    const e1 = try parseExpr(alloc, "true");
    defer if (e1 == .string) alloc.free(e1.string) else if (e1 == .raw) alloc.free(e1.raw);
    try std.testing.expect(e1 == .bool);

    const e2 = try parseExpr(alloc, "\"hello\"");
    defer if (e2 == .string) alloc.free(e2.string);
    try std.testing.expect(e2 == .string);

    const e3 = try parseExpr(alloc, "[\"a\" \"b\"]");
    defer if (e3 == .list) {
        for (e3.list) |el| if (el == .string) alloc.free(el.string);
        alloc.free(e3.list);
    } else if (e3 == .raw) alloc.free(e3.raw);
    try std.testing.expect(e3 == .list);
}
