const std = @import("std");
const Allocator = std.mem.Allocator;

const Config = @import("../Config.zig");
const files = @import("../files.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");
const Tool = @import("../Tool.zig");

const log = std.log.scoped(.list_cmd);
const List = @This();

pub fn command() Command {
    return Command{
        .name = "list",
        .helpFn = help,
        .isMatchFn = isMatch,
        .parseFn = parse,
    };
}

pub fn help() []const u8 {
    return "TODO: Implement List help message";
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

    for (tools.value) |tool| {
        try writer.print("{s} ({s})\n", .{ tool.name, tool.repository });
    }
}
