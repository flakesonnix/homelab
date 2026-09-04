const std = @import("std");
const cli = @import("cli.zig");

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.gpa;
    var args_iter = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args_iter.deinit();

    var list: std.ArrayList([]const u8) = .empty;
    defer {
        for (list.items) |item| allocator.free(item);
        list.deinit(allocator);
    }

    while (args_iter.next()) |arg_ptr| {
        const arg: []const u8 = arg_ptr;
        const duped = try allocator.dupe(u8, arg);
        try list.append(allocator, duped);
    }

    return try cli.run(init, list.items);
}
