const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn copy(allocator: Allocator, str: []const u8) Allocator.Error![]const u8 {
    const buf = try allocator.alloc(u8, str.len);
    @memcpy(buf, str);

    return buf;
}
