const std = @import("std");
const FileBuffer = enum {
    stdout,
    stdin,
    stderr, 
};

pub const StdIo = struct {
    const Self = @This();

    stdout: std.Io.File.Writer = undefined,
    stderr: std.Io.File.Writer = undefined,
    stdin: std.Io.File.Reader = undefined,
    inner: Inner, 

    /// Create new StdIo instance
    pub fn init(allocator: std.mem.Allocator, io: std.Io, buf_size: usize) !Self {
        var inner: Inner = .{.allocator = allocator, .io = io};
        inner.stdout_buf = try allocator.alloc(u8, buf_size);
        inner.stderr_buf = try allocator.alloc(u8, buf_size);
        inner.stdin_buf = try allocator.alloc(u8, buf_size);
        inner.res_buf = try allocator.alloc(u8, buf_size);
        
        var self: Self = .{.inner = inner};
        self.stdout = std.Io.File.Writer.init(.stdout(), io, inner.stdout_buf);
        self.stderr = std.Io.File.Writer.init(.stderr(), io, inner.stderr_buf);
        self.stdin = std.Io.File.Reader.init(.stdin(), io, inner.stdin_buf);
        
        return self;
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.inner.allocator;
        allocator.free(self.inner.stdout_buf);
        allocator.free(self.inner.stderr_buf);
        allocator.free(self.inner.stdin_buf);
        allocator.free(self.inner.res_buf);
    }

    /// Clears screen using ANSI escape sequence
    pub fn cls(self: *Self) !void {
        try self.write("\x1b[2J\x1b[H");
    }

    /// Set buffer size for specificed file buffer
    pub fn setBufferSize(self: *Self, file_buffer: FileBuffer, size: usize) !void {
        const allocator = self.inner.allocator;
        
        switch (file_buffer) {
            .stdout => try allocator.realloc(self.inner.stdout_buf, size),
            .stderr => try allocator.realloc(self.inner.stdout_buf, size),
            .stdin => try allocator.realloc(self.inner.stdout_buf, size),
        }
    }
    
    /// Write and flush to stdout
    pub fn write(self: *Self, bytes: []const u8) !void {
        const writer = &self.stdout.interface;
        _ = try writer.write(bytes);
        try writer.flush();
    }

    /// Print, format and flush to stdout
    pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        const writer = &self.stdout.interface;
        try writer.print(fmt, args);
        try writer.flush();
    }

    /// Write bytes and flush to stdout with new line
    pub fn writeln(self: *Self, bytes: []const u8) !void {
        try self.print("{s}\n", .{bytes});
    }

    /// Write to stdout without flushing
    pub fn writeAndHold(self: *Self, bytes: []const u8) !void {
        _ = try self.stdout.interface.write(bytes);
    }

    /// Print and format to stdout without flushing 
    pub fn printAndHold(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        try self.stdout.interface.print(fmt, args);
    }

    /// Flush stdout 
    pub fn flushStdout(self: *Self) !void {
        try self.stdout.interface.flush();
    }

    /// Print and flush to stderr and exit program with error-code 
    pub fn errorPrint(self: *Self, comptime fmt: []const u8, args: anytype, err_code: u8) !void {
        const writer = &self.stderr.interface;
        try writer.print(fmt, args);
        try writer.flush();

        std.process.exit(err_code);
    }

    /// Wait for stdin input to be read with newline as the delimiter. 
    /// The response will be overwritten in memory next time this input function is called 
    pub fn input(self: *Self, comptime prompt: ?[]const u8, args: anytype) ![]const u8 {
        if(prompt) |p| try self.print(p, args);
        
        const res = try self.stdin.interface.takeDelimiter('\n') orelse return error.EndOfStream;
        
        if(res.len > self.inner.res_buf.len) return error.BufSizeTooSmall;
        @memcpy(self.inner.res_buf[0..res.len], res);
        return self.inner.res_buf[0..res.len];
    }

    /// Wait for stdin input to be read with newline as the delimiter. 
    /// Store input in a separate buffer.
    pub fn captureInputBuf(self: *Self, comptime prompt: ?[]const u8, args: anytype, buf: []u8) ![]const u8 {
        if(prompt) |p| try self.print(p, args);
        
        const res = try self.stdin.interface.takeDelimiter('\n') orelse return error.EndOfStream;
        
        if(res.len > self.inner.res_buf.len) return error.BufSizeTooSmall;
        @memcpy(buf, res);
        return buf[0..res.len];
    }

    /// Wait for stdin input to be read with newline as the delimiter. 
    /// Allocate memory for input.  Memory is owned by the caller
    pub fn captureInputAlloc(self: *Self, comptime prompt: ?[]const u8, args: anytype, allocator: std.mem.Allocator) ![]const u8 {
        if(prompt) |p| try self.print(p, args);
        
        const res = try self.stdin.interface.takeDelimiter('\n') orelse return error.EndOfStream;
        
        if(res.len > self.inner.res_buf.len) return error.BufSizeTooSmall;
        return try allocator.dupe(u8, res);
    }
};

const Inner = struct {
    allocator: std.mem.Allocator, 
    io: std.Io, 
    
    stdout_buf: []u8 = undefined,
    stderr_buf: []u8 = undefined,
    stdin_buf: []u8 = undefined,
    res_buf: []u8 = undefined,
};

test "stdio" {
    const gpa = std.testing.allocator;
    const io = std.testing.io;

    var stdio = try StdIo.init(gpa, io, 1024);
    defer stdio.deinit();
}
