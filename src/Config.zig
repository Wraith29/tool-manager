const std = @import("std");
const log = std.log;
const Allocator = std.mem.Allocator;

const files = @import("files.zig");

const Config = @This();

max_threads: usize = 4,
install_directory: []const u8,

pub fn load(allocator: Allocator) !*Config {
    const cfg_fp = try std.mem.concat(allocator, u8, &.{ files.app_data_dir, std.fs.path.sep_str, "config.json" });
    defer allocator.free(cfg_fp);

    log.info("Checking for Config @ {s}", .{cfg_fp});

    if (!files.pathExists(cfg_fp))
        return error.FileNotFound;

    const cfg_file = try std.fs.openFileAbsolute(cfg_fp, .{});
    defer cfg_file.close();

    const cfg_contents = try cfg_file.readToEndAlloc(allocator, 1 << 16);
    defer allocator.free(cfg_contents);

    const json_obj = try std.json.parseFromSlice(Config, allocator, cfg_contents, .{ .allocate = .alloc_always });
    defer json_obj.deinit();

    const install_dir = try allocator.alloc(u8, json_obj.value.install_directory.len);
    @memcpy(install_dir, json_obj.value.install_directory);

    const cfg = try allocator.create(Config);

    cfg.max_threads = json_obj.value.max_threads;
    cfg.install_directory = install_dir;

    return cfg;
}

pub fn destroy(self: *Config, allocator: Allocator) void {
    allocator.free(self.install_directory);
    allocator.destroy(self);
}
