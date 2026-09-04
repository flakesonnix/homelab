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

    pub fn init(allocator: std.mem.Allocator, file: []const u8, source: []const u8) Diagnostics {
        return .{
            .allocator = allocator,
            .list = .empty,
            .source = source,
            .file = file,
        };
    }

    pub fn deinit(self: *Diagnostics) void {
        self.list.deinit(self.allocator);
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

    pub fn render(self: *const Diagnostics, writer: anytype) !void {
        for (self.list.items) |d| {
            const sev = switch (d.severity) {
                .err => "error",
                .warning => "warning",
                .info => "info",
            };
            const code = switch (d.code) {
                .unknown_role => "E042",
                .duplicate_decl => "E010",
                .unknown_preset => "E043",
                .unknown_bundle => "E044",
                .unknown_package => "E045",
                .parse_error => "E001",
                .lex_error => "E002",
                .unknown_ident => "E003",
                .duplicate_import => "E011",
            };
            try writer.print("purr {s}[{s}]: {s}\n", .{ sev, code, d.message });
            if (d.span) |sp| {
                try writer.print("  --> {s}:{d}:{d}\n", .{ sp.file, sp.line, sp.col });
                // print line context if available
                if (sp.start < self.source.len) {
                    const line_start = blk: {
                        var i = sp.start;
                        while (i > 0 and self.source[i - 1] != '\n') : (i -= 1) {}
                        break :blk i;
                    };
                    const line_end = blk: {
                        var i = sp.start;
                        while (i < self.source.len and self.source[i] != '\n') : (i += 1) {}
                        break :blk i;
                    };
                    const line = self.source[line_start..line_end];
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
