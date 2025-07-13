const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

const Config = @import("Config.zig");

pub fn main() !void {
    if (builtin.os.tag == .windows) {
        return error.UnsupportedOperatingSystem;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cfg = try Config.load(allocator);
    defer cfg.deinit();
}

test {
    std.testing.refAllDecls(@This());
}
