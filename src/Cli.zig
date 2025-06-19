const std = @import("std");
const log = std.log.scoped(.cli);
const Allocator = std.mem.Allocator;

const Command = @import("cmd/Command.zig");
const Executable = @import("cmd/Executable.zig");
const Init = @import("cmd/Init.zig");
const Install = @import("cmd/Install.zig");
const Export = @import("cmd/Export.zig");

const Cli = @This();

const commands = [_]Command{
    Init.command(),
    Install.command(),
    Export.command(),
};

allocator: Allocator,

pub fn init(allocator: Allocator) Cli {
    return Cli{
        .allocator = allocator,
    };
}

pub fn run(self: *const Cli) !void {
    const args = try std.process.argsAlloc(self.allocator);
    defer std.process.argsFree(self.allocator, args);

    if (args.len <= 1) {
        try std.io.getStdOut().writeAll(help());
        return;
    }

    const exe: Executable = inline for (commands) |command| {
        log.info("Checking {s}", .{command.name});
        if (command.isMatch(args[1])) {
            break command.parse(args) catch |err| switch (err) {
                error.MissingPositionalArgument => {
                    var stdout = std.io.getStdOut();
                    try stdout.writeAll("Missing required positional argument\n");
                    try stdout.writeAll(command.help());

                    return err;
                },
            };
        }
    } else {
        try std.io.getStdOut().writeAll(help());
        return error.NoCommandProvided;
    };

    try exe.execute(self.allocator);
}

fn help() []const u8 {
    return 
    \\tool-manager
    \\------------
    \\
    \\commands:
    \\  init
    \\    Initialise the tool manager.
    \\    Will prompt for the tool installation directory.
    \\
    \\  install <name>
    \\    Install the given tool
    \\    Will prompt for the git repository link, as well as build / install steps.
    \\
    \\
    ;
}
