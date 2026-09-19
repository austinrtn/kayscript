const std = @import("std");
const Allocator = std.mem.Allocator;
const CommandCenter = @import("CommandCenter.zig").CommandCenter;

const LsblkEntry = struct {
    name: []const u8,
    type: []const u8,
    @"id-link": ?[]const u8,
    size: []const u8,
    fstype: ?[]const u8 = null,
};

const LsblkOutput = struct {
    blockdevices: []LsblkEntry,
};

pub fn getBlockDevices(allocator: Allocator, cmd_center: *CommandCenter) ![]LsblkEntry {
    const args = &.{ "lsblk", "--json", "--output", "NAME,TYPE,SIZE,ID-LINK,FSTYPE" };

    const cmd, const success, _ = try cmd_center.run(args);
    if (!success) return error.CommandFailed;

    const parsed = try std.json.parseFromSlice(
        LsblkOutput,
        allocator,
        cmd.stdout,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const block_devices = parsed.value.blockdevices;
    return try allocator.dupe(LsblkEntry, block_devices);
}

pub fn queryBlockDevice(allocator: Allocator, cmd_center: *CommandCenter, block_dev_device: []const u8) ![]LsblkEntry {
    const args = &.{
        "lsblk",
        "--json",
        "--list",
        "--filter",
        "TYPE==\"part\"",
        "--output",
        "NAME,TYPE,SIZE,ID-LINK,FSTYPE",
        block_dev_device,
    };

    const cmd, const success, _ = try cmd_center.run(args);
    if (!success) return error.CommandFailed;

    const parsed = try std.json.parseFromSlice(
        LsblkOutput,
        allocator,
        cmd.stdout,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    const partitions = parsed.value.blockdevices;
    return try allocator.dupe(LsblkEntry, partitions);
}

pub fn fmtLsblkEntries(allocator: Allocator, entries: []LsblkEntry) ![]const u8 {
    var table: std.Io.Writer.Allocating = .init(allocator);
    defer table.deinit();

    try table.writer.print(
        "{s:>3} {s:<12} {s:<8} {s:<8} {s:>8}\n",
        .{ "#", "NAME", "TYPE", "FSTYPE", "SIZE" },
    );

    for (entries, 0..) |entry, i| {
        try table.writer.print(
            "{d:>3} {s:<12} {s:<8} {s:<8} {s:>8}\n",
            .{
                i,
                entry.name,
                entry.type,
                entry.fstype orelse "-",
                entry.size,
            },
        );
    }

    return try table.toOwnedSlice();
}
