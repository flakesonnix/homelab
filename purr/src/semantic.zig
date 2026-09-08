const std = @import("std");
const ast = @import("ast.zig");
const diagnostics = @import("diagnostics.zig");
const symbol = @import("symbol.zig");

pub const Semantic = struct {
    program: *const ast.Program,
    diag: *diagnostics.Diagnostics,
    allocator: std.mem.Allocator,

    // known roles for suggestions; in real use would be from data/roles
    known_roles: []const []const u8,
    known_presets: []const []const u8,
    known_bundles: []const []const u8,

    pub fn init(program: *const ast.Program, diag: *diagnostics.Diagnostics, allocator: std.mem.Allocator) Semantic {
        return .{
            .program = program,
            .diag = diag,
            .allocator = allocator,
            .known_roles = &.{ "core", "desktop", "dev", "gaming", "llm" },
            .known_presets = &.{ "gaming-base", "gaming-performance", "gaming-steam" },
            .known_bundles = &.{ "core", "desktop", "dev" },
        };
    }

    pub fn analyze(self: *Semantic) !void {
        // Phase 8.1: use symbol.Scope for module-level declarations
        const mod_scope = try symbol.Scope.init(self.allocator, .module, null);
        defer mod_scope.deinit();

        // Scope for let bindings sequential (for forward ref checks) - kept separate for ordered semantics
        var ordered_let_scope = std.StringHashMap(diagnostics.Span).init(self.allocator);
        defer ordered_let_scope.deinit();

        // first pass: collect declarations, detect duplicates via Scope
        for (self.program.decls) |decl| {
            switch (decl) {
                .role => |r| {
                    if (try mod_scope.define(r.name.name, .role, r.name.span)) |prev| {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .duplicate_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "duplicate role `{s}`", .{r.name.name}),
                            .span = r.name.span,
                            .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.span.file, prev.span.line, prev.span.col }),
                        });
                    }
                },
                .host => |h| {
                    if (try mod_scope.define(h.name.name, .host, h.name.span)) |prev| {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .duplicate_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "duplicate host `{s}`", .{h.name.name}),
                            .span = h.name.span,
                            .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.span.file, prev.span.line, prev.span.col }),
                        });
                    }
                },
                .bundle => |b| {
                    if (try mod_scope.define(b.name.name, .bundle, b.name.span)) |prev| {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .duplicate_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "duplicate bundle `{s}`", .{b.name.name}),
                            .span = b.name.span,
                            .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.span.file, prev.span.line, prev.span.col }),
                        });
                    }
                },
                .preset => |p| {
                    if (try mod_scope.define(p.name.name, .preset, p.name.span)) |prev| {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .duplicate_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "duplicate preset `{s}`", .{p.name.name}),
                            .span = p.name.span,
                            .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.span.file, prev.span.line, prev.span.col }),
                        });
                    }
                },
                .let_decl => |l| {
                    if (try mod_scope.define(l.name.name, .let_decl, l.name.span)) |prev| {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .duplicate_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "duplicate let `{s}`", .{l.name.name}),
                            .span = l.name.span,
                            .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.span.file, prev.span.line, prev.span.col }),
                        });
                    }
                },
                .microvm => |vm| {
                    if (try mod_scope.define(vm.name.name, .microvm, vm.name.span)) |prev| {
                        try self.diag.push(.{
                            .severity = .err,
                            .code = .duplicate_decl,
                            .message = try std.fmt.allocPrint(self.allocator, "duplicate microvm `{s}`", .{vm.name.name}),
                            .span = vm.name.span,
                            .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.span.file, prev.span.line, prev.span.col }),
                        });
                    }
                },
                else => {},
            }
        }

        // second pass: validate references (including let scope) - sequential via ordered_let_scope + mod_scope lookups
        var ordered_scope = std.StringHashMap(diagnostics.Span).init(self.allocator);
        defer ordered_scope.deinit();
        for (self.program.decls) |decl| {
            switch (decl) {
                .let_decl => |l| {
                    try self.checkExpr(l.value, &ordered_scope);
                    if (l.type_annot) |ty| {
                        if (!self.typeMatchesExpr(ty, l.value)) {
                            try self.diag.push(.{
                                .severity = .err,
                                .code = .type_mismatch,
                                .message = try std.fmt.allocPrint(self.allocator, "let `{s}` type mismatch", .{l.name.name}),
                                .span = l.name.span,
                                .help = try std.fmt.allocPrint(self.allocator, "expected {s}, got {s}", .{ self.typeToString(ty), self.exprTypeName(l.value) }),
                            });
                        }
                    } else {
                        // 8.4a: infer type for let without annotation (no diagnostic, just ensure inference works)
                        _ = try self.inferExprType(l.value);
                    }
                    if (!ordered_scope.contains(l.name.name)) try ordered_scope.put(l.name.name, l.name.span);
                    // also track in ordered_let_scope for host inheritance? Not needed
                    if (!ordered_let_scope.contains(l.name.name)) try ordered_let_scope.put(l.name.name, l.name.span);
                },
                .role => |r| {
                    if (r.host) |hb| {
                        for (hb.presets) |pname| {
                            const found = blk: {
                                for (self.known_presets) |k| if (std.mem.eql(u8, k, pname)) break :blk true;
                                if (mod_scope.lookup(pname, .preset) != null) break :blk true;
                                break :blk false;
                            };
                            if (!found) {
                                try self.diag.push(.{
                                    .severity = .err,
                                    .code = .unknown_preset,
                                    .message = try std.fmt.allocPrint(self.allocator, "unknown preset `{s}` in role `{s}`", .{ pname, r.name.name }),
                                    .span = hb.span,
                                    .help = "available presets: gaming-base, gaming-performance, gaming-steam",
                                });
                            }
                        }
                    }
                    if (r.home) |hb| {
                        for (hb.bundles) |bname| {
                            const found = blk: {
                                for (self.known_bundles) |k| if (std.mem.eql(u8, k, bname)) break :blk true;
                                if (mod_scope.lookup(bname, .bundle) != null) break :blk true;
                                break :blk false;
                            };
                            if (!found) {
                                var help: ?[]const u8 = null;
                                var cands: std.ArrayList([]const u8) = .empty;
                                for (self.known_bundles) |k| try cands.append(self.allocator, k);
                                const bundle_syms = try mod_scope.collectKind(.bundle, self.allocator);
                                defer self.allocator.free(bundle_syms);
                                for (bundle_syms) |s| try cands.append(self.allocator, s);
                                if (try diagnostics.Diagnostics.suggest(bname, cands.items, self.allocator)) |s| help = s;
                                if (help == null) {
                                    const avail = try std.mem.join(self.allocator, ", ", self.known_bundles);
                                    help = try std.fmt.allocPrint(self.allocator, "available bundles: {s}", .{avail});
                                }
                                try self.diag.push(.{
                                    .severity = .err,
                                    .code = .unknown_bundle,
                                    .message = try std.fmt.allocPrint(self.allocator, "unknown bundle `{s}` in role `{s}`", .{ bname, r.name.name }),
                                    .span = hb.span,
                                    .help = help,
                                });
                            }
                        }
                    }
                },
                .host => |h| {
                    // Build host-local scope: parent is mod_scope, plus ordered lets before this host
                    // For simplicity, create temporary host scope that can see module lets via parent
                    const host_scope_sym = try symbol.Scope.init(self.allocator, .host, mod_scope);
                    // host_scope owned by mod_scope, not deferred individually (mod_scope.deinit will clean children)
                    // Import ordered lets into host scope via define (shadowing allowed)
                    var scope_it = ordered_scope.keyIterator();
                    while (scope_it.next()) |k| {
                        // define in host_scope if not already? Use direct put without duplicate check for now
                        _ = try host_scope_sym.define(k.*, .let_decl, ordered_scope.get(k.*).?);
                    }
                    // Track microVM names for duplicate within host
                    var microvm_names = std.StringHashMap(diagnostics.Span).init(self.allocator);
                    defer microvm_names.deinit();
                    for (h.stmts) |stmt| {
                        switch (stmt) {
                            .let_decl => |l| {
                                if (host_scope_sym.lookupLocal(l.name.name, .let_decl) != null) {
                                    const prev = host_scope_sym.lookupLocal(l.name.name, .let_decl).?;
                                    try self.diag.push(.{
                                        .severity = .err,
                                        .code = .duplicate_decl,
                                        .message = try std.fmt.allocPrint(self.allocator, "duplicate let `{s}` in host `{s}`", .{ l.name.name, h.name.name }),
                                        .span = l.name.span,
                                        .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.span.file, prev.span.line, prev.span.col }),
                                    });
                                } else {
                                    try self.checkExpr(l.value, &ordered_scope);
                                    if (l.type_annot) |ty| {
                                        if (!self.typeMatchesExpr(ty, l.value)) {
                                            try self.diag.push(.{
                                                .severity = .err,
                                                .code = .type_mismatch,
                                                .message = try std.fmt.allocPrint(self.allocator, "let `{s}` type mismatch in host `{s}`", .{ l.name.name, h.name.name }),
                                                .span = l.name.span,
                                                .help = try std.fmt.allocPrint(self.allocator, "expected {s}, got {s}", .{ self.typeToString(ty), self.exprTypeName(l.value) }),
                                            });
                                        }
                                    } else {
                                        _ = try self.inferExprType(l.value);
                                    }
                                    _ = try host_scope_sym.define(l.name.name, .let_decl, l.name.span);
                                    try ordered_scope.put(l.name.name, l.name.span);
                                }
                            },
                            .use_role => |ident| {
                                const in_declared = mod_scope.lookup(ident.name, .role) != null;
                                var in_known = false;
                                for (self.known_roles) |k| {
                                    if (std.mem.eql(u8, k, ident.name)) in_known = true;
                                }
                                if (!in_declared and !in_known) {
                                    var help: ?[]const u8 = null;
                                    var candidates: std.ArrayList([]const u8) = .empty;
                                    for (self.known_roles) |k| try candidates.append(self.allocator, k);
                                    const role_syms = try mod_scope.collectKind(.role, self.allocator);
                                    defer self.allocator.free(role_syms);
                                    for (role_syms) |s| try candidates.append(self.allocator, s);
                                    if (try diagnostics.Diagnostics.suggest(ident.name, candidates.items, self.allocator)) |s| {
                                        help = s;
                                    }
                                    const msg = try std.fmt.allocPrint(self.allocator, "unknown role `{s}`", .{ident.name});
                                    if (help == null) {
                                        const avail = try std.mem.join(self.allocator, ", ", self.known_roles);
                                        help = try std.fmt.allocPrint(self.allocator, "available roles: {s}", .{avail});
                                    }
                                    try self.diag.push(.{
                                        .severity = .err,
                                        .code = .unknown_role,
                                        .message = msg,
                                        .span = ident.span,
                                        .help = help,
                                    });
                                }
                            },
                            .preset => |ident| {
                                const found = blk: {
                                    for (self.known_presets) |p| if (std.mem.eql(u8, p, ident.name)) break :blk true;
                                    if (mod_scope.lookup(ident.name, .preset) != null) break :blk true;
                                    break :blk false;
                                };
                                if (!found) {
                                    try self.diag.push(.{
                                        .severity = .err,
                                        .code = .unknown_preset,
                                        .message = try std.fmt.allocPrint(self.allocator, "unknown preset `{s}`", .{ident.name}),
                                        .span = ident.span,
                                        .help = "available presets: gaming-base, gaming-performance, gaming-steam",
                                    });
                                }
                            },
                            .setting => |s| {
                                // For setting values, need to check expr against host let scope
                                // Build a temporary map for checkExpr from host_scope's let symbols
                                var tmp_map = std.StringHashMap(diagnostics.Span).init(self.allocator);
                                defer tmp_map.deinit();
                                // Populate with host_scope let symbols (including parent)
                                // Simple: use ordered_scope as before plus host local
                                var it = ordered_scope.keyIterator();
                                while (it.next()) |k| try tmp_map.put(k.*, ordered_scope.get(k.*).?);
                                // Add host local lets that are not yet in ordered_scope? Already in host_scope_sym but not in ordered_scope unless defined earlier
                                // For now, just use ordered_scope + host let just defined? We already handled let above.
                                try self.checkExpr(s.value, &tmp_map);
                            },
                            .package => {},
                            .packages_assign => {},
                            .import => {},
                            .microvm => |vm| {
                                if (microvm_names.get(vm.name.name)) |prev| {
                                    try self.diag.push(.{
                                        .severity = .err,
                                        .code = .duplicate_decl,
                                        .message = try std.fmt.allocPrint(self.allocator, "duplicate microvm `{s}` in host `{s}`", .{ vm.name.name, h.name.name }),
                                        .span = vm.name.span,
                                        .help = try std.fmt.allocPrint(self.allocator, "previous at {s}:{d}:{d}", .{ prev.file, prev.line, prev.col }),
                                    });
                                } else {
                                    try microvm_names.put(vm.name.name, vm.name.span);
                                }
                                if (vm.mem) |m| {
                                    if (m <= 0) {
                                        try self.diag.push(.{
                                            .severity = .err,
                                            .code = .invalid_microvm,
                                            .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` mem must be positive", .{vm.name.name}),
                                            .span = vm.name.span,
                                            .help = "example: mem = 512;",
                                        });
                                    }
                                    if (m > 65536) {
                                        try self.diag.push(.{
                                            .severity = .err,
                                            .code = .invalid_microvm,
                                            .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` mem too large", .{vm.name.name}),
                                            .span = vm.name.span,
                                            .help = "max 65536 MiB",
                                        });
                                    }
                                }
                                if (vm.cpu) |c| {
                                    if (c <= 0) {
                                        try self.diag.push(.{
                                            .severity = .err,
                                            .code = .invalid_microvm,
                                            .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` cpu must be positive", .{vm.name.name}),
                                            .span = vm.name.span,
                                            .help = "example: cpu = 1;",
                                        });
                                    }
                                }
                                if (vm.net) |n| {
                                    if (n.len == 0) {
                                        try self.diag.push(.{
                                            .severity = .err,
                                            .code = .invalid_microvm,
                                            .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` net must be non-empty", .{vm.name.name}),
                                            .span = vm.name.span,
                                            .help = "example: net = \"lan\";",
                                        });
                                    }
                                }
                                if (vm.ip) |ip| {
                                    if (!isValidIpv4(ip)) {
                                        try self.diag.push(.{
                                            .severity = .err,
                                            .code = .invalid_microvm,
                                            .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` ip `{s}` is not valid ipv4", .{ vm.name.name, ip }),
                                            .span = vm.name.span,
                                            .help = "example: ip = \"10.8.0.2\";",
                                        });
                                    }
                                    if (vm.ip_type) |ty| {
                                        if (!self.isStringType(ty)) {
                                            try self.diag.push(.{
                                                .severity = .err,
                                                .code = .type_mismatch,
                                                .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` ip type must be String/Ipv4/Path", .{vm.name.name}),
                                                .span = vm.name.span,
                                                .help = try std.fmt.allocPrint(self.allocator, "got {s}", .{self.typeToString(ty)}),
                                            });
                                        } else if (!self.typeMatchesExpr(ty, .{ .span = vm.name.span, .data = .{ .string = ip } })) {
                                            try self.diag.push(.{
                                                .severity = .err,
                                                .code = .type_mismatch,
                                                .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` ip value type mismatch", .{vm.name.name}),
                                                .span = vm.name.span,
                                                .help = try std.fmt.allocPrint(self.allocator, "expected {s}, got String", .{self.typeToString(ty)}),
                                            });
                                        }
                                    }
                                }
                                if (vm.mem) |m| {
                                    _ = m;
                                    if (vm.mem_type) |ty| {
                                        if (!self.isIntegerType(ty)) {
                                            try self.diag.push(.{
                                                .severity = .err,
                                                .code = .type_mismatch,
                                                .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` mem type must be integer", .{vm.name.name}),
                                                .span = vm.name.span,
                                                .help = try std.fmt.allocPrint(self.allocator, "got {s}", .{self.typeToString(ty)}),
                                            });
                                        }
                                    }
                                }
                                if (vm.cpu) |c| {
                                    _ = c;
                                    if (vm.cpu_type) |ty| {
                                        if (!self.isIntegerType(ty)) {
                                            try self.diag.push(.{
                                                .severity = .err,
                                                .code = .type_mismatch,
                                                .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` cpu type must be integer", .{vm.name.name}),
                                                .span = vm.name.span,
                                                .help = try std.fmt.allocPrint(self.allocator, "got {s}", .{self.typeToString(ty)}),
                                            });
                                        }
                                    }
                                }
                                if (vm.net) |n| {
                                    _ = n;
                                    if (vm.net_type) |ty| {
                                        if (!self.isStringType(ty)) {
                                            try self.diag.push(.{
                                                .severity = .err,
                                                .code = .type_mismatch,
                                                .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` net type must be String", .{vm.name.name}),
                                                .span = vm.name.span,
                                                .help = try std.fmt.allocPrint(self.allocator, "got {s}", .{self.typeToString(ty)}),
                                            });
                                        }
                                    }
                                }
                                for (vm.volumes) |vol| {
                                    if (vol.image.len == 0) {
                                        try self.diag.push(.{
                                            .severity = .err,
                                            .code = .invalid_microvm,
                                            .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` volume missing image", .{vm.name.name}),
                                            .span = vol.span,
                                            .help = "example: volume { image = \"data.img\"; mountPoint = \"/var/lib/data\"; size = 1024; }",
                                        });
                                    }
                                    if (vol.mountPoint.len == 0) {
                                        try self.diag.push(.{
                                            .severity = .err,
                                            .code = .invalid_microvm,
                                            .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` volume missing mountPoint", .{vm.name.name}),
                                            .span = vol.span,
                                            .help = null,
                                        });
                                    }
                                    if (vol.size <= 0) {
                                        try self.diag.push(.{
                                            .severity = .err,
                                            .code = .invalid_microvm,
                                            .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` volume size must be positive", .{vm.name.name}),
                                            .span = vol.span,
                                            .help = "example: size = 1024;",
                                        });
                                    }
                                    if (vol.size > 1024 * 1024) {
                                        try self.diag.push(.{
                                            .severity = .err,
                                            .code = .invalid_microvm,
                                            .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` volume size too large", .{vm.name.name}),
                                            .span = vol.span,
                                            .help = "max 1TiB",
                                        });
                                    }
                                }
                            },
                        }
                    }
                },
                .microvm => |vm| {
                    if (vm.mem) |m| if (m <= 0) {
                        try self.diag.push(.{ .severity = .err, .code = .invalid_microvm, .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` mem must be positive", .{vm.name.name}), .span = vm.name.span, .help = "example: mem = 512;" });
                    };
                    if (vm.cpu) |c| if (c <= 0) {
                        try self.diag.push(.{ .severity = .err, .code = .invalid_microvm, .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` cpu must be positive", .{vm.name.name}), .span = vm.name.span, .help = "example: cpu = 1;" });
                    };
                    if (vm.net) |n| if (n.len == 0) {
                        try self.diag.push(.{ .severity = .err, .code = .invalid_microvm, .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` net must be non-empty", .{vm.name.name}), .span = vm.name.span, .help = "example: net = \"lan\";" });
                    };
                    if (vm.ip) |ip| if (!isValidIpv4(ip)) {
                        try self.diag.push(.{ .severity = .err, .code = .invalid_microvm, .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` ip `{s}` is not valid ipv4", .{ vm.name.name, ip }), .span = vm.name.span, .help = "example: ip = \"10.8.0.2\";" });
                    };
                    for (vm.volumes) |vol| {
                        if (vol.image.len == 0) {
                            try self.diag.push(.{ .severity = .err, .code = .invalid_microvm, .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` volume missing image", .{vm.name.name}), .span = vol.span, .help = null });
                        }
                        if (vol.size <= 0) {
                            try self.diag.push(.{ .severity = .err, .code = .invalid_microvm, .message = try std.fmt.allocPrint(self.allocator, "microvm `{s}` volume size must be positive", .{vm.name.name}), .span = vol.span, .help = null });
                        }
                    }
                },
                else => {},
            }
        }
    }

    fn checkExpr(self: *Semantic, expr: ast.Expr, scope: *std.StringHashMap(diagnostics.Span)) !void {
        switch (expr.data) {
            .ident => |ident| {
                if (!scope.contains(ident.name)) {
                    // Also check if it's a known role/bundle/preset? For now, only check let scope
                    // Unknown ident will be reported as unknown_ident with suggestion if close
                    var help: ?[]const u8 = null;
                    var candidates: std.ArrayList([]const u8) = .empty;
                    var it = scope.keyIterator();
                    while (it.next()) |k| try candidates.append(self.allocator, k.*);
                    if (candidates.items.len > 0) {
                        if (try diagnostics.Diagnostics.suggest(ident.name, candidates.items, self.allocator)) |s| help = s;
                    }
                    try self.diag.push(.{
                        .severity = .err,
                        .code = .unknown_ident,
                        .message = try std.fmt.allocPrint(self.allocator, "unknown identifier `{s}`", .{ident.name}),
                        .span = ident.span,
                        .help = help,
                    });
                }
            },
            .binary => |b| {
                try self.checkExpr(b.lhs.*, scope);
                try self.checkExpr(b.rhs.*, scope);
            },
            .unary => |u| try self.checkExpr(u.expr.*, scope),
            .paren => |p| try self.checkExpr(p.*, scope),
            .list => |lst| for (lst) |item| try self.checkExpr(item, scope),
            .string, .integer, .boolean => {},
        }
    }

    fn isValidIpv4(ip: []const u8) bool {
        var parts: usize = 0;
        var start: usize = 0;
        var i: usize = 0;
        while (i < ip.len) : (i += 1) {
            const c = ip[i];
            if (c == '.') {
                if (i <= start) return false;
                const part = ip[start..i];
                if (part.len == 0 or part.len > 3) return false;
                const val = std.fmt.parseInt(u16, part, 10) catch return false;
                if (val > 255) return false;
                parts += 1;
                start = i + 1;
            } else if (!std.ascii.isDigit(c)) {
                return false;
            }
        }
        // last part
        if (start >= ip.len) return false;
        const part = ip[start..];
        if (part.len == 0 or part.len > 3) return false;
        const val = std.fmt.parseInt(u16, part, 10) catch return false;
        if (val > 255) return false;
        parts += 1;
        return parts == 4;
    }

    fn isIntegerType(self: *Semantic, ty: ast.Type) bool {
        _ = self;
        return switch (ty.data) {
            .i32, .i64, .u32, .u64, .usize => true,
            else => false,
        };
    }

    fn isStringType(self: *Semantic, ty: ast.Type) bool {
        _ = self;
        return switch (ty.data) {
            .string, .ipv4, .path, .duration => true,
            else => false,
        };
    }

    fn typeMatchesExpr(self: *Semantic, ty: ast.Type, expr: ast.Expr) bool {
        switch (ty.data) {
            .string, .ipv4, .path, .duration => return expr.data == .string,
            .bool => return expr.data == .boolean,
            .i32, .i64, .u32, .u64, .usize => return expr.data == .integer or (expr.data == .unary and expr.data.unary.op == .neg and expr.data.unary.expr.*.data == .integer),
            .list => |inner| {
                if (expr.data != .list) return false;
                for (expr.data.list) |item| {
                    if (!self.typeMatchesExpr(inner.*, item)) return false;
                }
                return true;
            },
            .option => |inner| {
                return self.typeMatchesExpr(inner.*, expr);
            },
            .named => return true,
        }
    }

    fn typeToString(self: *Semantic, ty: ast.Type) []const u8 {
        _ = self;
        return switch (ty.data) {
            .string => "String",
            .ipv4 => "Ipv4",
            .path => "Path",
            .duration => "Duration",
            .bool => "bool",
            .i32 => "i32",
            .i64 => "i64",
            .u32 => "u32",
            .u64 => "u64",
            .usize => "usize",
            .list => "List<_>",
            .option => "Option<_>",
            .named => |c| c,
        };
    }

    fn exprTypeName(self: *Semantic, expr: ast.Expr) []const u8 {
        _ = self;
        return switch (expr.data) {
            .string => "String",
            .integer => "i64",
            .boolean => "bool",
            .ident => "ident",
            .list => "List<_>",
            .binary => "binary",
            .unary => "unary",
            .paren => "paren",
        };
    }

    fn inferExprType(self: *Semantic, expr: ast.Expr) !?ast.Type {
        const span = expr.span;
        switch (expr.data) {
            .string => return ast.Type{ .span = span, .data = .string },
            .boolean => return ast.Type{ .span = span, .data = .bool },
            .integer => {
                // For 8.4a, infer as u32 for non-negative small, else i64
                // Keep simple: infer as u32 if fits, else i64
                const v = expr.data.integer;
                if (v >= 0 and v <= 4294967295) {
                    return ast.Type{ .span = span, .data = .u32 };
                } else {
                    return ast.Type{ .span = span, .data = .i64 };
                }
            },
            .list => |lst| {
                if (lst.len == 0) return null;
                // Infer inner from first element, ensure all same
                const first_ty = try self.inferExprType(lst[0]);
                if (first_ty == null) return null;
                // For now, assume homogeneous and return List<first>
                const inner_ptr = try self.allocator.create(ast.Type);
                inner_ptr.* = first_ty.?;
                return ast.Type{ .span = span, .data = .{ .list = inner_ptr } };
            },
            .ident => |ident| {
                // Could be reference to let - try to lookup inferred type from ordered scope?
                // For 8.4a, not yet handling cross-let inference, return null
                _ = ident;
                return null;
            },
            .binary => |b| {
                // For binary, try to infer via lhs/rhs if both same
                const lhs_ty = try self.inferExprType(b.lhs.*);
                const rhs_ty = try self.inferExprType(b.rhs.*);
                if (lhs_ty != null and rhs_ty != null and std.meta.eql(lhs_ty.?, rhs_ty.?)) return lhs_ty;
                return lhs_ty orelse rhs_ty;
            },
            .unary => |u| return try self.inferExprType(u.expr.*),
            .paren => |e| return try self.inferExprType(e.*),
        }
    }

    pub fn inferLetType(self: *Semantic, expr: ast.Expr) !?ast.Type {
        return try self.inferExprType(expr);
    }
};

test "semantic unknown role" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "role desktop {} host x270 { use gamign; }";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.meow", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.meow", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.init(toks, &diag, &arena);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    try std.testing.expect(diag.hasErrors());
}

test "semantic duplicate host" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host x270 {} host x270 {}";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.meow", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.meow", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.init(toks, &diag, &arena);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    try std.testing.expect(diag.hasErrors());
}

test "semantic type mismatch let u32 vs string" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "let x: u32 = \"cat\";";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    var found = false;
    for (diag.list.items) |d| {
        if (d.code == .type_mismatch) found = true;
    }
    try std.testing.expect(found);
    try std.testing.expect(diag.hasErrors());
}

test "semantic type mismatch let Ipv4 vs integer" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "let addr: Ipv4 = 123;";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    var found = false;
    for (diag.list.items) |d| { if (d.code == .type_mismatch) found = true; }
    try std.testing.expect(found);
}

test "semantic type ok let" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "let x: u32 = 42; let y: String = \"cat\"; let z: Ipv4 = \"10.8.0.2\";";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    for (diag.list.items) |d| {
        if (d.code == .type_mismatch) {
            std.debug.print("unexpected type_mismatch: {s}\n", .{d.message});
            try std.testing.expect(false);
        }
    }
    try std.testing.expect(!diag.hasErrors());
}

test "semantic type mismatch microvm mem" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host mireo { microvm grafana { mem: String = 768; cpu: u32 = 2; net: String = \"lan\"; } }";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    var found = false;
    for (diag.list.items) |d| { if (d.code == .type_mismatch) found = true; }
    try std.testing.expect(found);
}

test "semantic type ok microvm" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "host mireo { microvm grafana { mem: u32 = 768; cpu: u32 = 2; ip: Ipv4 = \"10.8.0.2\"; net: String = \"lan\"; } }";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    for (diag.list.items) |d| { if (d.code == .type_mismatch) {
        std.debug.print("unexpected mismatch {s}\n", .{d.message});
        try std.testing.expect(false);
    } }
    try std.testing.expect(!diag.hasErrors());
}

test "semantic type mismatch List" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "let x: List<u32> = [\"a\", \"b\"];";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    var found = false;
    for (diag.list.items) |d| { if (d.code == .type_mismatch) found = true; }
    try std.testing.expect(found);
}

test "semantic infer let integer" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "let x = 768;";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    const expr = prog.decls[0].let_decl.value;
    const ty = try sem.inferExprType(expr);
    try std.testing.expect(ty != null);
    try std.testing.expect(ty.?.data == .u32 or ty.?.data == .i64);
    try std.testing.expect(!diag.hasErrors());
}

test "semantic infer let string" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "let s = \"foo\";";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    const expr = prog.decls[0].let_decl.value;
    const ty = try sem.inferExprType(expr);
    try std.testing.expect(ty != null);
    try std.testing.expect(ty.?.data == .string);
}

test "semantic infer let bool" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "let b = true;";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    const expr = prog.decls[0].let_decl.value;
    const ty = try sem.inferExprType(expr);
    try std.testing.expect(ty != null);
    try std.testing.expect(ty.?.data == .bool);
}

test "semantic infer let list" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "let xs = [1, 2, 3];";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    const expr = prog.decls[0].let_decl.value;
    const ty = try sem.inferExprType(expr);
    try std.testing.expect(ty != null);
    try std.testing.expect(ty.?.data == .list);
    try std.testing.expect(ty.?.data.list.*.data == .u32 or ty.?.data.list.*.data == .i64);
}

test "semantic infer explicit dominant" {
    const alloc = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const source = "let x: u32 = 768;";
    var diag = diagnostics.Diagnostics.init(arena.allocator(), "test.purr", source);
    const lexer = @import("lexer.zig");
    var lex = lexer.Lexer.init(source, "test.purr", &diag);
    const toks = try lex.lexAll(arena.allocator());
    var parser = @import("parser.zig").Parser.initWithSource(toks, &diag, &arena, source);
    var prog = try parser.parseProgram();
    try std.testing.expect(prog.decls[0].let_decl.type_annot != null);
    var sem = Semantic.init(&prog, &diag, arena.allocator());
    try sem.analyze();
    try std.testing.expect(!diag.hasErrors());
    // inferred should still work for explicit, but explicit is checked separately
    const expr = prog.decls[0].let_decl.value;
    const inferred = try sem.inferExprType(expr);
    try std.testing.expect(inferred != null);
}

