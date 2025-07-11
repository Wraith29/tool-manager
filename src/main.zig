const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Hello = @import("cmd/Hello.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cmd = Hello.command();
    const hello_exe = try cmd.parse(allocator);
    try hello_exe.execute(allocator);
}

test {
    std.testing.refAllDecls(@This());
}
