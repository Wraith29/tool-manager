const std = @import("std");
const log = std.log.scoped(.tool);
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Child = std.process.Child;

const files = @import("files.zig");
const Config = @import("Config.zig");
const Git = @import("Git.zig");

const Tool = @This();

pub const Step = struct {
    name: []const u8,
    args: []const []const u8,
};

name: []const u8,
repository: []const u8,
install_steps: []*Step,
version: Git.Version,

fn getToolPath(self: *const Tool, allocator: Allocator, cfg: *const Config) ![]const u8 {
    return try std.fs.path.join(allocator, &.{ cfg.install_directory, self.name });
}

pub fn install(self: *const Tool, allocator: Allocator, cfg: *const Config) !void {
    log.info("Installing {s}", .{self.name});
    const tool_path = try self.getToolPath(allocator, cfg);
    defer allocator.free(tool_path);

    log.info("Searching for {s} @ {s}", .{ self.name, tool_path });

    if (files.pathExists(tool_path)) {
        log.info("{s} found @ {s}", .{ self.name, tool_path });
        const updates_found = try Git.fetch(allocator, tool_path);
        if (updates_found) {
            log.info("{s} has changes to pull", .{self.name});
            try Git.pull(allocator, tool_path);
        }
        log.info("{s} is at latest version", .{self.name});
    } else {
        log.info("{s} not found. Cloning into {s}", .{ self.name, tool_path });
        try Git.clone(allocator, self.repository, tool_path, self.version);
        log.info("{s} cloned into {s}", .{ self.name, tool_path });
    }

    try self.build(allocator, tool_path);
}

pub fn update(self: *const Tool, allocator: Allocator, new_version: ?Git.Version, cfg: *const Config) !void {
    const tool_path = try self.getToolPath(allocator, cfg);
    defer allocator.free(tool_path);

    if (!files.pathExists(tool_path)) {
        log.err("{s} was not found at expected location ({s})", .{ self.name, tool_path });
        return error.ToolNotFound;
    }

    _ = try Git.fetch(allocator, tool_path);

    if (new_version) |version| {
        switch (version) {
            .default => {},
            .branch => |b| try Git.checkoutBranch(allocator, tool_path, b),
            .tag => |t| try Git.checkoutTag(allocator, tool_path, t),
        }
    }

    try Git.pull(allocator, tool_path);

    try self.build(allocator, tool_path);
}

fn build(
    self: *const Tool,
    allocator: Allocator,
    tool_path: []const u8,
) !void {
    for (self.install_steps) |step| {
        log.info("{s} running {s}", .{ self.name, step.name });

        const tmp = try std.mem.join(allocator, " ", step.args);
        defer allocator.free(tmp);

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
