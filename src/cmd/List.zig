const std = @import("std");
const Allocator = std.mem.Allocator;

const Config = @import("../Config.zig");
const files = @import("../files.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");
const Tool = @import("../Tool.zig");

const log = std.log.scoped(.list_cmd);
const List = @This();

const help =
    \\tm list
    \\  list all installed tools, and the repositories they live in
    \\
    \\usage:
    \\  tm list
    \\
    \\options:
    \\  -h, --help    Show this message
;

pub fn command() Command {
    return Command{
        .name = "list",
        .help = help,
        .isMatchFn = isMatch,
        .parseFn = parse,
    };
}

pub fn isMatch(cmd: []const u8) bool {
    return std.mem.eql(u8, cmd, "list");
}

pub fn parse(_: Allocator, _: []const []const u8) Command.ParseError!Executable {
    var exe = List{};

    return Executable{
        .ptr = &exe,
        .executeFn = execute,
        .deinitFn = deinit,
    };
}

pub fn deinit(_: *anyopaque, _: Allocator) void {}

pub fn execute(_: *anyopaque, allocator: Allocator) !void {
    const tools = try Tool.loadAll(allocator);
    defer tools.deinit();

    var writer = std.io.getStdOut().writer();

    for (tools.value.map.keys()) |key| {
        const tool = tools.value.map.get(key) orelse unreachable;
        try writer.print("{s} ({s})\n", .{ tool.name, tool.repository });
    }
}
