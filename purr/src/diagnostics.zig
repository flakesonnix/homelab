const std = @import("std");

pub const Severity = enum { err, warning, info };
pub const Code = enum {
    unknown_role,
    duplicate_decl,
    unknown_preset,
    unknown_bundle,
    unknown_package,
    parse_error,
    lex_error,
    unknown_ident,
    duplicate_import,
    unused_import,
    empty_decl,
    unformatted,
    unknown_parent,
    inheritance_cycle,
    self_inheritance,
    unused_let,
};

pub const Span = struct {
    file: []const u8,
    line: u32,
    col: u32,
    len: u32,
    // byte offsets for underline
    start: usize,
    end: usize,
};

pub const Diagnostic = struct {
    severity: Severity,
    code: Code,
    message: []const u8,
    span: ?Span,
    help: ?[]const u8,
};

pub const Diagnostics = struct {
    allocator: std.mem.Allocator,
    list: std.ArrayListUnmanaged(Diagnostic),
    source: []const u8,
    file: []const u8,
    // multi-file source map for resolver (file -> source). Initialized lazily.
    source_map: ?std.StringHashMap([]const u8) = null,

    pub fn init(allocator: std.mem.Allocator, file: []const u8, source: []const u8) Diagnostics {
        var self = Diagnostics{
            .allocator = allocator,
            .list = .empty,
            .source = source,
            .file = file,
            .source_map = std.StringHashMap([]const u8).init(allocator),
        };
        // seed map with primary file
        self.source_map.?.put(file, source) catch {};
        return self;
    }

    pub fn deinit(self: *Diagnostics) void {
        self.list.deinit(self.allocator);
        if (self.source_map) |*m| m.deinit();
    }

    pub fn addSource(self: *Diagnostics, file: []const u8, source: []const u8) !void {
        if (self.source_map == null) {
            self.source_map = std.StringHashMap([]const u8).init(self.allocator);
        }
        try self.source_map.?.put(file, source);
    }

    fn lookupSource(self: *const Diagnostics, file: []const u8) []const u8 {
        if (self.source_map) |m| {
            if (m.get(file)) |src| return src;
        }
        // fallback: if requested file matches primary, return primary source
        if (std.mem.eql(u8, file, self.file)) return self.source;
        return self.source;
    }

    pub fn push(self: *Diagnostics, d: Diagnostic) !void {
        try self.list.append(self.allocator, d);
    }

    pub fn hasErrors(self: *const Diagnostics) bool {
        for (self.list.items) |d| {
            if (d.severity == .err) return true;
        }
        return false;
    }

    pub fn severityString(sev: Severity) []const u8 {
        return switch (sev) {
            .err => "error",
            .warning => "warning",
            .info => "info",
        };
    }

    pub fn codeString(code: Code) []const u8 {
        return switch (code) {
            .unknown_role => "E042",
            .duplicate_decl => "E010",
            .unknown_preset => "E043",
            .unknown_bundle => "E044",
            .unknown_package => "E045",
            .parse_error => "E001",
            .lex_error => "E002",
            .unknown_ident => "E003",
            .duplicate_import => "E011",
            .unused_import => "W001",
            .empty_decl => "W002",
            .unformatted => "W003",
            .unknown_parent => "E050",
            .inheritance_cycle => "E051",
            .self_inheritance => "E052",
            .unused_let => "W004",
        };
    }

    pub fn sortDiagnostics(self: *Diagnostics) void {
        const items = self.list.items;
        for (0..items.len) |i| {
            for (i + 1..items.len) |j| {
                const a = items[i].span orelse Span{ .file = "", .line = 0, .col = 0, .len = 0, .start = 0, .end = 0 };
                const b = items[j].span orelse Span{ .file = "", .line = 0, .col = 0, .len = 0, .start = 0, .end = 0 };
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

    pub fn render(self: *const Diagnostics, writer: anytype) !void {
        for (self.list.items) |d| {
            const sev = severityString(d.severity);
            const code = codeString(d.code);
            try writer.print("purr {s}[{s}]: {s}\n", .{ sev, code, d.message });
            if (d.span) |sp| {
                try writer.print("  --> {s}:{d}:{d}\n", .{ sp.file, sp.line, sp.col });
                // print line context if available
                const src = self.lookupSource(sp.file);
                if (sp.start < src.len) {
                    const line_start = blk: {
                        var i = sp.start;
                        while (i > 0 and src[i - 1] != '\n') : (i -= 1) {}
                        break :blk i;
                    };
                    const line_end = blk: {
                        var i = sp.start;
                        while (i < src.len and src[i] != '\n') : (i += 1) {}
                        break :blk i;
                    };
                    const line = src[line_start..line_end];
                    try writer.print("   |\n{d} | {s}\n", .{ sp.line, line });
                    try writer.print("   | {s}{s}\n", .{ " " ** 0, "" });
                    // underline
                    const col0 = sp.col - 1;
                    try writer.writeAll("   | ");
                    for (0..col0) |_| try writer.writeAll(" ");
                    for (0..sp.len) |_| try writer.writeAll("^");
                    try writer.writeAll("\n");
                }
            }
            if (d.help) |h| {
                try writer.print("help: {s}\n", .{h});
            }
            try writer.writeAll("\n");
        }
    }

    pub fn renderJson(self: *Diagnostics, writer: anytype) !void {
        // deterministic ordering: file -> line -> col
        self.sortDiagnostics();
        try writer.writeAll("{\"file\":");
        try writeJsonString(writer, self.file);
        try writer.print(",\"ok\":{},\"diagnostics\":[", .{!self.hasErrors()});
        for (self.list.items, 0..) |d, idx| {
            if (idx > 0) try writer.writeAll(",");
            try writer.writeAll("{\"severity\":");
            try writeJsonString(writer, severityString(d.severity));
            try writer.writeAll(",\"code\":");
            try writeJsonString(writer, codeString(d.code));
            try writer.writeAll(",\"codeName\":");
            try writeJsonString(writer, @tagName(d.code));
            try writer.writeAll(",\"message\":");
            try writeJsonString(writer, d.message);
            try writer.writeAll(",\"span\":");
            if (d.span) |sp| {
                try writer.writeAll("{\"file\":");
                try writeJsonString(writer, sp.file);
                try writer.print(",\"line\":{d},\"col\":{d},\"len\":{d},\"start\":{d},\"end\":{d}}}", .{ sp.line, sp.col, sp.len, sp.start, sp.end });
            } else {
                try writer.writeAll("null");
            }
            try writer.writeAll(",\"help\":");
            if (d.help) |h| {
                try writeJsonString(writer, h);
            } else {
                try writer.writeAll("null");
            }
            try writer.writeAll("}");
        }
        try writer.writeAll("]}");
    }

    fn writeJsonString(writer: anytype, s: []const u8) !void {
        try writer.writeAll("\"");
        for (s) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                0x08 => try writer.writeAll("\\b"),
                0x0C => try writer.writeAll("\\f"),
                else => if (c < 0x20) {
                    try writer.print("\\u{x:0>4}", .{c});
                } else {
                    try writer.writeByte(c);
                },
            }
        }
        try writer.writeAll("\"");
    }

    // levenshtein distance for suggestions (small strings, simple DP)
    pub fn suggest(needle: []const u8, candidates: []const []const u8, allocator: std.mem.Allocator) !?[]const u8 {
        var best: ?[]const u8 = null;
        var best_dist: usize = 999;
        for (candidates) |c| {
            const d = levenshtein(needle, c);
            if (d < best_dist and d <= 2) {
                best_dist = d;
                best = c;
            }
        }
        if (best) |b| {
            return try std.fmt.allocPrint(allocator, "did you mean `{s}`?", .{b});
        }
        return null;
    }

    fn levenshtein(a: []const u8, b: []const u8) usize {
        // small stack buffer for typical ident lengths < 32
        var prev: [64]usize = undefined;
        var cur: [64]usize = undefined;
        const n = @min(a.len, 63);
        const m = @min(b.len, 63);
        for (0..m + 1) |j| prev[j] = j;
        for (1..n + 1) |i| {
            cur[0] = i;
            for (1..m + 1) |j| {
                const cost: usize = if (a[i - 1] == b[j - 1]) 0 else 1;
                cur[j] = @min(@min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
            }
            @memcpy(prev[0 .. m + 1], cur[0 .. m + 1]);
        }
        return prev[m];
    }
};

test "levenshtein suggest" {
    const alloc = std.testing.allocator;
    const cands = [_][]const u8{ "desktop", "gaming", "developer" };
    const help = try Diagnostics.suggest("gamign", &cands, alloc);
    defer if (help) |h| alloc.free(h);
    try std.testing.expect(help != null);
    try std.testing.expect(std.mem.indexOf(u8, help.?, "gaming") != null);
}

test "renderJson success" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    var diag = Diagnostics.init(arena.allocator(), "test.purr", "host x {}");
    var aw: std.Io.Writer.Allocating = .init(alloc);
    defer aw.deinit();
    try diag.renderJson(&aw.writer);
    const out = aw.written();
    try std.testing.expect(std.mem.indexOf(u8, out, "\"file\":\"test.purr\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"ok\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"diagnostics\":[]") != null);
}

test "renderJson error" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    var diag = Diagnostics.init(arena.allocator(), "test.purr", "host x {}");
    try diag.push(.{
        .severity = .err,
        .code = .unknown_role,
        .message = "unknown role `gamign`",
        .span = .{ .file = "test.purr", .line = 2, .col = 9, .len = 6, .start = 20, .end = 26 },
        .help = "did you mean `gaming`?",
    });
    var aw: std.Io.Writer.Allocating = .init(alloc);
    defer aw.deinit();
    try diag.renderJson(&aw.writer);
    const out = aw.written();
    try std.testing.expect(std.mem.indexOf(u8, out, "\"ok\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"code\":\"E042\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"codeName\":\"unknown_role\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"message\":\"unknown role `gamign`\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"line\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"col\":9") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"help\":\"did you mean") != null);
}

test "renderJson escaping" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    var diag = Diagnostics.init(arena.allocator(), "test.purr", "a");
    try diag.push(.{
        .severity = .err,
        .code = .parse_error,
        .message = "bad \"quote\" and \\ slash",
        .span = null,
        .help = "line\nbreak",
    });
    var aw: std.Io.Writer.Allocating = .init(alloc);
    defer aw.deinit();
    try diag.renderJson(&aw.writer);
    const out = aw.written();
    try std.testing.expect(std.mem.indexOf(u8, out, "\\\"quote\\\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\\\\ slash") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\"span\":null") != null);
}
