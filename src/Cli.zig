const std = @import("std");
const Allocator = std.mem.Allocator;

const Command = @import("cmd/Command.zig");
const Executable = @import("cmd/Executable.zig");
const Export = @import("cmd/Export.zig");
const Init = @import("cmd/Init.zig");
const Use = @import("cmd/Use.zig");
const List = @import("cmd/List.zig");

const log = std.log.scoped(.cli);
const Cli = @This();

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
    const args = try std.process.argsAlloc(self.allocator);
    defer std.process.argsFree(self.allocator, args);

    if (args.len <= 1) {
        const help_msg = try self.help();
        defer self.allocator.free(help_msg);

        try std.io.getStdOut().writeAll(help_msg);
        return;
    }

    const exe: Executable = inline for (commands) |command| {
        log.info("Checking {s}", .{command.name});
        if (command.isMatch(args[1])) {
            break command.parse(self.allocator, args) catch |err| switch (err) {
                error.MissingPositionalArgument => {
                    var stdout = std.io.getStdOut();
                    try stdout.writeAll("Missing required positional argument\n");
                    try stdout.writeAll(command.help());

                    return err;
                },
                else => return err,
            };
        }
    } else {
        const help_msg = try self.help();
        defer self.allocator.free(help_msg);

        try std.io.getStdOut().writeAll(help_msg);
        return error.NoCommandProvided;
    };
    defer exe.deinit(self.allocator);

    try exe.execute(self.allocator);
}

fn help(self: *const Cli) ![]const u8 {
    log.info("Building help message", .{});
    var help_buf = std.ArrayList(u8).init(self.allocator);

    try help_buf.appendSlice("tool-manager\n\n");

    inline for (commands) |cmd| {
        log.info("Appending help for {s}", .{cmd.name});
        try help_buf.appendSlice(comptime cmd.help() ++ "\n");
    }

    log.info("Built help message", .{});
    return try help_buf.toOwnedSlice();
}
