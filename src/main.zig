const std = @import("std");
const log = std.log;
const time = std.time;
const Allocator = std.mem.Allocator;

const Cli = @import("Cli.zig");
const Command = @import("cmd/Command.zig");
const Init = @import("cmd/Init.zig");
const Config = @import("Config.zig");
const files = @import("files.zig");
const Tool = @import("Tool.zig");

pub const std_options = std.Options{
    .logFn = customLogFn,
};

const DateTime = struct {
    year: time.epoch.Year,
    month: time.epoch.Month,
    day: u5,
    hour: u5,
    minutes: u6,
    seconds: u6,

    pub fn now() DateTime {
        const epoch_sec = time.epoch.EpochSeconds{ .secs = @intCast(time.timestamp()) };
        const ep_day = epoch_sec.getEpochDay();
        const ep_year = ep_day.calculateYearDay();
        const ep_month = ep_year.calculateMonthDay();
        const ep_time = epoch_sec.getDaySeconds();

        return DateTime{
            .year = ep_year.year,
            .month = ep_month.month,
            .day = ep_month.day_index,
            .hour = ep_time.getHoursIntoDay(),
            .minutes = ep_time.getMinutesIntoHour(),
            .seconds = ep_time.getSecondsIntoMinute(),
        };
    }

    pub fn toString(self: DateTime, buf: []u8) ![]const u8 {
        return try std.fmt.bufPrint(
            buf,
            "{d:0>2}:{d:0>2}:{d:0>2}",
            .{ self.hour, self.minutes, self.seconds },
        );
    }
};

fn customLogFn(
    comptime _: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime fmt: []const u8,
    args: anytype,
) void {
    const prefix_fmt = "[" ++ @tagName(scope) ++ "@{s}]: ";
    var buf: [8]u8 = undefined;
    const timestamp = DateTime.now().toString(&buf) catch return;

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();

    var writer = std.io.getStdErr().writer();

    writer.print(prefix_fmt, .{timestamp}) catch return;
    writer.print(fmt ++ "\n", args) catch return;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try files.init(allocator);
    defer files.deinit(allocator);

    const cli = Cli.init(allocator);
    try cli.run();
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
