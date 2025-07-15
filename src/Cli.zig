const std = @import("std");
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.cli);

const Command = @import("cmd/Command.zig");
const Executable = @import("cmd/Executable.zig");

const Cli = @This();

const commands = [_]Command{};

const help =
    \\tool-manager
;

allocator: Allocator,

pub fn init(allocator: Allocator) Cli {
    return Cli{ .allocator = allocator };
}

pub fn run(self: *const Cli) !void {
    const args = try std.process.argsAlloc(self.allocator);
    defer std.process.argsFree(self.allocator, args);

    const exe: Executable = inline for (commands) |cmd| {
        log.info("Checking {s}", .{cmd.name});
        if (cmd.match(args[1])) {
            if (std.mem.eql(u8, "--help", args[2]) or std.mem.eql(u8, "-h", args[2])) {
                try std.io.getStdOut().writeAll(cmd.help);
                std.process.cleanExit();
            }

            break cmd.parse(self.allocator, args[1..]) catch |err| switch (err) {
                .MissingRequiredArgument => {
                    try std.io.getStdErr().writeAll("Missing Required Argument\n");
                    try std.io.getStdErr().writeAll(cmd.help);

                    return err;
                },
                else => return err,
            };
        }
    } else showHelp();

    return exe.execute(self.allocator);
}

pub fn showHelp() noreturn {
    std.io.getStdOut().writeAll(help) catch |err| std.debug.panic("Error: {s}", .{@errorName(err)});
    std.process.cleanExit();
    unreachable;
}
