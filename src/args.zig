const std = @import("std");
const Allocator = std.mem.Allocator;
const Command = @import("cmd/Command.zig");

pub fn flagValue(
    allocator: Allocator,
    args: []const []const u8,
    flag_name: []const u8,
) Command.ParseError!?[]const u8 {
    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, flag_name)) {
            const eq_index = std.mem.indexOf(u8, arg, "=") orelse return Command.ParseError.InvalidFlag;

            const value_buf = try allocator.alloc(u8, arg.len - eq_index - 1);
            @memcpy(value_buf, arg[eq_index + 1 ..]);

            return value_buf;
        }
    }

    return null;
}

test "flagValue - returns null if flag not present" {
    const args = [_][]const u8{ "tm", "use", "my_repository_link" };
    const result = try flagValue(std.testing.allocator, &args, "--my-flag");

    try std.testing.expectEqual(null, result);
}

test "flagValue - returns error if flag is present but not value" {
    const args = [_][]const u8{ "tm", "use", "my_repository_link", "--flag" };
    const result = flagValue(std.testing.allocator, &args, "--flag");

    try std.testing.expectError(Command.ParseError.InvalidFlag, result);
}

test "flagValue - returns flag value if present" {
    const args = [_][]const u8{ "tm", "use", "my_repository_link", "--name=my_install_name" };
    const result = try flagValue(std.testing.allocator, &args, "--name");
    defer std.testing.allocator.free(result.?);

    try std.testing.expectEqualDeep("my_install_name", result);
}

pub fn hasFlag(args: []const []const u8, flag: []const u8) bool {
    for (args) |arg| {
        if (std.mem.eql(u8, arg, flag))
            return true;
    }

    return false;
}

test "hasFlag - flag not present" {
    const args = [_][]const u8{ "tm", "use", "my_repository_link" };
    const result = hasFlag(&args, "--multi-step");

    try std.testing.expect(!result);
}

test "hasFlag - flag present" {
    const args = [_][]const u8{ "tm", "use", "my_repository_link", "--multi-step" };
    const result = hasFlag(&args, "--multi-step");
    try std.testing.expect(result);
}
