const std = @import("std");

const git = @import("git.zig");

const Tool = @This();

name: []const u8,
repository: []const u8,
version: ?git.Version,
