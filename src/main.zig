const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("Args.zig");
const Cli = @import("Cli.zig");
const use = @import("commands/use.zig").execute;
const cfg_list = @import("commands/config/list.zig").execute;
const cfg_set = @import("commands/config/set.zig").execute;

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
                .name = "use",
                .execute = use,
            },
            .{
                .name = "config",
                .subcommands = &.{
                    .{
                        .name = "list",
                        .execute = cfg_list,
                    },
                    .{
                        .name = "set",
                        .execute = cfg_set,
                    },
                },
            },
        },
    };

    try cli.run(allocator, &args);
}
