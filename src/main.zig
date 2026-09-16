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
    var cmd_center: CommandCenter = .init(allocator, io);
    
    try stdio.cls();
    _ = try cmd_center.sudoV();
    try stdio.cls();

    const block_devices = try lsblk(allocator, &cmd_center);
    try stdio.writeln("Select block device: ");
    for(block_devices, 0..) |dev, i| {
        try stdio.print("{d}: {s}\n", .{i, dev.name});
    }

    const resp = try stdio.input(null, .{});
    const idx = try std.fmt.parseInt(usize, resp, 0);
    const selected_block_dev = block_devices[idx];
    const block_dev_loc = try std.fmt.allocPrint(allocator, "/dev/{s}/", .{selected_block_dev.name});

    try stdio.cls();
    
    const default_mount_pnt = try std.fmt.allocPrint(allocator, "/mnt/{s}/", .{selected_block_dev.name});
    const mount_pnt = blk: {
        const mnt_pt = try stdio.input("Enter mount point (default: {s})\n", .{default_mount_pnt});
        if(mnt_pt.len == 0) break :blk default_mount_pnt
        else break :blk mnt_pt;
    };
    
    const mkdir, const success, _ = try cmd_center.run(&.{"sudo", "mkdir", "-p", mount_pnt});
    if(!success) try stdio.errorPrint("{s}\n", .{mkdir.stderr}, 1);

    _, _, const code = try cmd_center.run(&.{"findmnt", "-rn", "-S", block_dev_loc, ">/dev/null"});

    if(code == 1) _, _, _ = try cmd_center.run(&.{"sudo", "mount", block_dev_loc, mount_pnt});
}