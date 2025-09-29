const std = @import("std");
const Allocator = std.mem.Allocator;

const app_name = "tool-manager";

fn ensureAppDataDirExists(allocator: Allocator) !void {
    const app_data_dir = try std.fs.getAppDataDir(allocator, app_name);
    defer allocator.free(app_data_dir);

    if (exists(app_data_dir))
        return;

    try std.fs.makeDirAbsolute(app_data_dir);
}

pub fn getConfigPath(allocator: Allocator) ![]const u8 {
    try ensureAppDataDirExists(allocator);

    const app_data_dir = try std.fs.getAppDataDir(allocator, app_name);
    defer allocator.free(app_data_dir);

    return std.fs.path.join(allocator, &.{ app_data_dir, "config.zon" });
}

pub fn exists(path: []const u8) bool {
    std.fs.accessAbsolute(path, .{}) catch return false;

    return true;
}
