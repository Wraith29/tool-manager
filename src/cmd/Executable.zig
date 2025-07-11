const std = @import("std");
const Allocator = std.mem.Allocator;

const Executable = @This();

ptr: *anyopaque,
executeFn: *const fn (*anyopaque, Allocator) anyerror!void,

pub fn execute(self: Executable, allocator: Allocator) anyerror!void {
    return self.executeFn(self.ptr, allocator);
}
