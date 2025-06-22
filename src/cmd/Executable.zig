const std = @import("std");
const log = std.log.scoped(.executable);
const Allocator = std.mem.Allocator;

const Executable = @This();

ptr: *anyopaque,
executeFn: *const fn (*anyopaque, Allocator) anyerror!void,
deinitFn: *const fn (*anyopaque, Allocator) void,

pub fn execute(self: Executable, allocator: Allocator) !void {
    return self.executeFn(self.ptr, allocator);
}

pub fn deinit(self: Executable, allocator: Allocator) void {
    return self.deinitFn(self.ptr, allocator);
}
