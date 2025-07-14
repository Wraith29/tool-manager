const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");
const log = std.log.scoped(.main);

const Config = @import("Config.zig");
const path = @import("path.zig");

fn ensureToolPathsExist(cfg: *const Config) !void {
    if (!path.exists(cfg.tool_path)) {
        log.info("{s} not found, creating it", .{cfg.tool_path});
        try std.fs.makeDirAbsolute(cfg.tool_path);
    }

    var tool_dir = try std.fs.openDirAbsolute(cfg.tool_path, .{});
    defer tool_dir.close();

    tool_dir.access("tools.json", .{}) catch {
        log.info("tools.json not found, creating it", .{});
        var tools_file = try tool_dir.createFile("tools.json", .{});
        defer tools_file.close();

        try tools_file.writeAll("{}");
    };

    tool_dir.access("src", .{}) catch {
        log.info("src dir not found, creating it", .{});
        try tool_dir.makeDir("src");
    };

    tool_dir.access("bin", .{}) catch {
        log.info("bin dir not found, creating it", .{});
        try tool_dir.makeDir("bin");
    };
}

pub fn main() !void {
    if (builtin.os.tag == .windows) {
        return error.UnsupportedOperatingSystem;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cfg = try Config.init(allocator);
    defer cfg.deinit(allocator);

    try ensureToolPathsExist(cfg);

    std.log.info("Tool Path: {s}", .{cfg.tool_path});
}

test {
    std.testing.refAllDecls(@This());
}
