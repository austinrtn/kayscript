const std = @import("std");
const Stdio = @import("ZigStdIo").StdIo;
const Allocator = std.mem.Allocator;
const Io = std.Io;

const kayscript = @import("kayscript");
const CommandCenter = @import("CommandCenter.zig").CommandCenter;
const lsblk = @import("Lsblk.zig").lsblk;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;
    
    var stdio: Stdio = try .init(allocator, io, 1042);
    defer stdio.deinit();
    try stdio.cls();

    var cmd_center: CommandCenter = .init(allocator, io);
    
    const block_devices = try lsblk(allocator, &cmd_center);

    try stdio.writeln("Select block device: ");
    for(block_devices, 0..) |dev, i| {
        try stdio.print("{d}: {s}\n", .{i, dev.name});
    }

    const resp = try stdio.input(null, .{});
    const idx = try std.fmt.parseInt(usize, resp, 0);
    try stdio.print("You entered: {s}", .{block_devices[idx].name});
}