const std = @import("std");
const Allocator = std.mem.Allocator;

const Executable = @import("Executable.zig");

const log = std.log.scoped(.command);
const Command = @This();

pub const ParseError = error{
    MissingPositionalArgument,
    InvalidArgument,
    InvalidFlag,
} || Allocator.Error;

name: []const u8,
help: []const u8,
isMatchFn: *const fn ([]const u8) bool,
parseFn: *const fn (Allocator, []const []const u8) ParseError!Executable,

pub fn isMatch(self: Command, cmd: []const u8) bool {
    return self.isMatchFn(cmd);
}

pub fn parse(self: Command, allocator: Allocator, args: []const []const u8) ParseError!Executable {
    return self.parseFn(allocator, args);
}
