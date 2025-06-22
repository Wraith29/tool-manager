const std = @import("std");
const Allocator = std.mem.Allocator;

const args = @import("args.zig");
const Command = @import("cmd/Command.zig");
const Executable = @import("cmd/Executable.zig");
const Export = @import("cmd/Export.zig");
const Init = @import("cmd/Init.zig");
const List = @import("cmd/List.zig");
const Update = @import("cmd/Update.zig");
const Use = @import("cmd/Use.zig");

const log = std.log.scoped(.cli);
const Cli = @This();

const help =
    \\tool-manager (tm)
    \\
    \\usage:
    \\  tm init
    \\  tm use <repository> [--name=<tool_name>] [--multi-step] [--branch=<branch>|--tag=<tag>]
    \\  tm update [<tool>] 
    \\  tm export [<export_file>]
    \\  tm list
    \\
    \\options:
    \\  -h, --help    Show the help message for the given command
    \\
;

const commands = [_]Command{
    Export.command(),
    Init.command(),
    List.command(),
    Update.command(),
    Use.command(),
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
