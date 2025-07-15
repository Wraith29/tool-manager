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

pub fn parseArgs(comptime T: type, allocator: Allocator, args: []const []const u8) Error!*T {
    if (!@hasDecl(T, "default"))
        @compileError(@typeName(T) ++ " must have a default function");

    var positional_arg_count: usize = 0;
    const inst = try allocator.create(T);
    inst.* = T.default();

    inline for (std.meta.fields(T), 0..) |field, index| {
        log.info("Checking {s}", .{field.name});
        // Required Fields
        if (@typeInfo(field.type) != .optional) {
            positional_arg_count += 1;

            if (args.len <= index) {
                // TODO(@LoggingUpgrade)
                log.warn("Missing positional argument \"{s}\": {s}", .{ field.name, @typeName(field.type) });
                return Error.MissingRequiredArgument;
            }

            const field_value = try parseToType(field.type, allocator, args[index]);
            @field(inst.*, field.name) = field_value;
            continue;
        }

        // Non-required fields
        if (args.len <= positional_arg_count) {
            log.info("No non-positional arguments found.", .{});
            break;
        }

        for (args[positional_arg_count..]) |arg| {
            if (try getNamedArgValue(allocator, arg, field.name)) |raw_value| {
                defer allocator.free(raw_value);

                const value = try parseToType(@typeInfo(field.type).optional.child, allocator, raw_value);
                @field(inst.*, field.name) = value;
            }
        }
    }
    return inst;
}

test "parseArgs - parses required fields into appropriate types" {
    const TestStruct = struct {
        required_str: []const u8 = undefined,
        required_int: u32 = undefined,

        fn default() @This() {
            return .{
                .required_str = undefined,
                .required_int = undefined,
            };
        }
    };

    const actual = try parseArgs(TestStruct, std.testing.allocator, &.{ "required_string", "128" });
    defer {
        std.testing.allocator.free(actual.required_str);
        std.testing.allocator.destroy(actual);
    }

    try std.testing.expectEqualStrings("required_string", actual.required_str);
    try std.testing.expectEqual(128, actual.required_int);
}

test "parseArgs - parses named fields into appropriate types" {
    const TestStruct = struct {
        opt_str: ?[]const u8 = null,
        opt_int: ?u32 = null,
        ign_str: ?[]const u8 = null,
        ign_int: ?u32 = null,

        fn default() @This() {
            return .{
                .opt_str = null,
                .opt_int = null,
                .ign_str = null,
                .ign_int = null,
            };
        }
    };

    const actual = try parseArgs(TestStruct, std.testing.allocator, &.{ "--opt_str=opt_str", "--opt_int=256" });
    defer {
        if (actual.opt_str) |str|
            std.testing.allocator.free(str);

        std.testing.allocator.destroy(actual);
    }

    try std.testing.expect(actual.opt_str != null);
    try std.testing.expectEqualStrings("opt_str", actual.opt_str.?);

    try std.testing.expect(actual.opt_int != null);
    try std.testing.expectEqual(256, actual.opt_int);

    try std.testing.expect(actual.ign_str == null);
    try std.testing.expect(actual.ign_int == null);
}
