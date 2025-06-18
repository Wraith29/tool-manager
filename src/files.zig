const std = @import("std");
const log = std.log;
const Allocator = std.mem.Allocator;

const app_name = "tool-manager";
pub var app_data_dir: []const u8 = undefined;

pub fn init(allocator: Allocator) !void {
    app_data_dir = try std.fs.getAppDataDir(allocator, app_name);
}

pub fn deinit(allocator: Allocator) void {
    allocator.free(app_data_dir);
}

pub fn pathExists(fp: []const u8) bool {
    std.fs.accessAbsolute(fp, .{}) catch return false;

    return true;
}

pub fn createFileWithContents(fp: []const u8, contents: []const u8) !void {
    var file = try std.fs.createFileAbsolute(fp, .{});
    defer file.close();

    try file.writeAll(contents);
}
