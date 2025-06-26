const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const Thread = std.Thread;

const Config = @import("../Config.zig");
const files = @import("../files.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");
const Tool = @import("../Tool.zig");
const git = @import("../git.zig");
const args = @import("../args.zig");

const log = std.log.scoped(.update_cmd);
const Update = @This();

const help =
    \\tm update
    \\
    \\usage:
    \\  tm update [<tool>]
    \\  tm update [(<tool> --branch=<branch>)]
    \\  tm update [(<tool> --tag=<tag>)]
    \\
    \\options:
    \\  -h, --help        Show this message
    \\  tool              Pass in an optional tool name to only update that tool
    \\  --branch=<branch> Install the given branch of the tool, rather than the git default branch
    \\  --tag=<tag>       Install the given tag of the tool, rather than the git default branch
    \\
;

tool_name: ?[]const u8 = null,
version: ?git.Version = null,

pub fn command() Command {
    return Command{
        .name = "update",
        .help = help,
        .isMatchFn = isMatch,
        .parseFn = parse,
    };
}

pub fn isMatch(cmd: []const u8) bool {
    if (std.mem.eql(u8, cmd, "update"))
        return true;

    return std.mem.eql(u8, cmd, "up");
}

pub fn parse(allocator: Allocator, arguments: []const []const u8) Command.ParseError!Executable {
    var exe = try allocator.create(Update);

    exe.tool_name = if (arguments.len >= 3) blk: {
        const tool_name = try allocator.alloc(u8, arguments[2].len);
        @memcpy(tool_name, arguments[2]);

        break :blk tool_name;
    } else null;

    const branch = try args.flagValue(allocator, arguments, "--branch");
    const tag = try args.flagValue(allocator, arguments, "--tag");

    // The version can only be configured on an individual level
    if (exe.tool_name != null)
        exe.version = if (branch) |b|
            git.Version{ .branch = b }
        else if (tag) |t|
            git.Version{ .tag = t }
        else
            null
    else
        exe.version = null;

    return Executable{
        .ptr = exe,
        .deinitFn = deinit,
        .executeFn = execute,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Update = @ptrCast(@alignCast(ptr));

    if (self.tool_name) |tn| {
        allocator.free(tn);
    }

    if (self.version) |version| {
        switch (version) {
            .branch => |b| allocator.free(b),
            .tag => |t| allocator.free(t),
        }
    }

    allocator.destroy(self);
}

pub fn execute(ptr: *anyopaque, allocator: Allocator) !void {
    const self: *Update = @ptrCast(@alignCast(ptr));
    log.info("Self: {any}", .{self});

    if (self.tool_name) |tool_name| {
        log.info("Updating {s}", .{tool_name});
        return try self.updateSingleTool(allocator, tool_name);
    }

    log.info("Updating all tools", .{});
    try self.updateAllTools(allocator);
}

fn updateSingleTool(self: *Update, allocator: Allocator, tool_name: []const u8) !void {
    var tools = try Tool.loadAll(allocator);
    defer tools.deinit();

    const cfg = try Config.load(allocator);
    defer cfg.destroy(allocator);

    for (tools.value.map.keys()) |key| {
        const tool = tools.value.map.get(key) orelse unreachable;
        log.info("Checking {s}", .{tool.name});
        if (!std.mem.eql(u8, tool_name, tool.name)) {
            continue;
        }

        try tool.update(allocator, self.version, cfg);
        break;
    }
}

fn updateAllTools(_: *Update, allocator: Allocator) !void {
    var tools_parsed = try Tool.loadAll(allocator);
    defer tools_parsed.deinit();

    const tools = tools_parsed.value;

    const cfg = try Config.load(allocator);
    defer cfg.destroy(allocator);

    var stdout = std.io.getStdOut().writer();

    const keys = tools.map.keys();
    for (keys) |key| {
        try stdout.print("Updating {s}\n", .{key});

        const tool = tools.map.get(key) orelse {
            log.err("Unexpected error searching for {s}", .{key});
            unreachable;
        };

        try tool.update(allocator, null, cfg);
    }
}
