const std = @import("std");
const Allocator = std.mem.Allocator;

const Command = @import("cmd/Command.zig");
const Executable = @import("cmd/Executable.zig");
const Export = @import("cmd/Export.zig");
const Init = @import("cmd/Init.zig");
const Use = @import("cmd/Use.zig");
const List = @import("cmd/List.zig");
const args = @import("args.zig");

const log = std.log.scoped(.cli);
const Cli = @This();

const help =
    \\tool-manager (tm)
    \\
    \\usage:
    \\  tm init
    \\  tm use <repository> [--name=<tool_name>] [--multi-step] [--branch=<branch>|--tag=<tag>]
    \\  tm export [<export_file>]
    \\  tm list
    \\
    \\options:
    \\  -h, --help    Show the help message for the given command
;

const commands = [_]Command{
    Init.command(),
    Use.command(),
    Export.command(),
    List.command(),
};

allocator: Allocator,

pub fn init(allocator: Allocator) Cli {
    return Cli{
        .allocator = allocator,
    };
}

pub fn run(self: *const Cli) !void {
    const arguments = try std.process.argsAlloc(self.allocator);
    defer std.process.argsFree(self.allocator, arguments);

    if (arguments.len <= 1) {
        try std.io.getStdOut().writeAll(help);
        return;
    }

    const exe: Executable = inline for (commands) |command| {
        log.info("Checking {s}", .{command.name});
        if (command.isMatch(arguments[1])) {
            if (args.hasFlag(arguments, "--help") or args.hasFlag(arguments, "-h")) {
                var stdout = std.io.getStdOut();
                try stdout.writeAll(command.help);
                return;
            }

            break command.parse(self.allocator, arguments) catch |err| switch (err) {
                error.MissingPositionalArgument => {
                    var stdout = std.io.getStdOut();
                    try stdout.writeAll("Missing required positional argument\n");
                    try stdout.writeAll(command.help);

                    return err;
                },
                else => return err,
            };
        }
    } else {
        try std.io.getStdOut().writeAll(help);
        return error.NoCommandProvided;
    };
    defer exe.deinit(self.allocator);

    try exe.execute(self.allocator);
}
