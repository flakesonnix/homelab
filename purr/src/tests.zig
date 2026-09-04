// Aggregator for `zig build test` — imports all modules so their `test` blocks run.
comptime {
    _ = @import("lexer.zig");
    _ = @import("diagnostics.zig");
    _ = @import("parser.zig");
    _ = @import("semantic.zig");
    _ = @import("nix.zig");
    _ = @import("resolver.zig");
    _ = @import("fmt.zig");
}
test {
    std.testing.refAllDecls(@This());
}
const std = @import("std");
