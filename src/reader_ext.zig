const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

const log = std.log.scoped(.reader_ext);

pub fn readUntilNewLineAlloc(allocator: Allocator, reader: @TypeOf(std.io.getStdIn().reader()), max_size: usize) ![]const u8 {
    const input = try reader.readUntilDelimiterAlloc(allocator, '\n', max_size);

    if (builtin.target.os.tag == .windows) {
        log.info("Targeting Windows. Trimming '\\r'", .{});
        const trimmed = try allocator.alloc(u8, input.len - 1);
        @memcpy(trimmed, input[0 .. input.len - 1]);

        allocator.free(input);
        return trimmed;
    }

    return input;
}
