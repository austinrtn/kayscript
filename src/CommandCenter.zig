const std = @import("std");
const RunResult = std.process.RunResult;

pub const CommandCenter = struct {
    const Self = @This();
    
    allocator: std.mem.Allocator,
    io: std.Io,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) Self {
        return .{
            .allocator = allocator,
            .io = io,
        };
    }

    pub fn run(self: Self, command: []const []const u8) !RunResult {
        const cmd = try std.process.run(self.allocator, self.io, .{.argv = command});

        try getCmdError(cmd);
        return cmd;
    }
    
    fn getCmdError(cmd: RunResult) error{CommandFailed, CommandTerminated}!void {
        switch(cmd.term) {
            .exited => |code| if(code != 0) return error.CommandFailed,
            else => return error.CommandTerminated,
        }
    }
};