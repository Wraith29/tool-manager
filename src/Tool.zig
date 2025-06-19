const std = @import("std");
const log = std.log.scoped(.tool);
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Child = std.process.Child;

const files = @import("files.zig");
const Config = @import("Config.zig");

const Tool = @This();

pub const Step = struct {
    name: []const u8,
    args: []const []const u8,
};

name: []const u8,
repository: []const u8,
install_steps: []*Step,

fn getToolPath(self: *const Tool, allocator: Allocator, cfg: *const Config) ![]const u8 {
    return try std.fs.path.join(allocator, &.{ cfg.install_directory, self.name });
}

pub fn install(self: *const Tool, allocator: Allocator, cfg: *const Config) !void {
    log.info("Installing {s}", .{self.name});
    const tool_path = try self.getToolPath(allocator, cfg);
    defer allocator.free(tool_path);

    log.info("Searching for {s} @ {s}", .{ self.name, tool_path });
    if (!files.pathExists(tool_path)) {
        log.info("{s} not found. Downloading", .{self.name});
        try self.downloadRepository(allocator, tool_path);
    } else {
        log.info("{s} found. Updating to latest version", .{self.name});
        try self.updateRepository(allocator, tool_path);
    }

    log.info("{s} is at the latest version. Rebuilding", .{self.name});
    try self.build(allocator, tool_path);
}

fn downloadRepository(
    self: *const Tool,
    allocator: Allocator,
    tool_path: []const u8,
) !void {
    const clone_result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "clone", self.repository, tool_path, "--quiet" },
    });
    defer freeChildResult(clone_result, allocator);

    if (clone_result.term.Exited != 0) {
        log.err("{s}: Failed to clone repository: {d}, {s}", .{ self.name, clone_result.term.Exited, clone_result.stderr });
        return error.DownloadFailed;
    }
}

fn updateRepository(
    self: *const Tool,
    allocator: Allocator,
    tool_path: []const u8,
) !void {
    const fetch_result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "fetch" },
        .cwd = tool_path,
    });
    defer freeChildResult(fetch_result, allocator);

    if (fetch_result.term.Exited != 0) {
        log.err("{s}: Failed to fetch repository: {d}, {s}", .{ self.name, fetch_result.term.Exited, fetch_result.stderr });
        return error.FetchFailed;
    }

    if (fetch_result.stdout.len == 0) {
        log.info("{s}: No changes to fetch.", .{self.name});
        return;
    }

    const pull_result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "pull" },
        .cwd = tool_path,
    });
    defer freeChildResult(pull_result, allocator);

    if (pull_result.term.Exited != 0) {
        log.err("{s}: Failed to pull repository: {d}, {s}", .{ self.name, pull_result.term.Exited, pull_result.stderr });
        return error.PullFailed;
    }
}

fn build(
    self: *const Tool,
    allocator: Allocator,
    tool_path: []const u8,
) !void {
    for (self.install_steps) |step| {
        const tmp = try std.mem.join(allocator, " ", step.args);
        defer allocator.free(tmp);

        std.debug.print("\n\nExecuting Command: '{s}'\n\n", .{tmp});

        log.info("{s}: Running {s} -> {s}", .{ self.name, step.name, tmp });

        const cmd = try Child.run(.{
            .allocator = allocator,
            .argv = step.args,
            .cwd = tool_path,
        });
        defer freeChildResult(cmd, allocator);

        if (cmd.term.Exited != 0) {
            log.err(
                "{s} - {s}: Unsuccessful Exit Code: {d}, {s}",
                .{ self.name, step.name, cmd.term.Exited, cmd.stderr },
            );
            return error.InstallStepFailed;
        }
    }

    log.info("{s}: Succesfully Installed", .{self.name});
}

pub fn save(self: *const Tool, allocator: Allocator) !void {
    const tool_fp = try std.fs.path.join(allocator, &.{ files.app_data_dir, "tools.json" });
    defer allocator.free(tool_fp);

    if (!files.pathExists(tool_fp)) {
        return error.FileNotFound;
    }

    var tool_file = try std.fs.openFileAbsolute(tool_fp, .{ .mode = .read_write });
    defer tool_file.close();

    const tools_contents = try tool_file.readToEndAlloc(allocator, 1 << 16);
    defer allocator.free(tools_contents);

    const tools_json = try std.json.parseFromSlice([]*const Tool, allocator, tools_contents, .{ .allocate = .alloc_always });
    defer tools_json.deinit();

    var tools_array = try ArrayListUnmanaged(*const Tool).initCapacity(allocator, tools_json.value.len + 1);
    defer tools_array.deinit(allocator);

    try tools_array.appendSlice(allocator, tools_json.value);
    try tools_array.append(allocator, self);

    const new_contents = try std.json.stringifyAlloc(allocator, tools_array.items, .{ .whitespace = .indent_4 });
    defer allocator.free(new_contents);

    try tool_file.seekTo(0);
    try tool_file.writeAll(new_contents);
}

pub fn loadAll(allocator: Allocator) !std.json.Parsed([]*const Tool) {
    const tool_fp = try std.fs.path.join(allocator, &.{ files.app_data_dir, "tools.json" });
    defer allocator.free(tool_fp);

    if (!files.pathExists(tool_fp)) {
        return error.FileNotFound;
    }

    var tool_file = try std.fs.openFileAbsolute(tool_fp, .{ .mode = .read_write });
    defer tool_file.close();

    const tools_contents = try tool_file.readToEndAlloc(allocator, 1 << 16);
    defer allocator.free(tools_contents);

    return try std.json.parseFromSlice([]*const Tool, allocator, tools_contents, .{ .allocate = .alloc_always });
}

fn freeChildResult(result: std.process.Child.RunResult, allocator: Allocator) void {
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}
