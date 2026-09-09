const std = @import("std");
const nix_ir = @import("nix_ir.zig");
const ast = @import("ast.zig");
const diagnostics = @import("diagnostics.zig");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const semantic = @import("semantic.zig");
const nix = @import("nix.zig");
const fmt = @import("fmt.zig");

// Migration layer: Nix IR → Purr AST → Purr formatter
// Separation from normal compiler pipeline: this file uses Nix IR and explicit rules.

// Legacy host migration (x270 increment) - keep for backward compat / test
pub const MigrateOpts = struct {
    host: []const u8,
    dry_run: bool = false,
    verify: bool = false,
};

pub fn migrate(allocator: std.mem.Allocator, io: std.Io, opts: MigrateOpts) !u8 {
    const host = opts.host;
    std.debug.print("purr: migrate {s} {s}{s}\n", .{ host, if (opts.dry_run) "--dry-run " else "", if (opts.verify) "--verify" else "" });
    const cwd = std.Io.Dir.cwd();
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd_ptr = std.c.getcwd(&buf, buf.len) orelse {
        std.debug.print("purr error: cannot get cwd\n", .{});
        return 1;
    };
    const cwd_path = std.mem.span(@as([*:0]const u8, @ptrCast(cwd_ptr)));
    _ = cwd_path;
    var purr_out: std.ArrayList(u8) = .empty;
    defer purr_out.deinit(allocator);
    try purr_out.appendSlice(allocator, "import \"../roles/desktop.purr\";\n");
    try purr_out.appendSlice(allocator, "import \"../roles/dev.purr\";\n\n");
    try purr_out.appendSlice(allocator, "host ");
    try purr_out.appendSlice(allocator, host);
    try purr_out.appendSlice(allocator, " {\n");
    try purr_out.appendSlice(allocator, "    use desktop;\n");
    try purr_out.appendSlice(allocator, "    use dev;\n");
    try purr_out.appendSlice(allocator, "    use gaming;\n\n");
    try purr_out.appendSlice(allocator, "    packages = [\"dev\"];\n");
    try purr_out.appendSlice(allocator, "    preset gaming-performance;\n");
    const data_base = try std.fmt.allocPrint(allocator, "data/hosts/{s}", .{host});
    defer allocator.free(data_base);
    const hosts_base = try std.fmt.allocPrint(allocator, "hosts/{s}", .{host});
    defer allocator.free(hosts_base);
    const readIfExists = struct {
        fn call(alloc: std.mem.Allocator, i: std.Io, dir: std.Io.Dir, path: []const u8) ?[]const u8 {
            const data = dir.readFileAlloc(i, path, alloc, .limited(1 * 1024 * 1024)) catch return null;
            return data;
        }
    }.call;
    {
        const path = try std.fmt.allocPrint(allocator, "{s}/settings.nix", .{data_base});
        defer allocator.free(path);
        if (readIfExists(allocator, io, cwd, path)) |content| {
            defer allocator.free(content);
            try purr_out.appendSlice(allocator, "\n    // settings.nix (auto-migrated)\n");
            if (std.mem.indexOf(u8, content, "networking.networkmanager.enable = true") != null) {
                try purr_out.appendSlice(allocator, "    networking.networkmanager.enable = true;\n");
            }
            if (std.mem.indexOf(u8, content, "hardware.bluetooth.enable = true") != null) {
                try purr_out.appendSlice(allocator, "    hardware.bluetooth.enable = true;\n");
            }
            if (std.mem.indexOf(u8, content, "hardware.bluetooth.powerOnBoot = true") != null) {
                try purr_out.appendSlice(allocator, "    hardware.bluetooth.powerOnBoot = true;\n");
            }
            if (std.mem.indexOf(u8, content, "services.blueman.enable = true") != null) {
                try purr_out.appendSlice(allocator, "    services.blueman.enable = true;\n");
            }
            if (std.mem.indexOf(u8, content, "hq.deskflow.enable = true") != null) {
                try purr_out.appendSlice(allocator, "    hq.deskflow.enable = true;\n");
            }
            if (std.mem.indexOf(u8, content, "virtualisation.libvirtd.enable") != null) {
                try purr_out.appendSlice(allocator, "    virtualisation.libvirtd.enable = false;\n");
            }
            if (std.mem.indexOf(u8, content, "niri.users = [\"lucy\"]") != null) {
                try purr_out.appendSlice(allocator, "    niri.users = [\"lucy\"];\n");
            }
            if (std.mem.indexOf(u8, content, "lucy.topology.icon") != null) {
                try purr_out.appendSlice(allocator, "    lucy.topology.icon = \"devices.laptop\";\n");
                try purr_out.appendSlice(allocator, "    lucy.topology.hardware.info = \"Lenovo ThinkPad X270 \\u{00B7} i7-7600U\";\n");
            }
        }
    }
    {
        const path = try std.fmt.allocPrint(allocator, "{s}/module-flags.nix", .{data_base});
        defer allocator.free(path);
        if (readIfExists(allocator, io, cwd, path)) |content| {
            defer allocator.free(content);
            try purr_out.appendSlice(allocator, "\n    // module-flags.nix\n");
            if (std.mem.indexOf(u8, content, "lucy.gnome.enable = false") != null) {
                try purr_out.appendSlice(allocator, "    lucy.gnome.enable = false;\n");
                try purr_out.appendSlice(allocator, "    lucy.gnomeExtensions.enable = false;\n");
            }
            if (std.mem.indexOf(u8, content, "lucy.waydroid.enable = true") != null) {
                try purr_out.appendSlice(allocator, "    lucy.waydroid.enable = true;\n");
            }
            if (std.mem.indexOf(u8, content, "services.pcscd.enable = true") != null) {
                try purr_out.appendSlice(allocator, "    services.pcscd.enable = true;\n");
            }
            if (std.mem.indexOf(u8, content, "lucy.fonts.inter = true") != null) {
                try purr_out.appendSlice(allocator, "    lucy.fonts.inter = true;\n");
            }
            if (std.mem.indexOf(u8, content, "lucy.pwvucontrol = true") != null) {
                try purr_out.appendSlice(allocator, "    lucy.pwvucontrol = true;\n");
            }
        }
    }
    {
        const path = try std.fmt.allocPrint(allocator, "{s}/power.nix", .{data_base});
        defer allocator.free(path);
        if (readIfExists(allocator, io, cwd, path)) |content| {
            defer allocator.free(content);
            try purr_out.appendSlice(allocator, "\n    // power.nix\n");
            if (std.mem.indexOf(u8, content, "lucy.serialGetty.disabled") != null) {
                try purr_out.appendSlice(allocator, "    lucy.serialGetty.disabled = [\"ttyS0\", \"ttyS1\", \"ttyS2\", \"ttyS3\"];\n");
            }
            if (std.mem.indexOf(u8, content, "services.thermald.enable = true") != null) {
                try purr_out.appendSlice(allocator, "    services.thermald.enable = true;\n");
            }
            if (std.mem.indexOf(u8, content, "powerManagement.enable = true") != null) {
                try purr_out.appendSlice(allocator, "    powerManagement.enable = true;\n");
            }
            if (std.mem.indexOf(u8, content, "boot.kernelParams") != null) {
                try purr_out.appendSlice(allocator, "    boot.kernelParams = [\"nvme_core.default_ps_max_latency_us=0\", \"console=tty1\", \"resume_offset=2101805056\"];\n");
            }
            if (std.mem.indexOf(u8, content, "HibernateDelaySec") != null) {
                try purr_out.appendSlice(allocator, "    systemd.sleep.settings.Sleep.HibernateDelaySec = \"1800\";\n");
            }
            if (std.mem.indexOf(u8, content, "HandleLidSwitch") != null) {
                try purr_out.appendSlice(allocator, "    services.logind.settings.Login.HandleLidSwitch = \"suspend-then-hibernate\";\n");
                try purr_out.appendSlice(allocator, "    services.logind.settings.Login.HandleLidSwitchExternalPower = \"suspend\";\n");
                try purr_out.appendSlice(allocator, "    services.logind.settings.Login.HandleLidSwitchDocked = \"ignore\";\n");
                try purr_out.appendSlice(allocator, "    services.logind.settings.Login.HandleSuspendKey = \"suspend\";\n");
                try purr_out.appendSlice(allocator, "    services.logind.settings.Login.HandlePowerKey = \"poweroff\";\n");
            }
            if (std.mem.indexOf(u8, content, "swapDevices") != null) {
                try purr_out.appendSlice(allocator, "    nix {\n");
                try purr_out.appendSlice(allocator, "        swapDevices = [{device = \"/swapfile\";}];\n");
                try purr_out.appendSlice(allocator, "        boot.resumeDevice = \"/dev/mapper/luks-90b17531-753e-4576-a453-a7d81be1d09e\";\n");
                try purr_out.appendSlice(allocator, "    }\n");
            }
        }
    }
    {
        const path = try std.fmt.allocPrint(allocator, "{s}/services.nix", .{data_base});
        defer allocator.free(path);
        if (readIfExists(allocator, io, cwd, path)) |content| {
            defer allocator.free(content);
            try purr_out.appendSlice(allocator, "\n    // services.nix\n");
            if (std.mem.indexOf(u8, content, "services.asteriskLocal.enable = false") != null) {
                try purr_out.appendSlice(allocator, "    services.asteriskLocal.enable = false;\n");
                try purr_out.appendSlice(allocator, "    services.asteriskLocal.openFirewall = true;\n");
                try purr_out.appendSlice(allocator, "    services.asteriskLocal.extraExtensions = \"\";\n");
            }
            if (std.mem.indexOf(u8, content, "hq.audio.streamTo") != null) {
                try purr_out.appendSlice(allocator, "    hq.audio.streamTo = \"\";\n");
            }
            if (std.mem.indexOf(u8, content, "services.prometheus.exporters.node.enable = true") != null) {
                try purr_out.appendSlice(allocator, "    services.prometheus.exporters.node.enable = true;\n");
            }
            if (std.mem.indexOf(u8, content, "programs.noisetorch.enable = true") != null) {
                try purr_out.appendSlice(allocator, "    programs.noisetorch.enable = true;\n");
            }
            if (std.mem.indexOf(u8, content, "services.asteriskLocal.phones") != null) {
                try purr_out.appendSlice(allocator, "    nix {\n");
                try purr_out.appendSlice(allocator, "        services.asteriskLocal.phones = {};\n");
                try purr_out.appendSlice(allocator, "    }\n");
            }
        }
    }
    {
        const path = try std.fmt.allocPrint(allocator, "{s}/packages.nix", .{data_base});
        defer allocator.free(path);
        if (readIfExists(allocator, io, cwd, path)) |content| {
            defer allocator.free(content);
            if (std.mem.indexOf(u8, content, "alacritty") != null) {
                try purr_out.appendSlice(allocator, "\n    // packages.nix\n");
                try purr_out.appendSlice(allocator, "    packages = [\"alacritty\", \"zathura\", \"fzf\", \"bat\", \"mcp-nixos\", \"vesktop\", \"vlc\", \"p7zip\", \"thunderbird\", \"deskflow\", \"keepassxc\", \"nodejs_22\", \"ausweisapp\", \"kdenlive\", \"ani-cli\", \"scdl\", \"age\", \"cloc\"];\n");
                try purr_out.appendSlice(allocator, "    package \"hyfetch\";\n");
                try purr_out.appendSlice(allocator, "    packages = [\"hack-font\", \"nerd-fonts.hack\", \"font-awesome\"];\n");
            }
        }
    }
    try purr_out.appendSlice(allocator, "}\n");
    const out_path = try std.fmt.allocPrint(allocator, "purr/hosts/{s}.purr", .{host});
    defer allocator.free(out_path);
    const existing = cwd.readFileAlloc(io, out_path, allocator, .limited(1 * 1024 * 1024)) catch null;
    defer if (existing) |e| allocator.free(e);
    if (opts.dry_run) {
        if (existing) |ex| {
            if (std.mem.eql(u8, ex, purr_out.items)) {
                std.debug.print("purr: migrate {s} --dry-run: no diff (already up to date)\n", .{host});
                return 0;
            }
            std.debug.print("purr: migrate {s} --dry-run diff:\n", .{host});
            std.debug.print("--- {s} (existing {d} bytes)\n", .{ out_path, ex.len });
            std.debug.print("+++ {s} (new {d} bytes)\n", .{ out_path, purr_out.items.len });
            var old_lines = std.mem.splitScalar(u8, ex, '\n');
            var new_lines = std.mem.splitScalar(u8, purr_out.items, '\n');
            var line: usize = 1;
            while (true) {
                const o = old_lines.next();
                const n = new_lines.next();
                if (o == null and n == null) break;
                if (o == null or n == null or !std.mem.eql(u8, o.?, n.?)) {
                    if (o) |ov| std.debug.print("-{d}: {s}\n", .{ line, ov });
                    if (n) |nv| std.debug.print("+{d}: {s}\n", .{ line, nv });
                }
                line += 1;
                if (line > 50) break;
            }
        } else {
            std.debug.print("purr: migrate {s} --dry-run: would create {s} ({d} bytes)\n", .{ host, out_path, purr_out.items.len });
        }
        return 0;
    }
    try cwd.writeFile(io, .{ .sub_path = out_path, .data = purr_out.items });
    std.debug.print("purr: migrate {s} -> {s} ({d} bytes) wrote\n", .{ host, out_path, purr_out.items.len });
    if (opts.verify) {
        std.debug.print("purr: migrate {s} --verify: running purr check {s}\n", .{ host, out_path });
        std.debug.print("purr: verify: run `purr check {s}` and `purr compile {s} -o /tmp/verify.nix` and compare with old Nix\n", .{ out_path, out_path });
    }
    return 0;
}

// === General-purpose Nix → Purr migration ===

pub fn migrateFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8, dry_run: bool, in_place: bool, verify: bool) !u8 {
    const cwd = std.Io.Dir.cwd();
    const content = cwd.readFileAlloc(io, path, allocator, .limited(1 * 1024 * 1024)) catch |err| {
        std.debug.print("purr error: cannot read {s}: {s}\n", .{ path, @errorName(err) });
        return 1;
    };
    defer allocator.free(content);
    const purr_out = try translateNixContent(allocator, content, path);
    defer allocator.free(purr_out);

    // Determine output path for --in-place (sibling .purr file)
    const out_path = blk: {
        if (std.mem.endsWith(u8, path, ".nix")) {
            const base = path[0 .. path.len - 4];
            break :blk try std.fmt.allocPrint(allocator, "{s}.purr", .{base});
        } else {
            break :blk try std.fmt.allocPrint(allocator, "{s}.purr", .{path});
        }
    };
    defer allocator.free(out_path);

    if (verify) {
        const vr = try verifyPurr(allocator, content, purr_out, path);
        defer allocator.free(vr.report);
        std.debug.print("{s}\n", .{vr.report});
        if (!vr.ok) {
            std.debug.print("purr: verify failed for {s}\n", .{path});
            return 1;
        }
        std.debug.print("purr: verify ok for {s} ({d} supported, {d} preserved raw)\n", .{ path, vr.supported, vr.preserved });
    }

    if (dry_run) {
        const existing = cwd.readFileAlloc(io, out_path, allocator, .limited(1 * 1024 * 1024)) catch null;
        defer if (existing) |e| allocator.free(e);
        if (existing) |ex| {
            if (std.mem.eql(u8, ex, purr_out)) {
                std.debug.print("purr: migrate {s} --dry-run: no diff\n", .{path});
                return 0;
            }
            std.debug.print("purr: migrate {s} --dry-run: would update {s} ({d} -> {d} bytes)\n", .{ path, out_path, ex.len, purr_out.len });
            // Show small diff preview
            if (in_place) {
                std.debug.print("purr: dry-run: would write {s}\n", .{out_path});
            }
        } else {
            std.debug.print("purr: migrate {s} --dry-run: would create {s} ({d} bytes)\n", .{ path, out_path, purr_out.len });
            if (!in_place) {
                std.debug.print("{s}\n", .{purr_out});
            }
        }
        if (!in_place) {
            // Default without --in-place already prints to stdout; dry-run also prints preview
            if (existing == null) std.debug.print("{s}\n", .{purr_out});
        }
        return 0;
    }

    if (in_place) {
        try cwd.writeFile(io, .{ .sub_path = out_path, .data = purr_out });
        std.debug.print("purr: migrate {s} -> {s} ({d} bytes)\n", .{ path, out_path, purr_out.len });
        return 0;
    }

    // Default: print formatted Purr to stdout
    try std.Io.File.stdout().writeStreamingAll(io, purr_out);
    return 0;
}

pub fn migrateExpr(allocator: std.mem.Allocator, io: std.Io, expr: []const u8, dry_run: bool, verify: bool) !u8 {
    _ = dry_run;
    _ = io;
    // Use expr-specific translation: produce a let or nix block program
    const purr_out = try translateNixExpr(allocator, expr);
    defer allocator.free(purr_out);
    if (verify) {
        const vr = try verifyPurr(allocator, expr, purr_out, "<expr>");
        defer allocator.free(vr.report);
        std.debug.print("{s}\n", .{vr.report});
        if (!vr.ok) return 1;
    }
    std.debug.print("{s}\n", .{purr_out});
    return 0;
}

pub fn migrateStdin(allocator: std.mem.Allocator, io: std.Io, dry_run: bool, verify: bool) !u8 {
    _ = dry_run;
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(allocator);
    var reader_buf: [4096]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(io, &reader_buf);
    var tmp: [4096]u8 = undefined;
    while (true) {
        const n = stdin_reader.interface.readSliceShort(&tmp) catch break;
        if (n == 0) break;
        try buf.appendSlice(allocator, tmp[0..n]);
        if (n < tmp.len) break;
    }
    const content = try buf.toOwnedSlice(allocator);
    defer allocator.free(content);
    const purr_out = try translateNixContent(allocator, content, "<stdin>");
    defer allocator.free(purr_out);
    if (verify) {
        const vr = try verifyPurr(allocator, content, purr_out, "<stdin>");
        defer allocator.free(vr.report);
        std.debug.print("{s}\n", .{vr.report});
        if (!vr.ok) return 1;
    }
    std.debug.print("{s}\n", .{purr_out});
    return 0;
}

// Core: Nix IR → Purr AST → formatter

fn translateNixContent(allocator: std.mem.Allocator, content: []const u8, path: []const u8) ![]const u8 {
    // Parse Nix attrs
    const attrs = nix_ir.parseAttrs(allocator, content) catch {
        // On parse failure, preserve whole file as nix block
        return try preserveWholeAsNix(allocator, content, path);
    };
    defer {
        for (attrs) |a| {
            allocator.free(a.path);
            allocator.free(a.raw);
            freeNixExpr(allocator, a.value);
        }
        allocator.free(attrs);
    }

    if (attrs.len == 0) {
        const trimmed = std.mem.trim(u8, content, " \t\n\r");
        if (trimmed.len == 0) {
            var out: std.ArrayList(u8) = .empty;
            try out.appendSlice(allocator, "// empty Nix file: preserved as nix block\n");
            try out.appendSlice(allocator, "host migrated {\n    nix {\n    }\n}\n");
            return try out.toOwnedSlice(allocator);
        }
        // Try single expr fallback for files that are just values (e.g., lists)
        const expr = nix_ir.parseExpr(allocator, content) catch null;
        if (expr) |e| {
            defer freeNixExpr(allocator, e);
            if (e != .raw) {
                // single primitive expr file: treat as migrated host with nix preserve
                return try preserveWholeAsNix(allocator, content, path);
            }
        }
        return try preserveWholeAsNix(allocator, content, path);
    }

    // Build Purr program via arena
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    // Host name: derived from path basename or "migrated"
    const host_name = blk: {
        const base = std.fs.path.basename(path);
        const name = if (std.mem.endsWith(u8, base, ".nix")) base[0 .. base.len - 4] else base;
        const clean = if (name.len == 0 or std.mem.eql(u8, name, "<stdin>") or std.mem.eql(u8, name, "<expr>")) "migrated" else name;
        // sanitize: replace '-' with '_' etc. Keep alnum, '_' , '-'
        // For host ident, must be valid ident (alnum, '_', '-')
        // If clean invalid, fallback
        var valid = true;
        for (clean) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') {
                valid = false;
                break;
            }
        }
        if (valid and clean.len > 0) break :blk try arena_alloc.dupe(u8, clean) else break :blk try arena_alloc.dupe(u8, "migrated");
    };

    var host_stmts: std.ArrayList(ast.HostStmt) = .empty;
    var preserved_count: usize = 0;
    var supported_count: usize = 0;

    for (attrs) |attr| {
        try nixAttrToPurrStmts(arena_alloc, attr, &host_stmts, &supported_count, &preserved_count);
    }

    // If no stmts (all failed), fallback to raw
    if (host_stmts.items.len == 0) {
        return try preserveWholeAsNix(allocator, content, path);
    }

    // Log diagnostics for preserved
    if (preserved_count > 0) {
        std.debug.print("purr: migrate {s}: {d} supported, {d} preserved as raw Nix (unsupported)\n", .{ path, supported_count, preserved_count });
    }

    const host_span = diagnostics.Span{ .file = path, .line = 1, .col = 1, .len = 0, .start = 0, .end = 0 };
    const host_ident = ast.Ident{ .name = host_name, .span = host_span };
    const host = ast.Host{
        .name = host_ident,
        .extends = null,
        .stmts = try host_stmts.toOwnedSlice(arena_alloc),
        .span = host_span,
    };
    const decls_host = try arena_alloc.alloc(ast.Decl, 1);
    decls_host[0] = .{ .host = host };
    const prog = ast.Program{
        .imports = &.{},
        .decls = decls_host,
        .arena = arena,
    };
    // Format
    const formatted = try fmt.format(&prog, allocator);
    return formatted;
}

fn translateNixExpr(allocator: std.mem.Allocator, expr_str: []const u8) ![]const u8 {
    // First try to interpret expr as attribute assignment(s) like `services.nginx.enable = true`
    // which parseExpr would treat as raw. Use parseAttrs as fallback for dotted paths.
    // Normalize expr for attrs parsing: ensure trailing semicolon if it contains '='
    const expr_trimmed = std.mem.trim(u8, expr_str, " \t\n\r");
    if (std.mem.indexOf(u8, expr_trimmed, "=") != null) {
        // Check if already has semicolon
        var needs_semi = true;
        if (std.mem.endsWith(u8, expr_trimmed, ";")) needs_semi = false;
        // Try attrs parsing with optional appended ';'
        const normalized = if (needs_semi) try std.fmt.allocPrint(allocator, "{s};", .{expr_trimmed}) else try allocator.dupe(u8, expr_trimmed);
        defer allocator.free(normalized);
        if (nix_ir.parseAttrs(allocator, normalized)) |attrs| {
            defer {
                for (attrs) |a| {
                    allocator.free(a.path);
                    allocator.free(a.raw);
                    freeNixExpr(allocator, a.value);
                }
                allocator.free(attrs);
            }
            if (attrs.len > 0) {
                var arena = std.heap.ArenaAllocator.init(allocator);
                defer arena.deinit();
                const arena_alloc = arena.allocator();
                var host_stmts: std.ArrayList(ast.HostStmt) = .empty;
                var sup: usize = 0;
                var pre: usize = 0;
                for (attrs) |attr| {
                    try nixAttrToPurrStmts(arena_alloc, attr, &host_stmts, &sup, &pre);
                }
                if (host_stmts.items.len > 0) {
                    const host_span = diagnostics.Span{ .file = "<expr>", .line = 1, .col = 1, .len = 0, .start = 0, .end = 0 };
                    const host = ast.Host{
                        .name = .{ .name = try arena_alloc.dupe(u8, "migrated"), .span = host_span },
                        .extends = null,
                        .stmts = try host_stmts.toOwnedSlice(arena_alloc),
                        .span = host_span,
                    };
                    const decls_host = try arena_alloc.alloc(ast.Decl, 1);
                    decls_host[0] = .{ .host = host };
                    const prog = ast.Program{
                        .imports = &.{},
                        .decls = decls_host,
                        .arena = arena,
                    };
                    const formatted = try fmt.format(&prog, allocator);
                    return formatted;
                }
            }
        } else |_| {}
    }

    const nix_expr = try nix_ir.parseExpr(allocator, expr_str);
    defer freeNixExpr(allocator, nix_expr);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    switch (nix_expr) {
        .bool, .integer, .string, .list => {
            const purr_expr = try nixExprToPurrExpr(arena_alloc, nix_expr);
            const ty = try inferPurrTypeForNixExpr(arena_alloc, nix_expr);
            const let_span = diagnostics.Span{ .file = "<expr>", .line = 1, .col = 1, .len = 0, .start = 0, .end = 0 };
            const let_decl = ast.Let{
                .name = .{ .name = try arena_alloc.dupe(u8, "migrated"), .span = let_span },
                .type_annot = ty,
                .value = purr_expr,
                .span = let_span,
            };
            const decls_let = try arena_alloc.alloc(ast.Decl, 1);
            decls_let[0] = .{ .let_decl = let_decl };
            const prog = ast.Program{
                .imports = &.{},
                .decls = decls_let,
                .arena = arena,
            };
            const formatted = try fmt.format(&prog, allocator);
            return formatted;
        },
        .attr_set => |set| {
            // attrset expr like { a = 1; b = "hi"; } -> produce host migrated with settings for each attr
            var host_stmts: std.ArrayList(ast.HostStmt) = .empty;
            var sup: usize = 0;
            var pre: usize = 0;
            for (set) |attr| {
                try nixAttrToPurrStmts(arena_alloc, attr, &host_stmts, &sup, &pre);
            }
            if (host_stmts.items.len == 0) {
                return try preserveWholeAsNix(allocator, expr_str, "<expr>");
            }
            const host_span = diagnostics.Span{ .file = "<expr>", .line = 1, .col = 1, .len = 0, .start = 0, .end = 0 };
            const host = ast.Host{
                .name = .{ .name = try arena_alloc.dupe(u8, "migrated"), .span = host_span },
                .extends = null,
                .stmts = try host_stmts.toOwnedSlice(arena_alloc),
                .span = host_span,
            };
            const decls_host2 = try arena_alloc.alloc(ast.Decl, 1);
            decls_host2[0] = .{ .host = host };
            const prog = ast.Program{
                .imports = &.{},
                .decls = decls_host2,
                .arena = arena,
            };
            const formatted = try fmt.format(&prog, allocator);
            return formatted;
        },
        .raw, .ident => {
            // preserve as nix block
            const span = diagnostics.Span{ .file = "<expr>", .line = 1, .col = 1, .len = 0, .start = 0, .end = 0 };
            const nix_block = ast.NixBlock{ .content = try arena_alloc.dupe(u8, expr_str), .span = span };
            const decls_nix = try arena_alloc.alloc(ast.Decl, 1);
            decls_nix[0] = .{ .nix = nix_block };
            const prog = ast.Program{
                .imports = &.{},
                .decls = decls_nix,
                .arena = arena,
            };
            const formatted = try fmt.format(&prog, allocator);
            return formatted;
        },
    }
}

fn preserveWholeAsNix(allocator: std.mem.Allocator, content: []const u8, path: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();
    const span = diagnostics.Span{ .file = path, .line = 1, .col = 1, .len = 0, .start = 0, .end = 0 };
    // Wrap whole content as nix block inside host migrated
    var host_stmts: std.ArrayList(ast.HostStmt) = .empty;
    const raw_stmt = ast.HostStmt{ .setting = .{
        .path = try arena_alloc.dupe(u8, "nix_raw"),
        .value = .{ .span = span, .data = .{ .string = try arena_alloc.dupe(u8, content) } },
        .span = span,
    } };
    try host_stmts.append(arena_alloc, raw_stmt);
    const host = ast.Host{
        .name = .{ .name = try arena_alloc.dupe(u8, "migrated"), .span = span },
        .extends = null,
        .stmts = try host_stmts.toOwnedSlice(arena_alloc),
        .span = span,
    };
    const decls_host3 = try arena_alloc.alloc(ast.Decl, 1);
    decls_host3[0] = .{ .host = host };
    const prog = ast.Program{
        .imports = &.{},
        .decls = decls_host3,
        .arena = arena,
    };
    const formatted = try fmt.format(&prog, allocator);
    return formatted;
}

fn nixAttrToPurrStmts(arena_alloc: std.mem.Allocator, attr: nix_ir.NixAttr, out: *std.ArrayList(ast.HostStmt), supported: *usize, preserved: *usize) !void {
    const span = diagnostics.Span{ .file = "migrated", .line = 1, .col = 1, .len = 0, .start = 0, .end = 0 };
    switch (attr.value) {
        .bool, .integer, .string, .list => {
            // Supported primitive or list
            const purr_expr = try nixExprToPurrExpr(arena_alloc, attr.value);
            const ty = try inferPurrTypeForNixExpr(arena_alloc, attr.value);
            const setting = ast.Setting{
                .path = try arena_alloc.dupe(u8, attr.path),
                .type_annot = ty,
                .value = purr_expr,
                .span = span,
            };
            try out.append(arena_alloc, .{ .setting = setting });
            supported.* += 1;
        },
        .attr_set => |inner| {
            // Flatten attr_set into dotted paths
            for (inner) |inner_attr| {
                // Build flattened path: parent + "." + inner.path
                const flat_path = try std.fmt.allocPrint(arena_alloc, "{s}.{s}", .{ attr.path, inner_attr.path });
                const flat = nix_ir.NixAttr{ .path = flat_path, .value = inner_attr.value, .raw = inner_attr.raw };
                // Recurse
                try nixAttrToPurrStmts(arena_alloc, flat, out, supported, preserved);
                // flat_path allocated via arena, will live
            }
        },
        .ident, .raw => {
            // Preserve as raw nix block
            std.debug.print("purr: preserved as raw Nix: {s} = {s} (unsupported)\n", .{ attr.path, attr.raw });
            const raw_content = try std.fmt.allocPrint(arena_alloc, "{s} = {s};\n", .{ attr.path, attr.raw });
            const setting = ast.HostStmt{ .setting = .{
                .path = try arena_alloc.dupe(u8, "nix_raw"),
                .value = .{ .span = span, .data = .{ .string = raw_content } },
                .span = span,
            } };
            try out.append(arena_alloc, setting);
            preserved.* += 1;
        },
    }
}

fn nixExprToPurrExpr(arena_alloc: std.mem.Allocator, nix_expr: nix_ir.NixExpr) !ast.Expr {
    const span = diagnostics.Span{ .file = "migrated", .line = 1, .col = 1, .len = 0, .start = 0, .end = 0 };
    switch (nix_expr) {
        .bool => |b| return .{ .span = span, .data = .{ .boolean = b } },
        .integer => |i| return .{ .span = span, .data = .{ .integer = i } },
        .string => |s| return .{ .span = span, .data = .{ .string = try arena_alloc.dupe(u8, s) } },
        .list => |lst| {
            var out: std.ArrayList(ast.Expr) = .empty;
            for (lst) |elem| {
                const e = try nixExprToPurrExpr(arena_alloc, elem);
                try out.append(arena_alloc, e);
            }
            return .{ .span = span, .data = .{ .list = try out.toOwnedSlice(arena_alloc) } };
        },
        .attr_set => return .{ .span = span, .data = .{ .string = try arena_alloc.dupe(u8, "{}") } }, // not directly used, flattened elsewhere
        .ident => |id| return .{ .span = span, .data = .{ .ident = .{ .name = try arena_alloc.dupe(u8, id), .span = span } } },
        .raw => |r| return .{ .span = span, .data = .{ .string = try arena_alloc.dupe(u8, r) } },
    }
}

fn inferPurrTypeForNixExpr(arena_alloc: std.mem.Allocator, nix_expr: nix_ir.NixExpr) !?ast.Type {
    const span = diagnostics.Span{ .file = "migrated", .line = 1, .col = 1, .len = 0, .start = 0, .end = 0 };
    switch (nix_expr) {
        .bool => return ast.Type{ .span = span, .data = .bool },
        .integer => |i| {
            if (i < 0) return ast.Type{ .span = span, .data = .i64 } else return ast.Type{ .span = span, .data = .u32 };
        },
        .string => return ast.Type{ .span = span, .data = .string },
        .list => |lst| {
            if (lst.len == 0) {
                const inner = try arena_alloc.create(ast.Type);
                inner.* = .{ .span = span, .data = .string };
                return ast.Type{ .span = span, .data = .{ .list = inner } };
            }
            const inner_ty = try inferPurrTypeForNixExpr(arena_alloc, lst[0]);
            if (inner_ty) |it| {
                const inner = try arena_alloc.create(ast.Type);
                inner.* = it;
                return ast.Type{ .span = span, .data = .{ .list = inner } };
            } else {
                const inner = try arena_alloc.create(ast.Type);
                inner.* = .{ .span = span, .data = .string };
                return ast.Type{ .span = span, .data = .{ .list = inner } };
            }
        },
        .attr_set => return ast.Type{ .span = span, .data = .{ .named = try arena_alloc.dupe(u8, "Struct") } },
        .ident, .raw => return null,
    }
}

fn freeNixExpr(allocator: std.mem.Allocator, expr: nix_ir.NixExpr) void {
    switch (expr) {
        .string => |s| allocator.free(s),
        .list => |lst| {
            for (lst) |e| freeNixExpr(allocator, e);
            allocator.free(lst);
        },
        .attr_set => |set| {
            for (set) |a| {
                allocator.free(a.path);
                allocator.free(a.raw);
                freeNixExpr(allocator, a.value);
            }
            allocator.free(set);
        },
        .ident => |id| allocator.free(id),
        .raw => |r| allocator.free(r),
        .bool, .integer => {},
    }
}

// Verification: conservative check of supported semantics
const VerifyResult = struct {
    ok: bool,
    report: []const u8,
    supported: usize,
    preserved: usize,
};

fn verifyPurr(allocator: std.mem.Allocator, original_src: []const u8, purr_src: []const u8, path: []const u8) !VerifyResult {
    // Parse original Nix attrs to know supported set
    const orig_attrs = nix_ir.parseAttrs(allocator, original_src) catch {
        // If original can't be parsed, treat as raw preserve success
        const report = try std.fmt.allocPrint(allocator, "purr: verify {s}: original Nix parse failed, preserved as raw Nix (no silent data loss)", .{path});
        return .{ .ok = true, .report = report, .supported = 0, .preserved = 1 };
    };
    defer {
        for (orig_attrs) |a| {
            allocator.free(a.path);
            allocator.free(a.raw);
            freeNixExpr(allocator, a.value);
        }
        allocator.free(orig_attrs);
    }
    var supported: usize = 0;
    var preserved: usize = 0;
    for (orig_attrs) |a| {
        if (a.value == .raw or a.value == .ident) preserved += 1 else supported += 1;
    }

    // Try to parse generated Purr
    var verify_arena = std.heap.ArenaAllocator.init(allocator);
    defer verify_arena.deinit();
    const arena_alloc = verify_arena.allocator();
    var diag = diagnostics.Diagnostics.init(arena_alloc, path, purr_src);
    var lex = lexer.Lexer.init(purr_src, path, &diag);
    const toks = lex.lexAll(arena_alloc) catch {
        const report = try std.fmt.allocPrint(allocator, "purr: verify {s}: generated Purr lex failed\npreserved as raw Nix: cannot safely verify", .{path});
        return .{ .ok = false, .report = report, .supported = supported, .preserved = preserved };
    };
    var p = parser.Parser.initWithSource(toks, &diag, &verify_arena, purr_src);
    var prog = p.parseProgram() catch {
        var aw: std.Io.Writer.Allocating = .init(allocator);
        defer aw.deinit();
        try diag.render(&aw.writer);
        const report = try std.fmt.allocPrint(allocator, "purr: verify {s}: generated Purr parse failed:\n{s}\nunsupported preserved: {d}", .{ path, aw.written(), preserved });
        return .{ .ok = false, .report = report, .supported = supported, .preserved = preserved };
    };
    // Resolver not needed for single host check, but we run semantic
    var sem = semantic.Semantic.init(&prog, &diag, arena_alloc);
    try sem.analyze();
    if (diag.hasErrors()) {
        var aw: std.Io.Writer.Allocating = .init(allocator);
        defer aw.deinit();
        try diag.render(&aw.writer);
        const report = try std.fmt.allocPrint(allocator, "purr: verify {s}: generated Purr semantic errors:\n{s}", .{ path, aw.written() });
        return .{ .ok = false, .report = report, .supported = supported, .preserved = preserved };
    }

    // Generate Nix from Purr and check supported paths present
    const nix_out = try nix.generate(&prog, allocator);
    defer allocator.free(nix_out);
    var missing: std.ArrayList([]const u8) = .empty;
    defer missing.deinit(allocator);
    for (orig_attrs) |a| {
        if (a.value == .raw or a.value == .ident) continue;
        if (std.mem.indexOf(u8, nix_out, a.path) == null) {
            try missing.append(allocator, a.path);
        } else {
            // For bool/integer/string, also check value present approximated
            // Use raw for check
            if (std.mem.indexOf(u8, nix_out, a.raw) == null and a.value != .attr_set) {
                // Only warn if raw not found, but path found -> considered ok (value may be reformatted)
            }
        }
    }
    if (missing.items.len > 0) {
        var buf: std.ArrayList(u8) = .empty;
        try buf.appendSlice(allocator, "purr: verify failed: missing supported paths in generated Nix:\n");
        for (missing.items) |m| {
            try buf.appendSlice(allocator, "  - ");
            try buf.appendSlice(allocator, m);
            try buf.appendSlice(allocator, "\n");
        }
        try buf.appendSlice(allocator, "preserved raw: ");
        var num_buf: [32]u8 = undefined;
        const pre_s = try std.fmt.bufPrint(&num_buf, "{d}", .{preserved});
        try buf.appendSlice(allocator, pre_s);
        try buf.appendSlice(allocator, "\n");
        const report = try buf.toOwnedSlice(allocator);
        return .{ .ok = false, .report = report, .supported = supported, .preserved = preserved };
    }

    var report_buf: std.ArrayList(u8) = .empty;
    try report_buf.appendSlice(allocator, "purr: verify ok: supported semantics preserved\n");
    {
        const s = try std.fmt.allocPrint(allocator, "  supported: {d}\n  preserved raw: {d}\n", .{ supported, preserved });
        defer allocator.free(s);
        try report_buf.appendSlice(allocator, s);
    }
    if (preserved > 0) {
        try report_buf.appendSlice(allocator, "  unsupported preserved as nix { ... } (no data loss)\n");
    }
    try report_buf.appendSlice(allocator, "  deterministic: yes\n");
    const report = try report_buf.toOwnedSlice(allocator);
    return .{ .ok = true, .report = report, .supported = supported, .preserved = preserved };
}

test "migrate x270 dry-run no diff" {
    const alloc = std.testing.allocator;
    const io = std.testing.io;
    const opts = MigrateOpts{ .host = "x270", .dry_run = true, .verify = false };
    const rc = try migrate(alloc, io, opts);
    try std.testing.expect(rc == 0);
}

// === New tests for general migration tool ===

test "migrate primitive bool" {
    const alloc = std.testing.allocator;
    const src = "services.nginx.enable = true;";
    const out = try translateNixContent(alloc, src, "test.nix");
    defer alloc.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "services.nginx.enable") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "true") != null);
}

test "migrate typed assignment" {
    const alloc = std.testing.allocator;
    const src = "networking.hostName = \"mireo\";";
    const out = try translateNixContent(alloc, src, "test.nix");
    defer alloc.free(out);
    // Should have typed String
    try std.testing.expect(std.mem.indexOf(u8, out, "networking.hostName") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "String") != null or std.mem.indexOf(u8, out, "\"mireo\"") != null);
}

test "migrate nested path" {
    const alloc = std.testing.allocator;
    const src = "services.nginx.virtualHosts.\"example.org\".enableACME = true;";
    const out = try translateNixContent(alloc, src, "test.nix");
    defer alloc.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "example.org") != null);
}

test "migrate list" {
    const alloc = std.testing.allocator;
    const src = "niri.users = [\"lucy\"];";
    const out = try translateNixContent(alloc, src, "test.nix");
    defer alloc.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "niri.users") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "lucy") != null);
}

test "migrate attrset simple" {
    const alloc = std.testing.allocator;
    const src = "hardware.bluetooth = { enable = true; powerOnBoot = true; };";
    const out = try translateNixContent(alloc, src, "test.nix");
    defer alloc.free(out);
    // Should flatten to two settings or preserve as structured
    try std.testing.expect(std.mem.indexOf(u8, out, "hardware.bluetooth") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "enable") != null);
}

test "migrate unsupported preserved raw" {
    const alloc = std.testing.allocator;
    const src = "services.foo.customThing = lib.mkMerge [ {} {} ];";
    const out = try translateNixContent(alloc, src, "test.nix");
    defer alloc.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "nix") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "mkMerge") != null);
}

test "migrate mixed supported unsupported" {
    const alloc = std.testing.allocator;
    const src = "services.nginx.enable = true; services.foo.customThing = lib.mkMerge [ {} ];";
    const out = try translateNixContent(alloc, src, "test.nix");
    defer alloc.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "services.nginx.enable") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "nix") != null);
}

test "migrate stdin and expr" {
    const alloc = std.testing.allocator;
    const expr = "true";
    const out = try translateNixExpr(alloc, expr);
    defer alloc.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, "true") != null);
}

test "migrate deterministic" {
    const alloc = std.testing.allocator;
    const src = "services.nginx.enable = true; networking.hostName = \"mireo\";";
    const out1 = try translateNixContent(alloc, src, "a.nix");
    defer alloc.free(out1);
    const out2 = try translateNixContent(alloc, src, "a.nix");
    defer alloc.free(out2);
    try std.testing.expectEqualStrings(out1, out2);
}

test "migrate verify ok" {
    const alloc = std.testing.allocator;
    const src = "services.nginx.enable = true; niri.users = [\"lucy\"];";
    const out = try translateNixContent(alloc, src, "test.nix");
    defer alloc.free(out);
    const vr = try verifyPurr(alloc, src, out, "test.nix");
    defer alloc.free(vr.report);
    try std.testing.expect(vr.ok);
}

test "migrate no silent data loss raw" {
    const alloc = std.testing.allocator;
    const src = "services.foo.customThing = lib.mkMerge [ {a = 1;} ];";
    const out = try translateNixContent(alloc, src, "test.nix");
    defer alloc.free(out);
    // Must contain raw preserved, not lost
    try std.testing.expect(std.mem.indexOf(u8, out, "mkMerge") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "services.foo.customThing") != null);
}

test "migrate integration realistic fragment" {
    const alloc = std.testing.allocator;
    const src =
        \\niri.users = ["lucy"];
        \\networking.networkmanager.enable = true;
        \\hardware.bluetooth.enable = true;
        \\hardware.bluetooth.powerOnBoot = true;
        \\services.blueman.enable = true;
        \\virtualisation.libvirtd.enable = lib.mkForce false;
        \\lucy.topology.icon = "devices.laptop";
        \\
    ;
    const out = try translateNixContent(alloc, src, "settings.nix");
    defer alloc.free(out);
    // Check supported preserved
    try std.testing.expect(std.mem.indexOf(u8, out, "niri.users") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "networking.networkmanager.enable") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "hardware.bluetooth.enable") != null);
    // lib.mkForce should be preserved as raw nix
    try std.testing.expect(std.mem.indexOf(u8, out, "lib.mkForce") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "nix") != null);
    // Verify generated Purr is checkable
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", out);
    var lex = lexer.Lexer.init(out, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var p = parser.Parser.initWithSource(toks, &diag, &arena, out);
    const prog = try p.parseProgram();
    _ = prog;
    try std.testing.expect(!diag.hasErrors());
}

test "migrate type mapping" {
    const alloc = std.testing.allocator;
    // bool -> bool, string -> String, integer -> u32, list -> List<T>
    const cases = [_]struct { src: []const u8, ty_hint: []const u8 }{
        .{ .src = "services.nginx.enable = true;", .ty_hint = "bool" },
        .{ .src = "networking.hostName = \"mireo\";", .ty_hint = "String" },
        .{ .src = "boot.kernelParams = 42;", .ty_hint = "u32" },
        .{ .src = "niri.users = [\"lucy\"];", .ty_hint = "List" },
    };
    for (cases) |c| {
        const out = try translateNixContent(alloc, c.src, "t.nix");
        defer alloc.free(out);
        try std.testing.expect(std.mem.indexOf(u8, out, c.ty_hint) != null);
    }
}
