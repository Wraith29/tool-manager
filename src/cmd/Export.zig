const std = @import("std");
const Allocator = std.mem.Allocator;

const Config = @import("../Config.zig");
const files = @import("../files.zig");
const Command = @import("Command.zig");
const Executable = @import("Executable.zig");
const Tool = @import("../Tool.zig");

const log = std.log.scoped(.export_cmd);
const Export = @This();

outfile: ?[]const u8,

pub fn command() Command {
    return Command{
        .name = "export",
        .helpFn = help,
        .isMatchFn = isMatch,
        .parseFn = parse,
    };
}

pub fn deinit(_: *anyopaque, _: Allocator) void {}

pub fn help() []const u8 {
    return "TODO: Implement export help message";
}

pub fn isMatch(cmd: []const u8) bool {
    if (std.mem.eql(u8, cmd, "export"))
        return true;

    if (std.mem.eql(u8, cmd, "ex"))
        return true;

    return false;
}

pub fn parse(_: Allocator, args: []const []const u8) Command.ParseError!Executable {
    var exe = Export{ .outfile = null };

    if (args.len >= 3) {
        exe.outfile = args[2];
    }

    return Executable{
        .ptr = &exe,
        .executeFn = execute,
        .deinitFn = deinit,
    };
}

pub fn execute(ptr: *anyopaque, allocator: Allocator) !void {
    const self: *Export = @ptrCast(@alignCast(ptr));

    log.info("Exporting to {?s}", .{self.outfile});

    var output_file = if (self.outfile) |outfile|
        try std.fs.cwd().createFile(outfile, .{})
    else
        std.io.getStdOut();
    defer output_file.close();

    const tools = try Tool.loadAll(allocator);
    defer tools.deinit();

    const export_contents = try std.json.stringifyAlloc(allocator, tools.value, .{ .whitespace = .indent_4 });
    defer allocator.free(export_contents);

    try output_file.writeAll(export_contents);
}
