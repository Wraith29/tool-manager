const std = @import("std");
const log = std.log.scoped(.arg_parser);
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Error = error{
    MissingRequiredArgument,
} || Allocator.Error || std.fmt.ParseIntError;

fn parseToType(comptime T: type, allocator: Allocator, arg: []const u8) Error!T {
    return switch (@typeInfo(T)) {
        .int => try std.fmt.parseInt(T, arg, 10),
        .pointer => {
            const buf = try allocator.alloc(u8, arg.len);
            @memcpy(buf, arg);

            return buf;
        },
        else => @compileError("unsupported type " ++ @typeName(T) ++ " expected []const u8 or int"),
    };
}

test "parseToType - integers" {
    inline for (&.{ u8, u32, u128, i8, i32, i128 }) |typ| {
        const expected: typ = 31;

        const actual = try parseToType(typ, std.testing.allocator, "31");

        try std.testing.expectEqual(expected, actual);
    }
}

test "parseToType - strings" {
    const expected = "my_string_value";
    const actual = try parseToType([]const u8, std.testing.allocator, "my_string_value");
    defer std.testing.allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

fn getNamedArgValue(allocator: Allocator, arg: []const u8, field_name: []const u8) Error!?[]const u8 {
    if (!std.mem.startsWith(u8, arg, "--"))
        return null;
    const eq_index = std.mem.indexOf(u8, arg, "=") orelse return null;

    const arg_name = arg[2..eq_index];
    if (!std.mem.eql(u8, arg_name, field_name))
        return null;

    const arg_value = arg[eq_index + 1 ..];

    const buf = try allocator.alloc(u8, arg_value.len);
    @memcpy(buf, arg_value);

    return buf;
}

test "getNamedArgValue - mismatched name returns null" {
    try std.testing.expectEqual(null, try getNamedArgValue(std.testing.allocator, "--argname_a=argvalue", "argname_b"));
}

test "getNamedArgValue - matched name returns value" {
    const expected = "result";
    const actual = try getNamedArgValue(std.testing.allocator, "--argname=result", "argname");
    defer if (actual) |act| std.testing.allocator.free(act);

    try std.testing.expect(actual != null);
    try std.testing.expectEqualStrings(expected, actual.?);
}

fn parseImpl(comptime T: type, allocator: Allocator, args: []const []const u8) Error!T {
    var positional_arg_count: usize = 0;
    var inst = T{};

    // Start at an index of 1 so that we skip the executable
    inline for (std.meta.fields(T), 1..) |field, index| {
        // Required Fields
        if (@typeInfo(field.type) != .optional) {
            positional_arg_count += 1;

            if (args.len <= index) {
                // TODO(@LoggingUpgrade)
                log.warn("Missing positional argument \"{s}\": {s}", .{ field.name, @typeName(field.type) });
                return Error.MissingRequiredArgument;
            }

            const field_value = try parseToType(field.type, allocator, args[index]);
            @field(inst, field.name) = field_value;
            continue;
        }

        // Non-required fields
        if (args.len <= positional_arg_count + 1) {
            log.info("No non-positional arguments found.", .{});
            break;
        }

        for (args[positional_arg_count + 1 ..]) |arg| {
            if (try getNamedArgValue(allocator, arg, field.name)) |raw_value| {
                defer allocator.free(raw_value);

                const value = try parseToType(@typeInfo(field.type).optional.child, allocator, raw_value);
                @field(inst, field.name) = value;
            }
        }
    }

    return inst;
}

test "parseImpl - maps all required fields" {
    const test_struct = struct {
        required_field: []const u8 = undefined,
        non_required_field: ?[]const u8 = null,
    };

    const expected = test_struct{
        .required_field = "required",
        .non_required_field = null,
    };

    const actual = try parseImpl(test_struct, std.testing.allocator, &.{ "exe_path", "required" });
    defer std.testing.allocator.free(actual.required_field);

    try std.testing.expectEqualDeep(expected, actual);
}

test "parseImpl - maps non-required fields" {
    const test_struct = struct {
        non_required_field: ?u8 = null,
    };

    const expected = test_struct{
        .non_required_field = 31,
    };

    const actual = try parseImpl(test_struct, std.testing.allocator, &.{ "exe_path", "--non_required_field=31" });

    try std.testing.expectEqualDeep(expected, actual);
}

/// This simply wraps `parseImpl` but passes in the process args. Saves the user having to allocate & free the args
/// While making the parse implementation nicely testable
pub fn parseInto(comptime T: type, allocator: Allocator) Error!T {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    return parseImpl(T, allocator, args);
}
