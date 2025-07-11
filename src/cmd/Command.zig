const std = @import("std");
const Allocator = std.mem.Allocator;
const ArgParser = @import("../ArgParser.zig");

const Executable = @import("Executable.zig");

const Command = @This();

pub const ParseError = ArgParser.Error || Allocator.Error;

name: []const u8,
aliases: []const []const u8,
help: []const u8,

/// TODO: Change this to return an actual executable
parseFn: *const fn (Allocator) ParseError!Executable,

pub fn match(self: Command, cmd: []const u8) bool {
    if (std.mem.eql(u8, cmd, self.name))
        return true;

    for (self.aliases) |alias|
        if (std.mem.eql(u8, cmd, alias))
            return true;

    return false;
}

pub fn parse(self: Command, allocator: Allocator) ParseError!Executable {
    return self.parseFn(allocator);
}
