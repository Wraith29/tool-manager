const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const builtin = @import("builtin");
const log = std.log.scoped(.main);

const arg_parser = @import("arg_parser.zig");
const Config = @import("Config.zig");
const Cli = @import("Cli.zig");
const path = @import("path.zig");
const git = @import("git.zig");

fn ensureToolPathsExist(cfg: *const Config) !void {
    if (!path.exists(cfg.tool_path)) {
        log.info("{s} not found, creating it", .{cfg.tool_path});
        try std.fs.makeDirAbsolute(cfg.tool_path);
    }

    var tool_dir = try std.fs.openDirAbsolute(cfg.tool_path, .{});
    defer tool_dir.close();

    tool_dir.access("tools.json", .{}) catch {
        log.info("tools.json not found, creating it", .{});
        var tools_file = try tool_dir.createFile("tools.json", .{});
        defer tools_file.close();

        try tools_file.writeAll("{}");
    };

    tool_dir.access("installers.json", .{}) catch {
        log.info("installers.json not found, creating it", .{});
        var installers_file = try tool_dir.createFile("installers.json", .{});
        defer installers_file.close();

        try installers_file.writeAll("{}");
    };

    tool_dir.access("src", .{}) catch {
        log.info("src dir not found, creating it", .{});
        try tool_dir.makeDir("src");
    };

    tool_dir.access("bin", .{}) catch {
        log.info("bin dir not found, creating it", .{});
        try tool_dir.makeDir("bin");
    };
}

pub fn main() !void {
    if (builtin.os.tag == .windows) {
        return error.UnsupportedOperatingSystem;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const Test = struct {
        hello: []const u8 = undefined,
        opt_field: ?[]const u8 = null,
        opt_int: ?u32 = null,

        pub fn default() @This() {
            return .{
                .hello = undefined,
                .opt_field = null,
                .opt_int = null,
            };
        }

        fn deinit(self: *@This(), alloc: Allocator) void {
            alloc.free(self.hello);
            if (self.opt_field) |opt| alloc.free(opt);

            alloc.destroy(self);
        }
    };

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const ts = try arg_parser.parseArgs(Test, allocator, args[1..]);
    defer ts.deinit(allocator);

    log.info("TS: {any}", .{ts});

    // var cfg = try Config.init(allocator);
    // defer cfg.deinit(allocator);

    // try ensureToolPathsExist(cfg);

    // const cli = Cli.init(allocator);

    // return try cli.run();
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
