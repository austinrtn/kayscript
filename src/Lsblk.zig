const std = @import("std");
const CommandCenter = @import("CommandCenter.zig").CommandCenter;

const args = &.{ "lsblk", "--json", "--output", "NAME,TYPE,SIZE,ID-LINK" };

const LsblkEntry = struct {
    name: []const u8,
    type: []const u8,
    @"id-link": ?[]const u8,
    size: []const u8,
};

const LsblkOutput = struct {
    blockdevices: []LsblkEntry,
};

pub fn lsblk(allocator: std.mem.Allocator, cmd_center: *CommandCenter) ![]LsblkEntry {
    const cmd = try cmd_center.run(args);

    const parsed = try std.json.parseFromSlice(
        LsblkOutput,
        allocator,
        cmd.stdout,
        .{ .ignore_unknown_fields = true },
    );

    const block_devices = parsed.value.blockdevices;

    return try allocator.dupe(LsblkEntry, block_devices);
}
