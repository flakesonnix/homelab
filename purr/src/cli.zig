const std = @import("std");
const diagnostics = @import("diagnostics.zig");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const semantic = @import("semantic.zig");
const nix = @import("nix.zig");
const resolver = @import("resolver.zig");

const Command = enum { check, compile, help };

pub fn run(init: std.process.Init, args: []const []const u8) !u8 {
    const allocator = init.gpa;
    const io = init.io;

    if (args.len < 2) {
        try printHelp(io);
        return 0;
    }
    const cmd_str = args[1];
    const cmd: Command = if (std.mem.eql(u8, cmd_str, "check")) .check else if (std.mem.eql(u8, cmd_str, "compile")) .compile else if (std.mem.eql(u8, cmd_str, "help") or std.mem.eql(u8, cmd_str, "--help") or std.mem.eql(u8, cmd_str, "-h")) .help else {
        std.debug.print("purr error: unknown command `{s}`\n", .{cmd_str});
        try printHelp(io);
        return 1;
    };
    if (cmd == .help) {
        try printHelp(io);
        return 0;
    }

    if (args.len < 3) {
        std.debug.print("purr error: missing file argument\n", .{});
        try printHelp(io);
        return 1;
    }
    const file = args[2];
    var out_path: ?[]const u8 = null;
    if (cmd == .compile) {
        for (args, 0..) |a, i| {
            if (std.mem.eql(u8, a, "--out") or std.mem.eql(u8, a, "-o")) {
                if (i + 1 < args.len) out_path = args[i + 1];
            }
        }
    }

    return try processFile(allocator, io, file, cmd, out_path);
}

fn printHelp(io: std.Io) !void {
    _ = io;
    const msg =
        \\purr — Lucy's Nix DSL compiler (Zig 0.16.0, purrc)
        \\
        \\Usage:
        \\  purr check <file.purr>              Parse + semantic check
        \\  purr compile <file.purr> [--out out.nix]   Generate Nix
        \\  purr help
        \\
        \\Examples:
        \\  purr check examples/minimal.purr
        \\  purr compile hosts/x270.purr --out generated.nix
        \\
    ;
    std.debug.print("{s}", .{msg});
}

fn processFile(allocator: std.mem.Allocator, io: std.Io, file: []const u8, cmd: Command, out_path: ?[]const u8) !u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const cwd = std.Io.Dir.cwd();
    const source = cwd.readFileAlloc(io, file, allocator, .limited(10 * 1024 * 1024)) catch |err| {
        std.debug.print("purr error: cannot read `{s}`: {s}\n", .{ file, @errorName(err) });
        return 1;
    };
    defer allocator.free(source);

    var diag = diagnostics.Diagnostics.init(arena_alloc, file, source);
    var lex = lexer.Lexer.init(source, file, &diag);
    const tokens = lex.lexAll(arena_alloc) catch |err| {
        std.debug.print("lex error: {s}\n", .{@errorName(err)});
        return 1;
    };

    var p = parser.Parser.init(tokens, &diag, &arena);
    var prog = p.parseProgram() catch {
        var aw: std.Io.Writer.Allocating = .init(allocator);
        defer aw.deinit();
        const writer = &aw.writer;
        try diag.render(writer);
        std.debug.print("{s}", .{aw.written()});
        return 1;
    };

    // Resolve imports (flatten transitive)
    var res = resolver.Resolver.init(allocator, io, cwd, &diag, &arena);
    defer res.deinit();
    const resolved = res.resolve(file, &prog) catch |err| {
        std.debug.print("purr error: resolver failed: {s}\n", .{@errorName(err)});
        var aw: std.Io.Writer.Allocating = .init(allocator);
        defer aw.deinit();
        const writer = &aw.writer;
        try diag.render(writer);
        std.debug.print("{s}", .{aw.written()});
        return 1;
    };
    // use resolved program for semantic + codegen
    prog = resolved;

    var sem = semantic.Semantic.init(&prog, &diag, arena_alloc);
    try sem.analyze();

    if (diag.hasErrors()) {
        var aw: std.Io.Writer.Allocating = .init(allocator);
        defer aw.deinit();
        const writer = &aw.writer;
        try diag.render(writer);
        std.debug.print("{s}", .{aw.written()});
        return 1;
    }

    std.debug.print("purr: {s} ok ({d} decls, {d} imports)\n", .{ file, prog.decls.len, prog.imports.len });

    if (cmd == .compile) {
        const nix_source = try nix.generate(&prog, allocator);
        defer allocator.free(nix_source);
        if (out_path) |out| {
            try cwd.writeFile(io, .{ .sub_path = out, .data = nix_source });
            std.debug.print("purr: wrote {s} ({d} bytes)\n", .{ out, nix_source.len });
        } else {
            // write to stdout via debug print (for now)
            std.debug.print("{s}", .{nix_source});
        }
    }

    return 0;
}
