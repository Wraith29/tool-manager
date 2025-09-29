const std = @import("std");
const Allocator = std.mem.Allocator;
const Args = @import("../Args.zig");

const Parameters = struct {
    repository: []const u8 = undefined,

    pub fn default() Parameters {
        return Parameters{
            .repository = undefined,
        };
    }

    fn deinit(self: *Parameters, allocator: Allocator) void {
        allocator.free(self.repository);
        allocator.destroy(self);
    }
};

pub fn execute(allocator: Allocator, args: *Args) !void {
    var parsed = try args.parseInto(Parameters, allocator);
    defer parsed.deinit(allocator);
}
