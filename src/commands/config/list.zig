const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("../../Args.zig");
const Config = @import("../../Config.zig");
const path = @import("../../path.zig");

const log = std.log.scoped(.config_list);

pub fn execute(allocator: Allocator, _: *Args) !void {
    var stdout = std.fs.File.stdout();
    defer stdout.close();

    var buf: [256]u8 = undefined;
    var writer = stdout.writer(&buf);
    const io_writer = &writer.interface;

    const cfg_path = try path.getConfigPath(allocator);
    defer allocator.free(cfg_path);

    try io_writer.print("Config Path: {s}\n\n", .{cfg_path});

    var cfg = try Config.init(allocator);
    defer cfg.deinit(allocator);

    try io_writer.writeAll("Settings:\n");

    inline for (std.meta.fields(Config)) |field| {
        const value = @field(cfg, field.name);

        try io_writer.print("  {s}: {?s}\n", .{ field.name, value });
    }

    try io_writer.flush();
}
