const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("../../Args.zig");

const Parameters = struct {
    setting_name: []const u8,
    setting_value: []const u8,

    pub fn default() Parameters {
        return Parameters{
            .setting_name = undefined,
            .setting_value = undefined,
        };
    }

    fn deinit(self: *Parameters, allocator: Allocator) void {
        allocator.free(self.setting_name);
        allocator.free(self.setting_value);
    }
};

pub fn execute(allocator: Allocator, args: *Args) !void {
    var params = try args.parseInto(Parameters, allocator);
    defer params.deinit(allocator);
}
