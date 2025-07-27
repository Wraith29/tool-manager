const std = @import("std");
const c = std.c;

pub fn main() !void {
    const stdin = std.io.getStdIn();

    const stdout = std.io.getStdOut();
    if (!stdout.getOrEnableAnsiEscapeSupport())
        return error.InvalidTerminal;

    // Save current terminal state & setup the reset on program exit
    var original_state: c.termios = undefined;
    var terminal_state: c.termios = undefined;
    if (c.tcgetattr(stdin.handle, &terminal_state) != 0)
        return error.TcGetAttrFailed;

    original_state = terminal_state;
    defer if (c.tcsetattr(stdin.handle, c.TCSA.NOW, &original_state) != 0)
        std.debug.panic("Resetting Terminal Failed\n", .{});

    // Disable Canonical Mode
    terminal_state.lflag.ICANON = false;
    terminal_state.lflag.ECHO = false;
    if (c.tcsetattr(stdin.handle, c.TCSA.NOW, &terminal_state) != 0)
        return error.TcSetAttrFailed;

    // Get Cursor Position in the format \x1B[<LINE>;<COL>R
    try stdout.writeAll("\x1B[6n");

    var buffer: [32]u8 = undefined;
    // We know that the Position is returned with an "R" at the end
    // So we can read until that delimiter
    const position = try stdout.reader().readUntilDelimiter(&buffer, 'R');

    const line_start_idx = std.mem.indexOf(u8, position, "[") orelse return error.InvalidPosition;
    const semicolon_idx = std.mem.indexOf(u8, position, ";") orelse return error.InvalidPosition;

    const cursor_line = try std.fmt.parseInt(u8, position[line_start_idx + 1 .. semicolon_idx], 10);
    const cursor_column = try std.fmt.parseInt(u8, position[semicolon_idx + 1 ..], 10);

    try stdout.writer().print(
        "Cursor Position (At time of running the Position Command):\nLine: {d}\nCol: {d}\n",
        .{ cursor_line, cursor_column },
    );
}
