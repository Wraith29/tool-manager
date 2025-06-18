const std = @import("std");
const Allocator = std.mem.Allocator;

const Config = @import("../Config.zig");
const files = @import("../files.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");

const log = std.log.scoped(.init_cmd);
const Init = @This();

pub fn command() Command {
    return Command{
        .name = "init",
        .isMatchFn = isMatch,
        .parseFn = parse,
        .helpFn = help,
    };
}

pub fn help() []const u8 {
    return 
    \\ init
    \\ ----
    \\ Initialise the tool manager.
    ;
}

pub fn isMatch(cmd: []const u8) bool {
    return std.mem.eql(u8, cmd, "init");
}

pub fn parse(_: []const []const u8) !Executable {
    var self = Init{};

    return Executable{
        .ptr = &self,
        .executeFn = execute,
    };
}

pub fn execute(_: *anyopaque, allocator: Allocator) !void {
    if (!files.pathExists(files.app_data_dir)) {
        try std.fs.makeDirAbsolute(files.app_data_dir);
    }

    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    try stdout.writeAll("Tool Installation Directory [Default: $HOME/tools]: ");
    const response = try stdin.readUntilDelimiterAlloc(allocator, '\n', std.fs.max_path_bytes + 1);

    const install_directory = if (response.len == 0) id_blk: {
        allocator.free(response);

        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();

        const home_dir = env_map.get("HOME") orelse {
            log.err("Missing required Environment Variable: $HOME", .{});
            return error.MissingEnvironmentVariable;
        };

        break :id_blk try std.mem.concat(allocator, u8, &.{ home_dir, std.fs.path.sep_str, "tools" });
    } else response;

    defer allocator.free(install_directory);

    if (!files.pathExists(install_directory)) {
        try std.fs.makeDirAbsolute(install_directory);
    }

    const cfg = Config{
        .install_directory = install_directory,
    };

    const cfg_json = try std.json.stringifyAlloc(allocator, cfg, .{ .whitespace = .indent_4 });
    defer allocator.free(cfg_json);

    const cfg_fp = try std.mem.concat(allocator, u8, &.{ files.app_data_dir, std.fs.path.sep_str, "config.json" });
    defer allocator.free(cfg_fp);

    log.info("Creating Config file @ {s}", .{cfg_fp});
    try files.createFileWithContents(cfg_fp, cfg_json);

    const tools_fp = try std.mem.concat(allocator, u8, &.{ files.app_data_dir, std.fs.path.sep_str, "tools.json" });
    defer allocator.free(tools_fp);

    log.info("Creating Tools file @ {s}", .{tools_fp});
    try files.createFileWithContents(tools_fp, "[]");
}
