const std = @import("std");
const cmd_template = @embedFile("example_cmd.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.err("Missing required argument: CommandName", .{});
        return;
    }

    var cmdname = args[1];
    cmdname[0] = std.ascii.toUpper(cmdname[0]);

    const bufsize = std.mem.replacementSize(u8, cmd_template, "Example", cmdname);
    const buf = try allocator.alloc(u8, bufsize);
    defer allocator.free(buf);
    _ = std.mem.replace(u8, cmd_template, "Example", cmdname, buf);

    const subpath = try std.fs.path.join(allocator, &.{ "src", "cmd" });
    defer allocator.free(subpath);

    var cmd_dir = try std.fs.cwd().openDir(subpath, .{});
    defer cmd_dir.close();

    const filename = try std.mem.concat(allocator, u8, &.{ cmdname, ".zig" });
    defer allocator.free(filename);

    var cmdfile = try cmd_dir.createFile(filename, .{});
    defer cmdfile.close();

    try cmdfile.writeAll(buf);
}
