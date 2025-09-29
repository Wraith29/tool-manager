const std = @import("std");
const log = std.log.scoped(.config);
const Allocator = std.mem.Allocator;

const path = @import("path.zig");

const Config = @This();

pub fn init(allocator: Allocator) !*Config {
    const cfg_path = try path.getConfigPath(allocator);
    defer allocator.free(cfg_path);

    const cfg = try allocator.create(Config);

    if (path.exists(cfg_path)) {
        cfg.* = try loadFromFile(allocator, cfg_path);
    } else {
        cfg.* = default();
        try cfg.save(cfg_path);
    }

    return cfg;
}

pub fn deinit(self: *Config, allocator: Allocator) void {
    allocator.destroy(self);
}

pub fn save(self: *Config, cfg_path: []const u8) !void {
    var file = try std.fs.createFileAbsolute(cfg_path, .{ .truncate = true });
    defer file.close();

    var buf: [256]u8 = undefined;
    var writer = file.writer(&buf);
    const io_writer = &writer.interface;

    try std.zon.stringify.serialize(self, .{}, io_writer);

    try io_writer.flush();
}

fn loadFromFile(allocator: Allocator, cfg_path: []const u8) !Config {
    var file = try std.fs.openFileAbsolute(cfg_path, .{});
    defer file.close();

    var buf: [256]u8 = undefined;
    var reader = file.reader(&buf);
    var io_reader = &reader.interface;

    const bytes = try io_reader.allocRemaining(allocator, .unlimited);
    defer allocator.free(bytes);

    const data = try std.mem.concatWithSentinel(allocator, u8, &.{bytes}, 0);
    defer allocator.free(data);

    return try std.zon.parse.fromSlice(Config, allocator, data, null, .{});
}

fn default() Config {
    return .{};
}
