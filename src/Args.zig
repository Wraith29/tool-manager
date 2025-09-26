const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const string = @import("string.zig");

const Args = @This();

pub const Error = error{MissingPositionalArgument};

args: []const []const u8,
index: usize,

pub fn init(allocator: Allocator) !Args {
    var iter = try std.process.argsWithAllocator(allocator);
    defer iter.deinit();
    var args = ArrayList([]const u8){};
    errdefer {
        for (args.items) |arg| {
            allocator.free(arg);
        }
        args.deinit(allocator);
    }

    while (iter.next()) |arg| {
        try args.append(allocator, try string.copy(allocator, arg));
    }

    return Args{
        .args = try args.toOwnedSlice(allocator),
        .index = 0,
    };
}

pub fn deinit(self: *Args, allocator: Allocator) void {
    for (self.args) |arg| {
        allocator.free(arg);
    }

    allocator.free(self.args);
}

pub fn next(self: *Args) ?[]const u8 {
    if (self.index >= self.args.len)
        return null;

    defer self.index += 1;
    return self.args[self.index];
}

pub fn skip(self: *Args) ?void {
    if (self.index >= self.args.len)
        return null;

    defer self.index += 1;
    return;
}

pub fn remaining(self: *Args) []const []const u8 {
    if (self.index >= self.args.len)
        return &.{};

    defer self.index = self.args.len - 1;
    return self.args[self.index..];
}

fn validateType(comptime T: type) void {
    if (!@hasDecl(T, "default"))
        @compileError("invalid type '" ++ @typeName(T) ++ "' missing required method 'default'");
}

fn getPositionalArgumentCount(comptime T: type) usize {
    var result: usize = 0;

    inline for (std.meta.fields(T)) |field| {
        switch (@typeInfo(field.type)) {
            .optional => {},
            else => result += 1,
        }
    }

    return result;
}

fn convertInto(comptime T: type, allocator: Allocator, str: []const u8) !T {
    return switch (@typeInfo(T)) {
        .int => try std.fmt.parseInt(T, str, 10),
        .pointer => try string.copy(allocator, str),
        else => @compileError("unexpected type '" ++ @typeName(T) ++ "'. require integer or string"),
    };
}

fn getNamedArgumentValue(field_name: []const u8, args: []const []const u8) ?[]const u8 {
    for (args) |arg| {
        if (!std.mem.endsWith(u8, arg, field_name))
            continue;

        return arg;
    }

    return null;
}

pub fn parseInto(self: *Args, comptime T: type, allocator: Allocator) !*T {
    validateType(T);

    const inst = try allocator.create(T);
    errdefer allocator.destroy(inst);
    inst.* = T.default();

    const args = self.remaining();
    const positional_argument_count = getPositionalArgumentCount(T);

    if (args.len < positional_argument_count) {
        return Error.MissingPositionalArgument;
    }

    const fields = std.meta.fields(T);

    inline for (fields, 0..) |field, idx| {
        if (idx < positional_argument_count) {
            @field(inst, field.name) = try convertInto(field.type, allocator, args[idx]);
        } else {
            if (getNamedArgumentValue(field.name, args[positional_argument_count..])) |value|
                @field(inst, field.name) = try convertInto(field.type, allocator, value);
        }
    }

    return inst;
}
