const std = @import("std");
const diagnostics = @import("diagnostics.zig");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const semantic = @import("semantic.zig");
const nix = @import("nix.zig");
const resolver = @import("resolver.zig");
const fmt = @import("fmt.zig");
const lint = @import("lint.zig");

const Command = enum { check, compile, fmt, lint, eval, rebuild, help };

pub fn run(init: std.process.Init, args: []const []const u8) !u8 {
    const allocator = init.gpa;
    const io = init.io;

    if (args.len < 2) {
        try printHelp(io);
        return 0;
    }
    const cmd_str = args[1];
    const cmd: Command = if (std.mem.eql(u8, cmd_str, "check")) .check else if (std.mem.eql(u8, cmd_str, "compile")) .compile else if (std.mem.eql(u8, cmd_str, "fmt")) .fmt else if (std.mem.eql(u8, cmd_str, "lint")) .lint else if (std.mem.eql(u8, cmd_str, "eval")) .eval else if (std.mem.eql(u8, cmd_str, "rebuild")) .rebuild else if (std.mem.eql(u8, cmd_str, "help") or std.mem.eql(u8, cmd_str, "--help") or std.mem.eql(u8, cmd_str, "-h")) .help else {
        std.debug.print("purr error: unknown command `{s}`\n", .{cmd_str});
        try printHelp(io);
        return 1;
    };
    if (cmd == .help) {
        try printHelp(io);
        return 0;
    }

    // handle `purr <cmd> --help` as help
    if (args.len >= 3 and (std.mem.eql(u8, args[2], "--help") or std.mem.eql(u8, args[2], "-h"))) {
        try printHelp(io);
        return 0;
    }
    // rebuild takes host name, not file
    if (cmd == .rebuild) {
        if (args.len < 3) {
            std.debug.print("purr error: missing host argument\n", .{});
            try printHelp(io);
            return 1;
        }
        var host: ?[]const u8 = null;
        var dry_run = false;
        for (args[2..]) |a| {
            if (std.mem.eql(u8, a, "--dry-run")) dry_run = true else if (host == null and a[0] != '-') host = a;
        }
        if (host == null) {
            std.debug.print("purr error: missing host argument\n", .{});
            try printHelp(io);
            return 1;
        }
        return try rebuildHost(allocator, io, host.?, dry_run);
    }
    if (args.len < 3) {
        std.debug.print("purr error: missing file argument\n", .{});
        try printHelp(io);
        return 1;
    }
    const file = args[2];
    var out_path: ?[]const u8 = null;
    var json_flag = false;
    if (cmd == .compile or cmd == .fmt) {
        for (args, 0..) |a, i| {
            if (std.mem.eql(u8, a, "--out") or std.mem.eql(u8, a, "-o")) {
                if (i + 1 < args.len) out_path = args[i + 1];
            }
        }
    }
    if (cmd == .check) {
        for (args) |a| {
            if (std.mem.eql(u8, a, "--json")) json_flag = true;
        }
    }
    if (cmd == .eval) {
        for (args) |a| {
            if (std.mem.eql(u8, a, "--json")) json_flag = true;
        }
        for (args, 0..) |a, i| {
            if (std.mem.eql(u8, a, "--out") or std.mem.eql(u8, a, "-o")) {
                if (i + 1 < args.len) out_path = args[i + 1];
            }
        }
    }

    return try processFile(allocator, io, file, cmd, out_path, json_flag);
}

fn printHelp(io: std.Io) !void {
    _ = io;
    const msg =
        \\purr — Lucy's Nix DSL compiler (Zig 0.16.0, purrc)
        \\
        \\Usage:
        \\  purr check <file.purr> [--json]      Parse + semantic check
        \\  purr compile <file.purr> [--out out.nix]   Generate Nix
        \\  purr fmt <file.purr> [--out out.purr]     Format
        \\  purr lint <file.purr>               Lint (unused/duplicate/empty/unformatted)
        \\  purr eval <file.purr> [--json]      Compile to Nix and nix eval
        \\  purr rebuild <host>                 nixos-rebuild switch for host
        \\  purr help
        \\
        \\Examples:
        \\  purr check examples/minimal.purr
        \\  purr check examples/minimal.purr --json
        \\  purr compile hosts/x270.purr --out generated.nix
        \\  purr fmt examples/minimal.purr
        \\  purr lint examples/minimal.purr
        \\  purr eval examples/minimal.purr
        \\  purr rebuild x270
        \\  purr rebuild mireo
        \\
    ;
    std.debug.print("{s}", .{msg});
}

fn writeStdout(io: std.Io, bytes: []const u8) !void {
    try std.Io.File.stdout().writeStreamingAll(io, bytes);
}

fn processFile(allocator: std.mem.Allocator, io: std.Io, file: []const u8, cmd: Command, out_path: ?[]const u8, json_flag: bool) !u8 {
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
        if (cmd == .check and json_flag) {
            var aw: std.Io.Writer.Allocating = .init(allocator);
            defer aw.deinit();
            try diag.renderJson(&aw.writer);
            try writeStdout(io, aw.written());
            try writeStdout(io, "\n");
            return 1;
        }
        std.debug.print("lex error: {s}\n", .{@errorName(err)});
        return 1;
    };

    var p = parser.Parser.initWithSource(tokens, &diag, &arena, source);
    var prog = p.parseProgram() catch {
        if (cmd == .check and json_flag) {
            var aw: std.Io.Writer.Allocating = .init(allocator);
            defer aw.deinit();
            try diag.renderJson(&aw.writer);
            try writeStdout(io, aw.written());
            try writeStdout(io, "\n");
            return 1;
        }
        var aw: std.Io.Writer.Allocating = .init(allocator);
        defer aw.deinit();
        const writer = &aw.writer;
        try diag.render(writer);
        std.debug.print("{s}", .{aw.written()});
        return 1;
    };
    const original_prog = prog;
    // Resolve imports (flatten transitive)
    var res = resolver.Resolver.init(allocator, io, cwd, &diag, &arena);
    defer res.deinit();
    const resolved = res.resolve(file, &prog) catch |err| {
        if (cmd == .check and json_flag) {
            var aw: std.Io.Writer.Allocating = .init(allocator);
            defer aw.deinit();
            try diag.renderJson(&aw.writer);
            try writeStdout(io, aw.written());
            try writeStdout(io, "\n");
            return 1;
        }
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

    if (cmd == .check and json_flag) {
        var l = lint.Lint.init(&original_prog, &prog, source, file, &diag, arena_alloc);
        try l.checkUnusedLets();
    }

    // Lint checks (always run, even if hasErrors? but only emit warnings if no parse errors)
    if (cmd == .lint) {
        var l = lint.Lint.init(&original_prog, &prog, source, file, &diag, arena_alloc);
        try l.run();
    }

    if (diag.hasErrors()) {
        if (cmd == .check and json_flag) {
            var aw: std.Io.Writer.Allocating = .init(allocator);
            defer aw.deinit();
            try diag.renderJson(&aw.writer);
            try writeStdout(io, aw.written());
            try writeStdout(io, "\n");
            return 1;
        }
        var aw: std.Io.Writer.Allocating = .init(allocator);
        defer aw.deinit();
        const writer = &aw.writer;
        try diag.render(writer);
        std.debug.print("{s}", .{aw.written()});
        return 1;
    }

    if (cmd == .check and json_flag) {
        var aw: std.Io.Writer.Allocating = .init(allocator);
        defer aw.deinit();
        try diag.renderJson(&aw.writer);
        try writeStdout(io, aw.written());
        try writeStdout(io, "\n");
        return 0;
    }

    // For lint, report warnings but exit 0 if only warnings
    if (cmd == .lint) {
        var has_warnings = false;
        for (diag.list.items) |d| {
            if (d.severity == .warning) has_warnings = true;
        }
        if (has_warnings) {
            var aw: std.Io.Writer.Allocating = .init(allocator);
            defer aw.deinit();
            const writer = &aw.writer;
            try diag.render(writer);
            std.debug.print("{s}", .{aw.written()});
            std.debug.print("purr: lint {s} — {d} warning(s)\n", .{ file, diag.list.items.len });
        } else {
            std.debug.print("purr: lint {s} ok — no warnings\n", .{file});
        }
        return 0;
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
    } else if (cmd == .fmt) {
        const formatted = try fmt.format(&original_prog, allocator);
        defer allocator.free(formatted);
        if (out_path) |out| {
            try cwd.writeFile(io, .{ .sub_path = out, .data = formatted });
            std.debug.print("purr: fmt {s} -> {s} ({d} bytes)\n", .{ file, out, formatted.len });
        } else {
            // check if already formatted: if formatted == source, say ok else print diff hint
            if (std.mem.eql(u8, formatted, source)) {
                std.debug.print("purr: fmt {s} ok — already formatted\n", .{file});
            } else {
                // write formatted to stdout for now (real fmt would overwrite)
                std.debug.print("{s}", .{formatted});
                std.debug.print("purr: fmt {s} — formatted output above (use --out to write)\n", .{file});
            }
        }
    } else if (cmd == .eval) {
        const nix_source = try nix.generate(&prog, allocator);
        defer allocator.free(nix_source);
        // Write to temp file and nix eval
        const tmp_path = "/tmp/purr-eval.nix";
        cwd.writeFile(io, .{ .sub_path = tmp_path, .data = nix_source }) catch |err| {
            std.debug.print("purr error: cannot write temp {s}: {s}\n", .{ tmp_path, @errorName(err) });
            return 1;
        };
        defer cwd.deleteFile(io, tmp_path) catch {};
        std.debug.print("purr: eval {s} -> {s} ({d} bytes generated)\n", .{ file, tmp_path, nix_source.len });
        std.debug.print("purr: running nix eval --file {s}{s}\n", .{ tmp_path, if (json_flag) " --json" else "" });
        const argv = if (json_flag) &[_][]const u8{ "nix", "eval", "--file", tmp_path, "--json" } else &[_][]const u8{ "nix", "eval", "--file", tmp_path };
        const result = std.process.run(allocator, io, .{ .argv = argv }) catch |err| {
            std.debug.print("purr error: cannot run nix eval: {s}\n", .{@errorName(err)});
            std.debug.print("generated Nix at {s}:\n{s}\n", .{ tmp_path, nix_source });
            return 1;
        };
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);
        if (result.stderr.len > 0) std.debug.print("{s}", .{result.stderr});
        if (result.stdout.len > 0) std.debug.print("{s}\n", .{result.stdout});
        switch (result.term) {
            .exited => |code| if (code != 0) {
                std.debug.print("purr error: nix eval failed with code {d}\n", .{code});
                std.debug.print("generated Nix kept at {s} for debugging\n", .{tmp_path});
                return 1;
            },
            else => {
                std.debug.print("purr error: nix eval terminated abnormally\n", .{});
                return 1;
            },
        }
        std.debug.print("purr: eval {s} ok\n", .{file});
    }

    return 0;
}

fn rebuildHost(allocator: std.mem.Allocator, io: std.Io, host: []const u8, dry_run: bool) !u8 {
    // Validate host name (simple: non-empty, alphanumeric + - _)
    if (host.len == 0) {
        std.debug.print("purr error: empty host name\n", .{});
        return 1;
    }
    for (host) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '-' and c != '_' ) {
            std.debug.print("purr error: invalid host name `{s}`\n", .{host});
            return 1;
        }
    }
    if (dry_run) {
        std.debug.print("nixos-rebuild switch --flake .#{s}\n", .{host});
        return 0;
    }
    std.debug.print("purr: rebuild {s} — running nixos-rebuild switch --flake .#{s}\n", .{ host, host });
    const flake_ref = try std.fmt.allocPrint(allocator, ".#{s}", .{host});
    defer allocator.free(flake_ref);
    const argv = [_][]const u8{ "nixos-rebuild", "switch", "--flake", flake_ref };
    const result = std.process.run(allocator, io, .{ .argv = &argv }) catch |err| {
        std.debug.print("purr error: cannot spawn nixos-rebuild: {s}\n", .{@errorName(err)});
        return 1;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    if (result.stderr.len > 0) std.debug.print("{s}", .{result.stderr});
    if (result.stdout.len > 0) std.debug.print("{s}\n", .{result.stdout});
    switch (result.term) {
        .exited => |code| {
            if (code != 0) {
                std.debug.print("purr: rebuild {s} failed with code {d}\n", .{ host, code });
                return code;
            }
        },
        else => {
            std.debug.print("purr error: nixos-rebuild terminated abnormally\n", .{});
            return 1;
        },
    }
    std.debug.print("purr: rebuild {s} ok\n", .{host});
    return 0;
}
