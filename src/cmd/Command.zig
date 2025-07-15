const std = @import("std");
const Allocator = std.mem.Allocator;

const arg_parser = @import("../arg_parser.zig");
const Executable = @import("Executable.zig");

const Command = @This();

pub const ParseError = arg_parser.Error || Allocator.Error;

name: []const u8,
aliases: []const []const u8,
help: []const u8,

parseFn: ?*const fn (Allocator, []const []const u8) ParseError!Executable,

pub fn match(self: Command, cmd: []const u8) bool {
    if (std.mem.eql(u8, cmd, self.name))
        return true;

    for (self.aliases) |alias|
        if (std.mem.eql(u8, cmd, alias))
            return true;

    return false;
}

test "match - cmd doesn't match anything - false" {
    const cmd = Command{
        .name = "hello",
        .aliases = &.{ "hi", "hey" },
        .help = "",
        .parseFn = null,
    };

    try std.testing.expect(!cmd.match("wassup"));
}

test "match - cmd matches the name - true" {
    const cmd = Command{
        .name = "hello",
        .aliases = &.{ "hi", "hey" },
        .help = "",
        .parseFn = null,
    };

    try std.testing.expect(cmd.match("hello"));
}

test "match - cmd matches an alias - true" {
    const cmd = Command{
        .name = "hello",
        .aliases = &.{ "hi", "hey" },
        .help = "",
        .parseFn = null,
    };

    try std.testing.expect(cmd.match("hi"));
    try std.testing.expect(cmd.match("hey"));
}

pub fn parse(self: Command, allocator: Allocator, args: []const []const u8) ParseError!Executable {
    return self.parseFn.?(allocator, args);
}
