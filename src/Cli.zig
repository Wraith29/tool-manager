const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("Args.zig");
const Command = @import("Command.zig");

const Cli = @This();

name: []const u8,
commands: []const Command,

pub fn run(self: *Cli, allocator: Allocator, args: *Args) !void {
    const sub_cmd = args.next() orelse return error.NoCommandProvided;

    for (self.commands) |command| {
        if (command.match(sub_cmd))
            return command.run(allocator, args);
    }

    return error.UnknownCommand;
}
