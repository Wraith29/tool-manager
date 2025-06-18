const std = @import("std");
const log = std.log.scoped(.executable);
const Allocator = std.mem.Allocator;

const Executable = @This();

ptr: *anyopaque,
executeFn: *const fn (ptr: *anyopaque, allocator: Allocator) anyerror!void,

pub fn execute(self: Executable, allocator: Allocator) !void {
    return self.executeFn(self.ptr, allocator);
}
