const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("Args.zig");
const Cli = @import("Cli.zig");

fn installTool(_: Allocator, _: *Args) !void {
    std.log.info("Hello from Tool/Install", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try Args.init(allocator);
    defer args.deinit(allocator);
    args.skip() orelse unreachable;

    var cli = Cli{
        .name = "tool-manager",
        .commands = &.{
            .{
                .name = "tool",
                .subcommands = &.{
                    .{
                        .name = "install",
                        .short = "i",
                        .execute = installTool,
                    },
                },
            },
        },
    };

    try cli.run(allocator, &args);
}
