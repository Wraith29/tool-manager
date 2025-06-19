const std = @import("std");
const builtin = @import("builtin");
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

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

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
            if (std.mem.containsAtLeast(u8, arg, 1, "$")) {
                const ev_data = try getEnvVarName(allocator, arg);
                defer allocator.free(ev_data.name);
                log.debug("Looking for {s}", .{ev_data.name});

                const env_var = env_map.get(ev_data.name[1..]) orelse return error.EnvVarNotFound;
                log.debug("Expanded to {s}", .{env_var});

                const arg_expanded = try std.mem.replaceOwned(u8, allocator, arg, ev_data.name, env_var);
                try step_command.append(arg_expanded);
            } else {
                const arg_buf = try allocator.alloc(u8, arg.len);
                @memcpy(arg_buf, arg);
                try step_command.append(arg_buf);
            }
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

fn getEnvVarName(allocator: Allocator, str: []const u8) !struct { name: []const u8, start: usize, end: usize } {
    switch (builtin.target.os.tag) {
        .windows => {
            return error.NotImplemented;
        },
        else => {
            const start_idx = std.mem.indexOf(u8, str, "$") orelse return error.InvalidEnvVar;

            var idx: usize = start_idx;
            var env_var_name = ArrayList(u8).init(allocator);

            while (idx < str.len) : (idx += 1) {
                const chr = str[idx];
                if (!std.ascii.isAlphanumeric(chr) and chr != '$')
                    break;

                try env_var_name.append(chr);
            }

            return .{
                .name = try env_var_name.toOwnedSlice(),
                .start = start_idx,
                .end = idx,
            };
        },
    }
}
