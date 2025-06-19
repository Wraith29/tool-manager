const std = @import("std");

pub fn isAllWhitespace(str: []const u8) bool {
    for (str) |chr|
        if (!std.ascii.isWhitespace(chr))
            return false;

    return true;
}
