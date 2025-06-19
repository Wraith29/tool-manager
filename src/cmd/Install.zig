const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Config = @import("../Config.zig");
const files = @import("../files.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");
const Tool = @import("../Tool.zig");
const string = @import("../string.zig");
const readUntilNewLineAlloc = @import("../reader_ext.zig").readUntilNewLineAlloc;

const log = std.log.scoped(.install_cmd);
const Install = @This();

tool_name: []const u8,

pub fn command() Command {
    return Command{
        .name = "install",
        .isMatchFn = isMatch,
        .parseFn = parse,
        .helpFn = help,
    };
}

pub fn help() []const u8 {
    return 
    \\install
    \\-------
    \\Install the given command
    \\
    \\Parameters:
    \\  tm install <name>
    \\
    \\
    ;
}

pub fn isMatch(cmd: []const u8) bool {
    if (std.mem.eql(u8, cmd, "install"))
        return true;

    if (std.mem.eql(u8, cmd, "inst"))
        return true;

    return false;
}

pub fn parse(args: []const []const u8) Command.ParseError!Executable {
    if (args.len < 3) {
        return Command.ParseError.MissingPositionalArgument;
    }

    var exe = Install{
        .tool_name = args[2],
    };

    return Executable{
        .ptr = &exe,
        .executeFn = execute,
    };
}

pub fn execute(ptr: *anyopaque, allocator: Allocator) !void {
    const self: *Install = @ptrCast(@alignCast(ptr));
    log.info("Gathering tool info for {s}", .{self.tool_name});

    const cfg = try Config.load(allocator);
    defer cfg.destroy(allocator);

    var writer = std.io.getStdOut().writer();
    const reader = std.io.getStdIn().reader();

    try writer.writeAll("Git Repository: ");
    const repo_link = try readUntilNewLineAlloc(allocator, reader, 1 << 12);
    defer allocator.free(repo_link);

    // Ensure we have been given a valid repo link
    _ = std.Uri.parse(repo_link) catch |err| {
        log.err("Invalid Repository Link: {!}", .{err});
        return error.InvalidRepositoryLink;
    };

    try writer.writeAll("Enter build steps in order:\n");

    var install_steps = ArrayList(*Tool.Step).init(allocator);
    defer {
        for (install_steps.items) |step| {
            allocator.free(step.name);
            for (step.args) |arg|
                allocator.free(arg);
            allocator.free(step.args);
            allocator.destroy(step);
        }

        install_steps.deinit();
    }

    while (true) {
        try writer.writeAll("Step Name: ");
        const step_name = try readUntilNewLineAlloc(allocator, reader, 16);

        if (string.isAllWhitespace(step_name)) {
            allocator.free(step_name);
            break;
        }

        try writer.writeAll("Step Command: ");
        const step_arguments = try readUntilNewLineAlloc(allocator, reader, 256);
        defer allocator.free(step_arguments);

        var step_arg_iter = std.mem.splitSequence(u8, step_arguments, " ");
        var step_command = ArrayList([]const u8).init(allocator);

        while (step_arg_iter.next()) |arg| {
            const arg_buf = try allocator.alloc(u8, arg.len);
            @memcpy(arg_buf, arg);
            try step_command.append(arg_buf);
            log.debug("Cmd Arg: '{s}'", .{arg_buf});
        }

        var next_step = try allocator.create(Tool.Step);
        next_step.name = step_name;
        next_step.args = try step_command.toOwnedSlice();

        try install_steps.append(next_step);
    }

    const tool = Tool{
        .name = self.tool_name,
        .repository = repo_link,
        .install_steps = install_steps.items,
    };

    try tool.install(allocator, cfg);
    try tool.save(allocator);
}
