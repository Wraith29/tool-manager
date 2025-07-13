const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.config);
const path = @import("path.zig");

const Config = @This();

const app_name = "tool-manager";

/// The base path for the tools.json file, and the src / bin dirs
tool_path: []const u8,

fn getPaths(allocator: Allocator) !struct { []const u8, []const u8 } {
    const base_path = try std.fs.getAppDataDir(allocator, app_name);

    return .{ base_path, try std.fs.path.join(allocator, &.{ base_path, "config.json" }) };
}

fn default(allocator: Allocator) !*Config {
    log.info("Config file not found. Creating a default config.", .{});

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const home = env_map.get("HOME") orelse {
        log.err("Expected HOME variable, not found", .{});
        return error.MissingExpectedEnvironmentVariable;
    };

    const tool_path = try std.fs.path.join(allocator, &.{ home, ".tool-manager" });

    const cfg = try allocator.create(Config);

    cfg.tool_path = tool_path;

    return cfg;
}

fn loadFromPath(allocator: Allocator, cfg_path: []const u8) !*Config {
    log.info("Loading config from: {s}", .{cfg_path});

    var cfg_file = try std.fs.openFileAbsolute(cfg_path, .{});
    defer cfg_file.close();

    // 4096 bytes max size
    const bytes = try cfg_file.readToEndAlloc(allocator, 1 << 12);
    defer allocator.free(bytes);

    const parsed_cfg = try std.json.parseFromSlice(Config, allocator, bytes, .{ .allocate = .alloc_always });
    defer parsed_cfg.deinit();

    var cfg = try allocator.create(Config);
    errdefer allocator.destroy(cfg);

    const tool_path = try allocator.alloc(u8, parsed_cfg.value.tool_path.len);
    @memcpy(tool_path, parsed_cfg.value.tool_path);
    cfg.tool_path = tool_path;

    return cfg;
}

fn saveToFile(self: *const Config, allocator: Allocator, cfg_path: []const u8) !void {
    var cfg_file = if (path.exists(cfg_path))
        try std.fs.openFileAbsolute(cfg_path, .{ .mode = .write_only })
    else
        try std.fs.createFileAbsolute(cfg_path, .{});
    defer cfg_file.close();

    const bytes = try std.json.stringifyAlloc(allocator, self, .{ .whitespace = .indent_2 });
    defer allocator.free(bytes);

    try cfg_file.seekTo(0);
    try cfg_file.writeAll(bytes);
}

pub fn init(allocator: Allocator) !*Config {
    const base_path, const cfg_path = try getPaths(allocator);
    defer {
        allocator.free(base_path);
        allocator.free(cfg_path);
    }

    if (!path.exists(base_path))
        try std.fs.makeDirAbsolute(base_path);

    if (path.exists(cfg_path))
        return try loadFromPath(allocator, cfg_path);

    log.info("Config File not found. Generating Defaults", .{});
    const cfg = try default(allocator);
    errdefer cfg.deinit(allocator);

    log.info("Saving Config to {s}", .{cfg_path});

    try cfg.saveToFile(allocator, cfg_path);

    return cfg;
}

pub fn deinit(self: *Config, allocator: Allocator) void {
    allocator.free(self.tool_path);
    allocator.destroy(self);
}
