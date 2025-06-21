const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

const args = @import("../args.zig");
const Config = @import("../Config.zig");
const files = @import("../files.zig");
const Git = @import("../Git.zig");
const readUntilNewLineAlloc = @import("../reader_ext.zig").readUntilNewLineAlloc;
const string = @import("../string.zig");
const Tool = @import("../Tool.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");

const log = std.log.scoped(.use_cmd);
const Use = @This();

repository: []const u8,
install_name: ?[]const u8 = null,
is_multi_step: bool = false,
version: Git.Version = .default,

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    _ = ptr; // autofix
    _ = allocator; // autofix
    // const self: *Use = @ptrCast(@alignCast(ptr));

    // if (self.install_name) |name|
    //     allocator.free(name);

    // switch (self.version) {
    //     .branch => |b| allocator.free(b),
    //     .tag => |t| allocator.free(t),
    //     .default => {},
    // }
}

pub fn command() Command {
    return Command{
        .name = "install",
        .isMatchFn = isMatch,
        .parseFn = parse,
        .helpFn = help,
    };
}

pub fn help() []const u8 {
    return "TODO: Implement `Use` help message";
}

pub fn isMatch(cmd: []const u8) bool {
    return std.mem.eql(u8, cmd, "use");
}

pub fn parse(allocator: Allocator, arguments: []const []const u8) Command.ParseError!Executable {}

pub fn execute(ptr: *anyopaque, allocator: Allocator) !void {
    _ = allocator; // autofix

    const self: *Use = @ptrCast(@alignCast(ptr));
    log.info("Repository: {s}", .{self.repository});
    if (self.install_name) |name| {
        log.info("Install Name: {s}", .{name});
    } else {
        log.info("Install Name: null", .{});
    }
    log.info("IsMultiStep: {}", .{self.is_multi_step});
    // log.info("Version: {any}", .{self.version});
}
