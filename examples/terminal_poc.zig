const std = @import("std");
const c = std.c;

const AnsiCodes = struct {
    const escape = "\x1B";
    const reset = escape ++ "[m";
    const erase_to_end_of_screen = escape ++ "[0J";

    const Cursor = struct {
        const position = escape ++ "[6n";
    };

    const Foreground = enum(u8) {
        blue = 34,
    };

    fn foreground(comptime fg: Foreground) []const u8 {
        return escape ++ std.fmt.comptimePrint("[{d}m", .{@intFromEnum(fg)});
    }
};

const Key = enum(u8) {
    enter = 10,
    up_arrow = 65,
    down_arrow = 66,
    _,
};

const ListState = struct {
    items: []const []const u8,
    selected: usize,

    pub fn init(items: []const []const u8) ListState {
        return ListState{ .items = items, .selected = 0 };
    }

    pub fn next(self: *ListState) void {
        if (self.selected >= self.items.len) {
            self.selected = 0;
            return;
        }

        self.selected += 1;
    }

    pub fn prev(self: *ListState) void {
        if (self.selected <= 0) {
            self.selected = self.items.len - 1;
            return;
        }

        self.selected -= 1;
    }

    pub fn draw(self: *const ListState, stdout: std.fs.File) !void {
        for (self.items, 0..) |item, idx| {
            if (self.selected == idx)
                try stdout.writeAll(AnsiCodes.foreground(.blue));

            try stdout.writer().print("{d}) {s}\n", .{ idx + 1, item });

            if (self.selected == idx)
                try stdout.writeAll(AnsiCodes.reset);
        }
    }
};

const CursorPosition = struct { line: usize, col: usize };

const Terminal = struct {
    original_state: c.termios,
    terminal_state: c.termios,
    stdin: std.fs.File,
    stdout: std.fs.File,

    pub fn init() !Terminal {
        const stdin = std.io.getStdIn();
        var original_state: c.termios = undefined;
        var terminal_state: c.termios = undefined;

        if (c.tcgetattr(stdin.handle, &terminal_state) != 0) {
            return error.TcGetAttrFailed;
        }

        original_state = terminal_state;

        return Terminal{
            .original_state = original_state,
            .terminal_state = terminal_state,
            .stdin = stdin,
            .stdout = std.io.getStdOut(),
        };
    }

    pub fn deinit(self: *Terminal) void {
        if (c.tcsetattr(self.stdin.handle, c.TCSA.NOW, &self.original_state) != 0)
            std.debug.panic("Error when re-setting terminal state", .{});

        self.stdin.close();
        self.stdout.close();
    }

    fn getCursorPosition(self: *Terminal) !CursorPosition {
        // Responds in the format of `<ESCAPE>[<LINE>;<COL>R`
        try self.stdout.writeAll(AnsiCodes.Cursor.position);

        var buf: [32]u8 = undefined;
        const position = try self.stdout.reader().readUntilDelimiter(&buf, 'R');

        const open = std.mem.indexOf(u8, position, "[") orelse return error.InvalidCursorPosition;
        const semicolon = std.mem.indexOf(u8, position, ";") orelse return error.InvalidCursorPosition;

        return CursorPosition{
            .line = try std.fmt.parseInt(u8, position[open + 1 .. semicolon], 10),
            .col = try std.fmt.parseInt(u8, position[semicolon + 1 ..], 10),
        };
    }

    fn setCursorPosition(self: *Terminal, pos: CursorPosition) !void {
        try self.stdout.writer().print("{s}[{d};{d}f", .{ AnsiCodes.escape, pos.line, pos.col });
    }

    fn readKey(self: *Terminal) !Key {
        const byte = try self.stdin.reader().readByte();

        return @enumFromInt(byte);
    }

    fn setState(self: *Terminal) !void {
        if (c.tcsetattr(self.stdin.handle, c.TCSA.NOW, &self.terminal_state) != 0)
            return error.TcSetAttrFailed;
    }

    pub fn renderListAndGetSelectedOption(
        self: *Terminal,
        list_header: []const u8,
        list_items: []const []const u8,
    ) !usize {
        self.terminal_state.lflag.ICANON = false;
        self.terminal_state.lflag.ECHO = false;
        try self.setState();

        var list_state = ListState.init(list_items);

        try self.stdout.writeAll(list_header);
        try self.stdout.writeAll("\n");

        const initial_cursor_position = try self.getCursorPosition();

        try list_state.draw(self.stdout);

        var key: Key = undefined;
        while (key != .enter) : (key = try self.readKey()) {
            switch (key) {
                .up_arrow => list_state.prev(),
                .down_arrow => list_state.next(),
                else => {},
            }

            // TODO: Update the list
            try self.setCursorPosition(initial_cursor_position);
            try self.stdout.writeAll(AnsiCodes.erase_to_end_of_screen);
            try self.setCursorPosition(initial_cursor_position);
            try list_state.draw(self.stdout);
        }

        return list_state.selected;
    }
};

pub fn main() !void {
    var term = try Terminal.init();
    defer term.deinit();

    const selected = try term.renderListAndGetSelectedOption(
        "Choose from these items:",
        &.{
            "Item 1",
            "Item 2",
            "Item 3",
        },
    );

    std.debug.print("User chose item: {d}\n", .{selected});
}
