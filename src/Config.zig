const std = @import("std");
const Json = std.json;
const File = std.Io.File;

pub const Config = struct {
    const Self = @This();
    pub const file_name = "config.json";

    allocator: std.mem.Allocator,
    io: std.Io,
    file: ?*File = null,
    new_file_created: bool = false,
    device_name: ?[]const u8 = null,
    mount_point: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) !Self {
        var self = Self{ .allocator = allocator, .io = io };
        self.file = try allocator.create(File);
        
        try self.setFile();

        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.file) |f| {
            f.close(self.io);   
            self.allocator.destroy(f);
        }
    }

    fn setFile(self: *Self) !void {
        var cwd = std.Io.Dir.cwd();
        const config_file = cwd.openFile(self.io, file_name, .{});
        var file: File = undefined;

        if (config_file) |f| file = f
        else |err| switch (err) {
            error.FileNotFound => { 
                file = try cwd.createFile(self.io, file_name, .{});
                self.new_file_created = true;
            },
            else => return err,
        }

        self.file.?.* = file;
    }
};
