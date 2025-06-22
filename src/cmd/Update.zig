const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

const Config = @import("../Config.zig");
const files = @import("../files.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");
const Tool = @import("../Tool.zig");
const Git = @import("../Git.zig");
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
;

tool_name: ?[]const u8 = null,
version: ?Git.Version = null,

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

    if (arguments.len > 2) {
        const tool_name = try allocator.alloc(u8, arguments[2].len);
        @memcpy(tool_name, arguments[2]);

        exe.tool_name = tool_name;
    }

    const branch = try args.flagValue(allocator, arguments, "--branch");
    const tag = try args.flagValue(allocator, arguments, "--tag");

    exe.version = if (branch) |b|
        Git.Version{ .branch = b }
    else if (tag) |t|
        Git.Version{ .tag = t }
    else
        null;

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

    allocator.destroy(self);
}

pub fn execute(ptr: *anyopaque, allocator: Allocator) !void {
    const self: *Update = @ptrCast(@alignCast(ptr));

    if (self.tool_name != null) {
        return try self.updateSingleTool(allocator);
    }

    try self.updateAllTools(allocator);
}

fn updateSingleTool(self: *Update, allocator: Allocator) !void {
    const tools = try Tool.loadAll(allocator);
    defer tools.deinit();

    const cfg = try Config.load(allocator);
    defer cfg.destroy(allocator);

    const selected_tool = self.tool_name.?;

    for (tools.value) |tool| {
        if (!std.mem.eql(u8, selected_tool, tool.name)) {
            continue;
        }

        try tool.update(allocator, self.version, cfg);
    }
}

fn updateAllTools(self: *Update, allocator: Allocator) !void {
    _ = self;
    _ = allocator;

    log.info("Not Implemented", .{});
}
