const std = @import("std");
const diagnostics = @import("diagnostics.zig");
pub const Span = diagnostics.Span;

pub const Ident = struct {
    name: []const u8,
    span: Span,
};

pub const Value = union(enum) {
    string: []const u8,
    integer: i64,
    boolean: bool,
    list: []Value,
    ident: Ident,
};

pub const Import = struct {
    path: []const u8,
    span: Span,
};

pub const RoleField = union(enum) {
    description: []const u8,
    targets: [][]const u8,
    requires: [][]const u8,
    conflicts: [][]const u8,
    host_block: HostBlock,
    home_block: HomeBlock,
};

pub const HostBlock = struct {
    presets: [][]const u8,
    tags: [][]const u8,
    span: Span,
};

pub const HomeBlock = struct {
    bundles: [][]const u8,
    span: Span,
};

pub const Role = struct {
    name: Ident,
    description: ?[]const u8,
    targets: [][]const u8,
    requires_host: [][]const u8,
    requires_home: [][]const u8,
    conflicts_host: [][]const u8,
    conflicts_home: [][]const u8,
    host: ?HostBlock,
    home: ?HomeBlock,
    span: Span,
};

pub const HostStmt = union(enum) {
    use_role: Ident,
    preset: Ident,
    package: []const u8,
    packages_assign: [][]const u8,
    setting: Setting,
};

pub const Setting = struct {
    path: []const u8, // dotted path e.g. "services.printing.enable"
    value: Value,
    span: Span,
};

pub const Host = struct {
    name: Ident,
    stmts: []HostStmt,
    span: Span,
};

pub const Bundle = struct {
    name: Ident,
    description: ?[]const u8,
    programs: [][]const u8, // simplified
    package_toggles: [][]const u8,
    span: Span,
};

pub const Preset = struct {
    name: Ident,
    description: ?[]const u8,
    flags: []Setting,
    span: Span,
};

pub const NixBlock = struct {
    content: []const u8, // raw Nix inside `nix { ... }`
    span: Span,
};

pub const Decl = union(enum) {
    role: Role,
    host: Host,
    bundle: Bundle,
    preset: Preset,
    package_decl: Package,
    nix: NixBlock,
};

pub const Package = struct {
    name: []const u8, // string lit like "git"
    span: Span,
};

pub const Program = struct {
    imports: []Import,
    decls: []Decl,
    arena: std.heap.ArenaAllocator, // owns all slices

    pub fn deinit(self: *Program) void {
        self.arena.deinit();
    }
};
