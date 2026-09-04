const std = @import("std");
const ast = @import("ast.zig");

pub fn format(program: *const ast.Program, allocator: std.mem.Allocator) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    // imports first
    for (program.imports) |imp| {
        try buf.appendSlice(allocator, "import \"");
        try escapeString(&buf, allocator, imp.path);
        try buf.appendSlice(allocator, "\";\n");
    }
    if (program.imports.len > 0 and program.decls.len > 0) try buf.appendSlice(allocator, "\n");

    for (program.decls, 0..) |decl, idx| {
        switch (decl) {
            .role => |r| try formatRole(&buf, allocator, r),
            .host => |h| try formatHost(&buf, allocator, h),
            .bundle => |b| try formatBundle(&buf, allocator, b),
            .preset => |p| try formatPreset(&buf, allocator, p),
            .package_decl => |pkg| {
                try buf.appendSlice(allocator, "package \"");
                try escapeString(&buf, allocator, pkg.name);
                try buf.appendSlice(allocator, "\";\n");
            },
            .nix => |n| {
                try buf.appendSlice(allocator, "nix {");
                // raw content already includes newlines; ensure surrounding newlines
                if (n.content.len > 0 and n.content[0] != '\n') try buf.appendSlice(allocator, "\n");
                try buf.appendSlice(allocator, n.content);
                if (n.content.len == 0 or n.content[n.content.len - 1] != '\n') try buf.appendSlice(allocator, "\n");
                try buf.appendSlice(allocator, "}\n");
            },
        }
        if (idx + 1 < program.decls.len) try buf.appendSlice(allocator, "\n");
    }
    return try buf.toOwnedSlice(allocator);
}

fn formatRole(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, r: ast.Role) !void {
    try buf.appendSlice(allocator, "role ");
    try buf.appendSlice(allocator, r.name.name);
    try buf.appendSlice(allocator, " {\n");
    if (r.description) |d| {
        try buf.appendSlice(allocator, "    description = \"");
        try escapeString(buf, allocator, d);
        try buf.appendSlice(allocator, "\";\n");
    }
    if (r.targets.len > 0) {
        try buf.appendSlice(allocator, "    targets = [");
        for (r.targets, 0..) |t, i| {
            if (i > 0) try buf.appendSlice(allocator, ", ");
            try buf.appendSlice(allocator, "\"");
            try escapeString(buf, allocator, t);
            try buf.appendSlice(allocator, "\"");
        }
        try buf.appendSlice(allocator, "];\n");
    }
    if (r.requires_host.len > 0) {
        try buf.appendSlice(allocator, "    requires = [");
        for (r.requires_host, 0..) |t, i| {
            if (i > 0) try buf.appendSlice(allocator, ", ");
            try buf.appendSlice(allocator, "\"");
            try escapeString(buf, allocator, t);
            try buf.appendSlice(allocator, "\"");
        }
        try buf.appendSlice(allocator, "];\n");
    }
    if (r.conflicts_host.len > 0) {
        try buf.appendSlice(allocator, "    conflicts = [");
        for (r.conflicts_host, 0..) |t, i| {
            if (i > 0) try buf.appendSlice(allocator, ", ");
            try buf.appendSlice(allocator, "\"");
            try escapeString(buf, allocator, t);
            try buf.appendSlice(allocator, "\"");
        }
        try buf.appendSlice(allocator, "];\n");
    }
    if (r.host) |hb| {
        try buf.appendSlice(allocator, "    host {\n");
        if (hb.presets.len > 0) {
            try buf.appendSlice(allocator, "        presets = [");
            for (hb.presets, 0..) |p, i| {
                if (i > 0) try buf.appendSlice(allocator, ", ");
                try buf.appendSlice(allocator, "\"");
                try escapeString(buf, allocator, p);
                try buf.appendSlice(allocator, "\"");
            }
            try buf.appendSlice(allocator, "];\n");
        }
        if (hb.tags.len > 0) {
            try buf.appendSlice(allocator, "        tags = [");
            for (hb.tags, 0..) |t, i| {
                if (i > 0) try buf.appendSlice(allocator, ", ");
                try buf.appendSlice(allocator, "\"");
                try escapeString(buf, allocator, t);
                try buf.appendSlice(allocator, "\"");
            }
            try buf.appendSlice(allocator, "];\n");
        }
        try buf.appendSlice(allocator, "    }\n");
    }
    if (r.home) |hb| {
        try buf.appendSlice(allocator, "    home {\n");
        if (hb.bundles.len > 0) {
            try buf.appendSlice(allocator, "        bundles = [");
            for (hb.bundles, 0..) |b, i| {
                if (i > 0) try buf.appendSlice(allocator, ", ");
                try buf.appendSlice(allocator, "\"");
                try escapeString(buf, allocator, b);
                try buf.appendSlice(allocator, "\"");
            }
            try buf.appendSlice(allocator, "];\n");
        }
        try buf.appendSlice(allocator, "    }\n");
    }
    try buf.appendSlice(allocator, "}\n");
}

fn formatHost(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, h: ast.Host) !void {
    try buf.appendSlice(allocator, "host ");
    try buf.appendSlice(allocator, h.name.name);
    try buf.appendSlice(allocator, " {\n");
    for (h.stmts) |stmt| {
        switch (stmt) {
            .use_role => |ident| {
                try buf.appendSlice(allocator, "    use ");
                try buf.appendSlice(allocator, ident.name);
                try buf.appendSlice(allocator, ";\n");
            },
            .preset => |ident| {
                try buf.appendSlice(allocator, "    preset ");
                try buf.appendSlice(allocator, ident.name);
                try buf.appendSlice(allocator, ";\n");
            },
            .package => |pkg| {
                try buf.appendSlice(allocator, "    package \"");
                try escapeString(buf, allocator, pkg);
                try buf.appendSlice(allocator, "\";\n");
            },
            .packages_assign => |tags| {
                try buf.appendSlice(allocator, "    packages = [");
                for (tags, 0..) |t, i| {
                    if (i > 0) try buf.appendSlice(allocator, ", ");
                    try buf.appendSlice(allocator, "\"");
                    try escapeString(buf, allocator, t);
                    try buf.appendSlice(allocator, "\"");
                }
                try buf.appendSlice(allocator, "];\n");
            },
            .setting => |s| {
                if (std.mem.eql(u8, s.path, "nix_raw")) {
                    try buf.appendSlice(allocator, "    nix {");
                    switch (s.value) {
                        .string => |raw| {
                            if (raw.len > 0 and raw[0] != '\n') try buf.appendSlice(allocator, "\n");
                            try buf.appendSlice(allocator, raw);
                            if (raw.len == 0 or raw[raw.len - 1] != '\n') try buf.appendSlice(allocator, "\n");
                        },
                        else => {
                            try buf.appendSlice(allocator, " ");
                            try formatValue(buf, allocator, s.value);
                            try buf.appendSlice(allocator, " ");
                        },
                    }
                    try buf.appendSlice(allocator, "    }\n");
                } else {
                    try buf.appendSlice(allocator, "    ");
                    try buf.appendSlice(allocator, s.path);
                    try buf.appendSlice(allocator, " = ");
                    try formatValue(buf, allocator, s.value);
                    try buf.appendSlice(allocator, ";\n");
                }
            },
        }
    }
    try buf.appendSlice(allocator, "}\n");
}

fn formatBundle(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, b: ast.Bundle) !void {
    try buf.appendSlice(allocator, "bundle ");
    try buf.appendSlice(allocator, b.name.name);
    try buf.appendSlice(allocator, " {\n");
    if (b.description) |d| {
        try buf.appendSlice(allocator, "    description = \"");
        try escapeString(buf, allocator, d);
        try buf.appendSlice(allocator, "\";\n");
    }
    if (b.programs.len > 0) {
        try buf.appendSlice(allocator, "    programs = [");
        for (b.programs, 0..) |p, i| {
            if (i > 0) try buf.appendSlice(allocator, ", ");
            try buf.appendSlice(allocator, "\"");
            try escapeString(buf, allocator, p);
            try buf.appendSlice(allocator, "\"");
        }
        try buf.appendSlice(allocator, "];\n");
    }
    if (b.package_toggles.len > 0) {
        try buf.appendSlice(allocator, "    packages = [");
        for (b.package_toggles, 0..) |t, i| {
            if (i > 0) try buf.appendSlice(allocator, ", ");
            try buf.appendSlice(allocator, "\"");
            try escapeString(buf, allocator, t);
            try buf.appendSlice(allocator, "\"");
        }
        try buf.appendSlice(allocator, "];\n");
    }
    try buf.appendSlice(allocator, "}\n");
}

fn formatPreset(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, p: ast.Preset) !void {
    try buf.appendSlice(allocator, "preset ");
    try buf.appendSlice(allocator, p.name.name);
    try buf.appendSlice(allocator, " {\n");
    if (p.description) |d| {
        try buf.appendSlice(allocator, "    description = \"");
        try escapeString(buf, allocator, d);
        try buf.appendSlice(allocator, "\";\n");
    }
    if (p.flags.len > 0) {
        try buf.appendSlice(allocator, "    flags {\n");
        for (p.flags) |f| {
            try buf.appendSlice(allocator, "        ");
            try buf.appendSlice(allocator, f.path);
            try buf.appendSlice(allocator, " = ");
            try formatValue(buf, allocator, f.value);
            try buf.appendSlice(allocator, ";\n");
        }
        try buf.appendSlice(allocator, "    }\n");
    }
    try buf.appendSlice(allocator, "}\n");
}

fn formatValue(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, v: ast.Value) !void {
    switch (v) {
        .string => |s| {
            try buf.appendSlice(allocator, "\"");
            try escapeString(buf, allocator, s);
            try buf.appendSlice(allocator, "\"");
        },
        .integer => |i| {
            const s = try std.fmt.allocPrint(allocator, "{d}", .{i});
            defer allocator.free(s);
            try buf.appendSlice(allocator, s);
        },
        .boolean => |b| try buf.appendSlice(allocator, if (b) "true" else "false"),
        .ident => |id| try buf.appendSlice(allocator, id.name),
        .list => |lst| {
            try buf.appendSlice(allocator, "[");
            for (lst, 0..) |item, idx| {
                if (idx > 0) try buf.appendSlice(allocator, ", ");
                try formatValue(buf, allocator, item);
            }
            try buf.appendSlice(allocator, "]");
        },
    }
}

fn escapeString(buf: *std.ArrayList(u8), allocator: std.mem.Allocator, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try buf.appendSlice(allocator, "\\\""),
            '\\' => try buf.appendSlice(allocator, "\\\\"),
            '\n' => try buf.appendSlice(allocator, "\\n"),
            '\t' => try buf.appendSlice(allocator, "\\t"),
            '\r' => try buf.appendSlice(allocator, "\\r"),
            else => try buf.append(allocator, c),
        }
    }
}

test "fmt roundtrip" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host x270 { use desktop; }";
    const diagnostics = @import("diagnostics.zig");
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    const out = try format(&prog, arena.allocator());
    try std.testing.expect(std.mem.indexOf(u8, out, "host x270") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "use desktop;") != null);
}
