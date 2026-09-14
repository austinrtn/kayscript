const std = @import("std");
const Stdio = @import("ZigStdIo").StdIo;
const Allocator = std.mem.Allocator;
const Io = std.Io;

const kayscript = @import("kayscript");
const CommandCenter = @import("CommandCenter.zig").CommandCenter;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;
    
    var stdio: Stdio = try .init(allocator, io, 1042);
    defer stdio.deinit();
    
    try stdio.cls();
    
    const res = try lsblk(allocator, io);
    const entries = res.blockdevices;

    try stdio.writeln("Select block device: ");
    for(entries, 0..) |ent, i| {
        try stdio.print("{d}: {s}\n", .{i, ent.name});
    }

    const resp = try stdio.input(null, .{});
    const idx = try std.fmt.parseInt(usize, resp, 0);
    try stdio.print("You entered: {s}", .{entries[idx].name});
}

const LsblkEntry = struct {
    name: []const u8,
    type: []const u8,
    @"id-link": ?[]const u8,
    size: []const u8,
};

const LsblkOutput = struct {
    blockdevices: []LsblkEntry,
};

fn cls(stdout: *std.Io.Writer) void {
    stdout.writeAll("\x1b[2J\x1b[H") catch @panic("Unable to clear screen");
    stdout.flush() catch @panic("Unable to clear screen");
}

fn lsblk(allocator: Allocator, io: Io) !*LsblkOutput {
    const cmd = try std.process.run(allocator, io, .{
        .argv = &.{ "lsblk", "--json", "--output", "NAME,TYPE,SIZE,ID-LINK" },
    });

    getCmdError(cmd) catch |err| {
        std.debug.print("{s}\n", .{cmd.stderr});
        return err;
    };

    const parsed = try std.json.parseFromSlice(
        LsblkOutput,
        allocator, 
        cmd.stdout, 
        .{.ignore_unknown_fields = true},
    );

    const res_ptr = try allocator.create(LsblkOutput);
    res_ptr.* = parsed.value;
    return res_ptr;
}
