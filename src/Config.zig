const std = @import("std");
const Allocator = std.mem.Allocator;
const file = @import("file.zig");

const Config = @This();

tool_src_dir: []const u8,
tool_install_dir: []const u8,

fn path(allocator: Allocator) ![]const u8 {
    const app_data_dir = try std.fs.getAppDataDir(allocator, "tool-manager");
    defer allocator.free(app_data_dir);
}

pub fn load(allocator: Allocator) !*Config {
    const cfg = try allocator.alloc(Config);

    return cfg;
}
