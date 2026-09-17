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
    _ = try cmd_center.sudoV();
    
    const args = try init.minimal.args.toSlice(allocator);
    const arg = if(args.len >= 2) args[1] else "";

    const config_exists = try createConfig(io);
    _ = config_exists;

    if(std.mem.eql(u8, arg, "--c")) {
        try setupConfig(allocator, &stdio, &cmd_center);
        return;
    }
}

fn createConfig(io: Io) !bool {
    //var buf = [1024]u8;
    var config_file = blk: {
        var cwd = Io.Dir.cwd();
        const cf_file = cwd.openFile(io, "config.json", .{}) catch |err| switch(err) {
            error.FileNotFound => break :blk try cwd.createFile(io, "config.json", .{}),
            else => return err,
        };
        break :blk cf_file;
    };
    defer config_file.close(io);
    return true;
}

fn setupConfig(allocator: Allocator, stdio: *Stdio, cmd_center: *CommandCenter) !void {
    try stdio.cls();
    try stdio.cls();

    const block_devices = try lsblk(allocator, cmd_center);
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
    
    const mkdir, var success, _ = try cmd_center.run(&.{"sudo", "mkdir", "-p", mount_pnt});
    if(!success) try stdio.errorPrint("{s}\n", .{mkdir.stderr}, 1);

    _, _, const code = try cmd_center.run(&.{"findmnt", "-rn", "-S", block_dev_loc, ">/dev/null"});

    if(code == 1) {
        const mnt, success, _ = try cmd_center.run(&.{"sudo", "mount", block_dev_loc, mount_pnt});
        if(!success) try stdio.errorPrint("{s}\n", .{mnt.stderr}, 1);
    }
}