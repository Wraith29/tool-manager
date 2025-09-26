const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("Args.zig");

const Command = @This();

name: []const u8,
short: ?[]const u8 = null,
execute: ?*const fn (Allocator, *Args) anyerror!void = null,
subcommands: []const Command = &.{},

pub fn match(self: Command, cmd: []const u8) bool {
    if (std.mem.eql(u8, self.name, cmd))
        return true;

    if (self.short) |short|
        return std.mem.eql(u8, short, cmd);

    return false;
}

pub fn run(self: *const Command, allocator: Allocator, args: *Args) !void {
    if (self.execute) |exec| {
        return try exec(allocator, args);
    }

    const subcmd = args.next() orelse return error.NoCommandProvided;

    for (self.subcommands) |sub| {
        if (sub.match(subcmd))
            return sub.run(allocator, args);
    }

    return error.UnknownSubCommand;
}
