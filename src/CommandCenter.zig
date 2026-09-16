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

    pub fn run(self: Self, command: []const []const u8) !struct{RunResult, bool, u8} {
        const cmd = try std.process.run(self.allocator, self.io, .{ .argv = command });

        if (cmd.term != .exited) return error.CommandTerminated;
        const success = cmd.term.exited == 0;
        return .{cmd, success, cmd.term.exited};
    }

    pub fn sudoV(self: Self) !RunResult {
        const cmd = try std.process.run(self.allocator, self.io, .{.argv = &.{"sudo", "-v"}});
        if (cmd.term != .exited) return error.CommandTerminated;
        return cmd;
    }
};
