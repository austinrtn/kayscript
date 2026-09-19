const std = @import("std");
const Stdio = @import("ZigStdIo").StdIo;
const Allocator = std.mem.Allocator;
const Io = std.Io;

const kayscript = @import("kayscript");
const CommandCenter = @import("CommandCenter.zig").CommandCenter;
const Lsblk = @import("Lsblk.zig");
const Config = @import("Config.zig").Config;


pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;
    
    var stdio: Stdio = try .init(allocator, io, 1042);
    var cmd_center: CommandCenter = .init(allocator, io);
    
    try stdio.cls();
    _ = try cmd_center.sudoV();
    
    const args = try init.minimal.args.toSlice(allocator);
    const arg = if(args.len >= 2) args[1] else "";

    var config: Config = try .init(allocator, io);
    defer config.deinit();
    
    if(std.mem.eql(u8, arg, "--c") or config.new_file_created) {
        setupConfig(allocator, &stdio, &cmd_center) catch |err|{
            _ = cmd_center.run(&.{"rm", "-f", "config.json"}) catch {};
            return err;
        };
    }
}

fn setupConfig(allocator: Allocator, stdio: *Stdio, cmd_center: *CommandCenter) !void {
    try stdio.cls();

    const block_devices = try Lsblk.getBlockDevices(allocator, cmd_center);
    try stdio.writeln("Select block device: ");
    try stdio.print("{s}\n", .{try Lsblk.fmtLsblkEntries(allocator, block_devices)});

    const resp = try stdio.input(null, .{});
    var idx = try std.fmt.parseInt(usize, resp, 0);
    const selected_block_dev = block_devices[idx];
    const block_dev_loc = try std.fmt.allocPrint(allocator, "/dev/{s}", .{selected_block_dev.name});
    try stdio.cls();
    
    try stdio.writeln("Select Parition to Mount: ");
    const partitions = try Lsblk.queryBlockDevice(allocator, cmd_center, block_dev_loc);
    var selected_partition: Lsblk.LsblkEntry = undefined;
    var partition_loc: []u8 = "";
    
    if(partitions.len > 0) {
        const partitions_fmt = try Lsblk.fmtLsblkEntries(allocator, partitions);
        try stdio.print("{s}\n", .{partitions_fmt});
        idx = try std.fmt.parseInt(usize, try stdio.input(null, .{}), 0);
        selected_partition = partitions[idx];
        partition_loc = try std.fmt.allocPrint(allocator, "/dev/{s}", .{selected_partition.name});
        
        try stdio.cls();
    }

    const default_mount_pnt = try std.fmt.allocPrint(allocator, "/mnt/{s}/", .{selected_partition.name});
    const mount_pnt = blk: {
        const mnt_pt = try stdio.input("Enter mount point (default: {s})\n", .{default_mount_pnt});
        if(mnt_pt.len == 0) break :blk default_mount_pnt
        else break :blk mnt_pt;
    };
    
    const mkdir, var success, _ = try cmd_center.run(&.{"sudo", "mkdir", "-p", mount_pnt});
    if(!success) try stdio.errorPrint("{s}\n", .{mkdir.stderr}, 1);

    _, _, const code = try cmd_center.run(&.{"findmnt", "-rn", "-S", block_dev_loc,});

    if(code == 1) {
        const mnt, success, _ = try cmd_center.run(&.{"sudo", "mount", partition_loc, mount_pnt});
        if(!success) try stdio.errorPrint("{s}\n", .{mnt.stderr}, null);
        return error.UnableToMount;
    }
}