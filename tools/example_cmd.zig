const std = @import("std");
const Allocator = std.mem.Allocator;

const arg_parser = @import("../arg_parser.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");

const Example = @This();

const ExampleArgs = struct {
    /// Required fields must be non-nullable
    /// And default to `undefined`
    /// Currently the only supported types are `[]const u8` and any integer type
    required_field: []const u8 = undefined,

    /// Non-required fields must be nullable
    /// And they are required to be passed in the format
    /// --<name>=<value>
    /// e.g: --non_req_field=value
    non_req_field: ?[]const u8 = null,
};

/// This is what will be used to determine if the command has been matched
const name = "name";
/// These will be checked as a backup if the name doesn't match
/// So `exe n` will match as well as `exe name`
const aliases = &.{"n"};

/// This is how to provide more information on a specific command
/// based on the spec defined at http://docopt.org/
const help =
    \\my-help-message
;

args: ExampleArgs,

/// This shouldn't need to change from the generated code
pub fn comand() Command {
    return Command{
        .name = name,
        .aliasees = aliases,
        .help = help,
        .parseFn = parse,
    };
}

pub fn parse(allocator: Allocator, args: []const []const u8) Command.ParseError!Executable {
    const exe = try allocator.create(Example);
    exe.args = try arg_parser.parseArgs(ExampleArgs, allocator, args);

    return Executable{
        .ptr = exe,
        .executeFn = execute,
    };
}

fn deinit(self: *Example, allocator: Allocator) void {
    // Deinit any `[]const u8` fields in the args struct
    allocator.free(self.args.required_field);
    if (self.args.non_req_field) |f| {
        allocator.free(f);
    }

    // Destroy the pointer of the executable
    allocator.destroy(self);
}

pub fn execute(ptr: *anyopaque, allocator: Allocator) !void {
    // Cast the pointer into our implementation type
    const self: *Example = @ptrCast(@alignCast(ptr));
    _ = self;
    _ = allocator;
}
