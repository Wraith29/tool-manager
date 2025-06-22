const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

const Config = @import("../Config.zig");
const files = @import("../files.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");
const string = @import("../string.zig");
const readUntilNewLineAlloc = @import("../reader_ext.zig").readUntilNewLineAlloc;

const log = std.log.scoped(.init_cmd);
const Init = @This();

const help =
    \\tm init
    \\  initialise the tool-manager, setting up the config
    \\
    \\usage:
    \\  tm init
    \\
    \\options:
    \\  -h, --help    Show this message
;

pub fn command() Command {
    return Command{
        .name = "init",
        .help = help,
        .isMatchFn = isMatch,
        .parseFn = parse,
    };
}

pub fn isMatch(cmd: []const u8) bool {
    return std.mem.eql(u8, cmd, "init");
}

pub fn parse(_: Allocator, _: []const []const u8) !Executable {
    var self = Init{};

    return Executable{
        .ptr = &self,
        .executeFn = execute,
        .deinitFn = deinit,
    };
}

pub fn deinit(_: *anyopaque, _: Allocator) void {}

pub fn execute(_: *anyopaque, allocator: Allocator) !void {
    if (!files.pathExists(files.app_data_dir)) {
        try std.fs.makeDirAbsolute(files.app_data_dir);
    }

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.writeAll("Tool Installation Directory [Default: $HOME/tools]: ");
    const response = try readUntilNewLineAlloc(allocator, stdin, std.fs.max_path_bytes + 1);
    log.debug("Response Length: {d}, Response: {s}", .{ response.len, response });

    const install_directory = if (string.isAllWhitespace(response)) id_blk: {
        log.info("No Custom Directory Provided. Calculating Default", .{});
        allocator.free(response);

        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();

        const home_env_var = switch (builtin.target.os.tag) {
            .windows => "USERPROFILE",
            else => "HOME",
        };

        const home_dir = env_map.get(home_env_var) orelse {
            log.err("Missing required Environment Variable: ${s}", .{home_env_var});
            return error.MissingEnvironmentVariable;
        };
        log.info("Using Home Directory: {s}", .{home_dir});

        break :id_blk try std.fs.path.join(allocator, &.{ home_dir, "tools" });
    } else response;
    defer allocator.free(install_directory);

    log.info("Using Install Dir: {s}", .{install_directory});

    if (!files.pathExists(install_directory)) {
        try std.fs.makeDirAbsolute(install_directory);
    }

    const cfg = Config{
        .install_directory = install_directory,
    };

    const cfg_json = try std.json.stringifyAlloc(allocator, cfg, .{ .whitespace = .indent_4 });
    defer allocator.free(cfg_json);

    const cfg_fp = try std.fs.path.join(allocator, &.{ files.app_data_dir, "config.json" });
    defer allocator.free(cfg_fp);

    log.info("Creating Config file @ {s}", .{cfg_fp});
    try files.createFileWithContents(cfg_fp, cfg_json);

    const tools_fp = try std.fs.path.join(allocator, &.{ files.app_data_dir, "tools.json" });
    defer allocator.free(tools_fp);

    log.info("Creating Tools file @ {s}", .{tools_fp});
    try files.createFileWithContents(tools_fp, "[]");
}
