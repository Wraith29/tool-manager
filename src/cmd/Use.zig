const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");

const args = @import("../args.zig");
const Config = @import("../Config.zig");
const files = @import("../files.zig");
const git = @import("../git.zig");
const readUntilNewLineAlloc = @import("../reader_ext.zig").readUntilNewLineAlloc;
const string = @import("../string.zig");
const Tool = @import("../Tool.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");

const log = std.log.scoped(.use_cmd);
const Use = @This();

const help =
    \\tm use
    \\  Install the given tool
    \\
    \\usage:
    \\  tm use <repository> [--name=<tool_name>] [--multi-step] [--branch=<branch>|--tag=<tag>]
    \\
    \\options:
    \\  -h, --help        Show this message
    \\  --name=<name>     Install the given tool under a specified name, rather than the name of the repository
    \\                    (Note: this does not effect the binary name, that is determined by the tool)
    \\  --multi-step      Allow the tool to have a multi-step installation process (i.e. if dependencies are required to be installed)
    \\  --branch=<branch> Install the given branch of the tool, rather than the git default branch
    \\  --tag=<tag>       Install the given tag of the tool, rather than the git default branch
    \\
;

repository: []const u8,
tool_name: ?[]const u8 = null,
is_multi_step: bool = false,
version: ?git.Version = null,

pub fn command() Command {
    return Command{
        .name = "install",
        .help = help,
        .isMatchFn = isMatch,
        .parseFn = parse,
    };
}

pub fn isMatch(cmd: []const u8) bool {
    return std.mem.eql(u8, cmd, "use");
}

pub fn parse(allocator: Allocator, arguments: []const []const u8) Command.ParseError!Executable {
    if (arguments.len < 3) {
        log.err("Missing required positional argument: <repository>", .{});
        return Command.ParseError.MissingPositionalArgument;
    }

    _ = std.Uri.parse(arguments[2]) catch |err| {
        log.err("Invalid git link: {!}", .{err});
        return error.InvalidArgument;
    };

    var exe = try allocator.create(Use);
    exe.repository = arguments[2];
    exe.tool_name = try args.flagValue(allocator, arguments, "--name");
    exe.is_multi_step = args.hasFlag(arguments, "--multi-step");

    const branch = try args.flagValue(allocator, arguments, "--branch");
    const tag = try args.flagValue(allocator, arguments, "--tag");

    exe.version = if (branch) |b|
        git.Version{ .branch = b }
    else if (tag) |t|
        git.Version{ .tag = t }
    else
        null;

    return Executable{
        .ptr = exe,
        .executeFn = execute,
        .deinitFn = deinit,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Use = @ptrCast(@alignCast(ptr));

    if (self.tool_name) |tool_name|
        allocator.free(tool_name);

    if (self.version) |v|
        switch (v) {
            .branch => |b| allocator.free(b),
            .tag => |t| allocator.free(t),
        };

    allocator.destroy(self);
}

pub fn execute(ptr: *anyopaque, allocator: Allocator) !void {
    const self: *Use = @ptrCast(@alignCast(ptr));

    log.info("Repository: {s}", .{self.repository});

    const tool_name = if (self.tool_name) |tn|
        tn
    else
        try getInstallName(allocator, self.repository);

    defer if (self.tool_name == null) allocator.free(tool_name);

    log.info("ToolName: {?s}", .{tool_name});
    log.info("IsMultiStep: {}", .{self.is_multi_step});
    log.info("Version: {any}", .{self.version});

    var install_steps = ArrayList(*Tool.Step).init(allocator);
    defer {
        for (install_steps.items) |step| {
            allocator.free(step.name);
            for (step.args) |arg| {
                allocator.free(arg);
            }

            allocator.free(step.args);
            allocator.destroy(step);
        }

        install_steps.deinit();
    }

    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    if (self.is_multi_step) {
        while (try getInstallStep(allocator, &env_map)) |step|
            try install_steps.append(step);
    } else {
        const step = try getInstallStep(allocator, &env_map);
        if (step == null) {
            log.err("Expected an installation step", .{});
            return error.InvalidInstallStep;
        }

        try install_steps.append(step.?);
    }

    var tool = Tool{
        .repository = self.repository,
        .name = tool_name,
        .version = self.version,
        .install_steps = install_steps.items,
        .updated_at = std.time.timestamp(),
    };

    var cfg = try Config.load(allocator);
    defer cfg.destroy(allocator);

    try tool.install(allocator, cfg);
    log.info("Version (PostInstall): {?any}", .{tool.version});

    defer if (self.version == null) {
        if (tool.version) |v| {
            switch (v) {
                .branch => |b| allocator.free(b),
                .tag => |t| allocator.free(t),
            }
        }
    };

    try tool.save(allocator);
}

fn getInstallName(allocator: Allocator, repository: []const u8) ![]const u8 {
    const last_slash = std.mem.lastIndexOf(u8, repository, "/") orelse return error.InvalidArgument;

    if (std.mem.endsWith(u8, repository, ".git")) {
        const tool_name = try allocator.alloc(u8, repository.len - last_slash - 5);
        @memcpy(tool_name, repository[last_slash + 1 .. repository.len - 4]);

        return tool_name;
    }

    const tool_name = try allocator.alloc(u8, repository.len - last_slash - 1);
    @memcpy(tool_name, repository[last_slash + 1 ..]);

    return tool_name;
}

fn getInstallStep(allocator: Allocator, env_map: *const std.process.EnvMap) !?*Tool.Step {
    var writer = std.io.getStdOut().writer();
    const reader = std.io.getStdIn().reader();

    try writer.writeAll("Step Name: ");
    const step_name = try readUntilNewLineAlloc(allocator, reader, 16);
    errdefer allocator.free(step_name);

    if (string.isAllWhitespace(step_name))
        return null;

    try writer.writeAll("Step Command: ");
    const step_cmd = try readUntilNewLineAlloc(allocator, reader, 256);
    defer allocator.free(step_cmd);

    var step_args = ArrayList([]const u8).init(allocator);
    errdefer step_args.deinit();
    var arg_iter = std.mem.splitSequence(u8, step_cmd, " ");

    while (arg_iter.next()) |arg| {
        if (std.mem.containsAtLeast(u8, arg, 1, "$")) {
            const ev_data = try getEnvVarName(allocator, arg);
            defer allocator.free(ev_data.name);
            log.debug("Looking for {s}", .{ev_data.name});

            const env_var = env_map.get(ev_data.name[1..]) orelse return error.EnvVarNotFound;
            log.debug("Expanded to {s}", .{env_var});

            const arg_expanded = try std.mem.replaceOwned(u8, allocator, arg, ev_data.name, env_var);
            try step_args.append(arg_expanded);
        } else {
            const buf = try allocator.alloc(u8, arg.len);
            @memcpy(buf, arg);

            try step_args.append(buf);
        }
    }

    var step = try allocator.create(Tool.Step);

    step.name = step_name;
    step.args = try step_args.toOwnedSlice();

    return step;
}

fn getEnvVarName(allocator: Allocator, str: []const u8) !struct { name: []const u8, start: usize, end: usize } {
    return switch (builtin.target.os.tag) {
        .windows => error.NotImplemented,
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
    };
}
