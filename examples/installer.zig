const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;

fn jsonHashMapToStdHashMap(
    allocator: Allocator,
    in: json.ArrayHashMap([]const u8),
    out: *std.StringHashMapUnmanaged([]const u8),
) !void {
    for (in.map.keys()) |key| {
        const value = try copyStr(allocator, in.map.get(key).?);
        const new_key = try copyStr(allocator, key);

        try out.put(allocator, new_key, value);
    }
}

fn copyStr(allocator: Allocator, s: []const u8) ![]const u8 {
    const buf = try allocator.alloc(u8, s.len);
    @memcpy(buf, s);

    return buf;
}

const InstallerListItem = struct {
    name: []const u8,
    description: []const u8,

    pub fn deinit(self: *InstallerListItem, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.description);
        allocator.destroy(self);
    }

    pub fn copy(self: *InstallerListItem, allocator: Allocator) !*InstallerListItem {
        const new = try allocator.create(InstallerListItem);

        new.name = try copyStr(allocator, self.name);
        new.description = try copyStr(allocator, self.description);

        return new;
    }
};

const Installer = struct {
    name: []const u8,
    description: []const u8,
    commands: []const []const u8,
    variables: *json.ArrayHashMap([]const u8),

    pub fn deinit(self: *Installer, allocator: Allocator) void {
        allocator.free(self.name);
        allocator.free(self.description);
        for (self.commands) |cmd|
            allocator.free(cmd);
        allocator.free(self.commands);

        for (self.variables.map.keys()) |key| {
            allocator.free(self.variables.map.get(key).?);
            allocator.free(key);
        }

        self.variables.deinit(allocator);
        allocator.destroy(self.variables);

        allocator.destroy(self);
    }

    pub fn load(allocator: Allocator, name: []const u8) !*Installer {
        var installer_dir = try std.fs.cwd().openDir("installers", .{});
        defer installer_dir.close();

        const path = try std.mem.concat(allocator, u8, &.{ name, ".json" });
        defer allocator.free(path);

        var file = try installer_dir.openFile(path, .{});
        defer file.close();

        const bytes = try file.readToEndAlloc(allocator, 1 << 16);
        defer allocator.free(bytes);

        var parsed = try json.parseFromSlice(Installer, allocator, bytes, .{});
        defer parsed.deinit();

        std.log.info("Parsed installer: {any}", .{parsed.value});

        const new = try parsed.value.copy(allocator);

        return new;
    }

    pub fn copy(self: *const Installer, allocator: Allocator) !*Installer {
        const new = try allocator.create(Installer);

        new.name = try copyStr(allocator, self.name);
        new.description = try copyStr(allocator, self.description);
        var cmds = try std.ArrayListUnmanaged([]const u8).initCapacity(allocator, self.commands.len);

        for (self.commands, 0..) |cmd, idx| {
            try cmds.insert(allocator, idx, try copyStr(allocator, cmd));
        }

        new.commands = try cmds.toOwnedSlice(allocator);
        new.variables = try allocator.create(json.ArrayHashMap([]const u8));
        new.variables.map = .{};

        for (self.variables.map.keys()) |key| {
            const new_key = try copyStr(allocator, key);
            const value = try copyStr(allocator, self.variables.map.get(key).?);

            try new.variables.map.put(allocator, new_key, value);
        }

        return new;
    }
};

fn loadInstallerList(allocator: Allocator) ![]*InstallerListItem {
    const file = try std.fs.cwd().openFile("installers.json", .{});
    defer file.close();

    const bytes = try file.readToEndAlloc(allocator, 1 << 16);
    defer allocator.free(bytes);

    const parsed = try json.parseFromSlice([]*InstallerListItem, allocator, bytes, .{});
    defer parsed.deinit();

    var copied_items = try std.ArrayListUnmanaged(*InstallerListItem).initCapacity(allocator, parsed.value.len);

    for (parsed.value, 0..) |list_item, index| {
        try copied_items.insert(allocator, index, try list_item.copy(allocator));
    }

    return try copied_items.toOwnedSlice(allocator);
}

const Tool = struct {
    name: []const u8,
    repository: []const u8,
    installer: []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const installers = try loadInstallerList(allocator);
    defer {
        for (installers) |installer| {
            installer.deinit(allocator);
        }

        allocator.free(installers);
    }

    for (installers, 0..) |installer, idx| {
        std.log.info("Trying to open {s}", .{installer.name});
        const inst = try Installer.load(allocator, installer.name);
        defer inst.deinit(allocator);

        std.log.info(
            "{d}: {s} -> {s}",
            .{ idx, inst.name, inst.description },
        );

        for (inst.commands, 0..) |cmd, cmd_idx| {
            std.log.info("\t{d}: {s}", .{ cmd_idx, cmd });
        }

        for (inst.variables.map.keys()) |key| {
            std.log.info("\t{s}: {s}", .{ key, inst.variables.map.get(key).? });
        }
    }
}
