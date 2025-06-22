const std = @import("std");
const log = std.log.scoped(.git);
const Allocator = std.mem.Allocator;
const Child = std.process.Child;

pub const Version = union(enum) {
    default: void,
    branch: []const u8,
    tag: []const u8,
};

pub fn clone(
    allocator: Allocator,
    repository: []const u8,
    path: []const u8,
    version: Version,
) !void {
    const argv: []const []const u8 = switch (version) {
        .default => &.{ "git", "clone", repository, path, "--quiet" },
        .branch => |b| &.{ "git", "clone", repository, path, "--quiet", "--branch", b },
        .tag => &.{ "git", "clone", repository, path, "--quiet", "--tags" },
    };

    const result = try Child.run(.{
        .allocator = allocator,
        .argv = argv,
    });
    defer freeResult(allocator, result);

    if (result.term.Exited != 0) {
        log.err("Clone Failed: {s}", .{result.stderr});
        return error.CloneFailed;
    }

    if (version == .tag)
        try checkoutTag(allocator, path, version.tag);
}

pub fn checkoutBranch(allocator: Allocator, path: []const u8, branch_name: []const u8) !void {
    const result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "checkout", branch_name },
        .cwd = path,
    });
    defer freeResult(allocator, result);

    if (result.term.Exited != 0) {
        log.err("Branch Checkout Failed: {s}", .{result.stderr});
        return error.CheckoutFailed;
    }
}

pub fn checkoutTag(allocator: Allocator, path: []const u8, tag_name: []const u8) !void {
    const tag_str = try std.mem.concat(allocator, u8, &.{ "tags/", tag_name });
    defer allocator.free(tag_str);

    const result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "checkout", tag_str },
        .cwd = path,
    });
    defer freeResult(allocator, result);

    if (result.term.Exited != 0) {
        log.err("Checkout Failed: {s}", .{result.stderr});
        return error.CheckoutFailed;
    }
}

/// A true response means that there were changes to fetch
pub fn fetch(
    allocator: Allocator,
    path: []const u8,
) !bool {
    const result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "fetch" },
        .cwd = path,
    });
    defer freeResult(allocator, result);

    if (result.term.Exited != 0) {
        log.err("Fetch Failed: {s}", .{result.stderr});
        return error.FetchFailed;
    }

    return result.stdout.len != 0;
}

pub fn pull(
    allocator: Allocator,
    path: []const u8,
) !void {
    const result = try Child.run(.{
        .allocator = allocator,
        .argv = &.{ "git", "pull" },
        .cwd = path,
    });
    defer freeResult(allocator, result);

    if (result.term.Exited != 0) {
        log.err("Pull Failed: {s}", .{result.stderr});
        return error.PullFailed;
    }
}

fn freeResult(allocator: Allocator, result: Child.RunResult) void {
    allocator.free(result.stderr);
    allocator.free(result.stdout);
}
