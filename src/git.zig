const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Child = std.process.Child;
const log = std.log.scoped(.git);

const Config = @import("Config.zig");
const string = @import("string.zig");

const Error = error{
    CheckoutFailed,
    CloneFailed,
    FetchFailed,
    GetBranchNameFailed,
    PullFailed,
} || Allocator.Error || Child.RunError;

pub const Version = union(enum) {
    branch: []const u8,
    tag: []const u8,

    pub fn deinit(self: *Version, allocator: Allocator) void {
        switch (self.*) {
            .branch => |b| allocator.free(b),
            .tag => |t| allocator.free(t),
        }
    }
};

pub fn clone(
    allocator: Allocator,
    cfg: *const Config,
    repository: []const u8,
    name: []const u8,
    version: ?Version,
) Error!?Version {
    const tool_src_dir = try std.fs.path.join(allocator, &.{ cfg.tool_path, "src" });
    defer allocator.free(tool_src_dir);

    const tool_install_dir = try std.fs.path.join(allocator, &.{ tool_src_dir, name });
    defer allocator.free(tool_install_dir);

    const clone_cmd = try getCloneCommand(allocator, repository, tool_install_dir, version);
    defer {
        for (clone_cmd) |arg| allocator.free(arg);
        allocator.free(clone_cmd);
    }

    const result = try Child.run(.{
        .allocator = allocator,
        .argv = clone_cmd,
        .cwd = tool_src_dir,
    });
    defer freeRunResult(allocator, result);

    if (result.term.Exited != 0) {
        log.err("{s}: failed to clone repository: {s}", .{ name, result.stderr });
        return Error.CloneFailed;
    }

    if (version) |v| {
        if (v == .tag)
            try checkoutTag(allocator, name, tool_install_dir, v.tag);
    } else return .{ .branch = try getBranchName(allocator, name, tool_install_dir) };

    return null;
}

pub fn fetch(allocator: Allocator, cfg: *const Config, name: []const u8) Error!bool {
    const tool_install_dir = try std.fs.path.join(allocator, &.{ cfg.tool_path, "src", name });
    defer allocator.free(tool_install_dir);

    const result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "fetch" },
        .cwd = tool_install_dir,
    });
    defer freeRunResult(allocator, result);

    if (result.term.Exited != 0) {
        log.err("{s}: fetch failed: {s}", .{ name, result.stder });
        return Error.FetchFailed;
    }

    return result.stdout.len != 0;
}

pub fn pull(allocator: Allocator, cfg: *const Config, name: []const u8) Error!void {
    const tool_install_dir = try std.fs.path.join(allocator, &.{ cfg.tool_path, "src", name });
    defer allocator.free(tool_install_dir);

    const result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "pull" },
        .cwd = tool_install_dir,
    });
    defer freeRunResult(allocator, result);

    if (result.term.Exited != 0) {
        log.err("{s}: pull failed: {s}", .{ name, result.stderr });
        return Error.PullFailed;
    }
}

fn getCloneCommand(
    allocator: Allocator,
    repository: []const u8,
    install_path: []const u8,
    version: ?Version,
) Error![]const []const u8 {
    var cmd = ArrayList([]const u8).init(allocator);

    try cmd.appendSlice(&.{
        try string.copy(allocator, "git"),
        try string.copy(allocator, "clone"),
        try string.copy(allocator, "--quiet"),
        try string.copy(allocator, repository),
        try string.copy(allocator, install_path),
    });

    if (version) |v| {
        switch (v) {
            .branch => |b| try cmd.appendSlice(&.{
                try string.copy(allocator, "--branch"),
                try string.copy(allocator, b),
            }),
            .tag => try cmd.append(try string.copy(allocator, "--tags")),
        }
    }

    return try cmd.toOwnedSlice();
}

fn checkoutTag(allocator: Allocator, name: []const u8, tool_path: []const u8, tag_name: []const u8) Error!void {
    const result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "checkout", tag_name },
        .cwd = tool_path,
    });
    defer freeRunResult(allocator, result);

    if (result.term.Exited != 0) {
        log.err("{s}: failed to checkout tag {s}: {s}", .{ name, tag_name, result.stderr });
        return Error.CheckoutFailed;
    }
}

fn getSrcPath(allocator: Allocator, cfg: *const Config, name: []const u8) Error![]const u8 {
    return try std.fs.path.join(
        allocator,
        &.{ cfg.tool_path, "src", name },
    );
}

fn getBranchName(allocator: Allocator, name: []const u8, repo_path: []const u8) Error![]const u8 {
    const result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "branch", "--show-current" },
        .cwd = repo_path,
    });
    defer freeRunResult(allocator, result);

    if (result.term.Exited != 0) {
        log.err("{s}: Failed to get branch name: {s}", .{ name, result.stderr });
        return Error.GetBranchNameFailed;
    }

    const buf = try allocator.alloc(u8, result.stdout.len - 1);
    @memcpy(buf, result.stdout[0 .. result.stdout.len - 1]);

    return buf;
}

fn freeRunResult(allocator: Allocator, result: Child.RunResult) void {
    allocator.free(result.stderr);
    allocator.free(result.stdout);
}
