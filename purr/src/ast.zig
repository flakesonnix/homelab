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

pub const Expr = struct {
    span: Span,
    data: Data,
    pub const Data = union(enum) {
        string: []const u8,
        integer: i64,
        boolean: bool,
        ident: Ident,
        list: []Expr,
        binary: Binary,
        unary: Unary,
        paren: *Expr,
    };
};

pub const BinaryOp = enum { add, sub, mul, div, mod, eq, neq, logical_and, logical_or, lt, gt, lte, gte };
pub const UnaryOp = enum { not, neg };

pub const Binary = struct {
    op: BinaryOp,
    lhs: *Expr,
    rhs: *Expr,
    span: Span,
};

pub const Unary = struct {
    op: UnaryOp,
    expr: *Expr,
    span: Span,
};

pub const Type = struct {
    span: Span,
    data: Data,
    pub const Data = union(enum) {
        bool,
        i32,
        i64,
        u32,
        u64,
        usize,
        string, // String / str
        ipv4, // Ipv4
        path, // Path
        duration, // Duration
        list: *Type, // List<T> / Vec<T>
        option: *Type, // Option<T>
        named: []const u8, // custom e.g. Volume, MicroVM, etc.
    };
};

pub const Let = struct {
    name: Ident,
    type_annot: ?Type = null,
    value: Expr,
    span: Span,
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

pub const Volume = struct {
    name: ?Ident = null, // for `volume data: Volume { ... }` name is "data"
    type_annot: ?Type = null, // e.g. Volume
    image: []const u8,
    mountPoint: []const u8,
    size: i64, // MiB, positive
    user: ?[]const u8,
    group: ?[]const u8,
    span: Span,
};

pub const MicroVM = struct {
    name: Ident,
    mem: ?i64, // MiB, positive
    mem_type: ?Type = null,
    cpu: ?i64, // vCPU count, positive
    cpu_type: ?Type = null,
    net: ?[]const u8, // network name, e.g. "lan"
    net_type: ?Type = null,
    ip: ?[]const u8, // ipv4 string, e.g. "10.8.0.2"
    ip_type: ?Type = null,
    volumes: []Volume,
    span: Span,
};

pub const HostStmt = union(enum) {
    use_role: Ident,
    preset: Ident,
    package: []const u8,
    packages_assign: [][]const u8,
    setting: Setting,
    let_decl: Let,
    microvm: MicroVM,
    import: Import,
};

pub const Setting = struct {
    path: []const u8, // dotted path e.g. "services.printing.enable"
    type_annot: ?Type = null, // optional typed setting e.g. `services.nginx.enable: bool = true;`
    value: Expr,
    span: Span,
};

pub const Host = struct {
    name: Ident,
    extends: ?Ident, // parent host for `host child extends parent { ... }`
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
    let_decl: Let,
    microvm: MicroVM,
    struct_decl: Struct,
};

pub const StructField = struct {
    name: Ident,
    type_annot: Type,
    span: Span,
};

pub const Struct = struct {
    name: Ident,
    fields: []StructField,
    span: Span,
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
