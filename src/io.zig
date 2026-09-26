const std = @import("std");

pub fn bufferedPrint(io: std.Io, str: []const u8) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(str);
    try stdout.flush();
}
pub fn bufferedPrintln(io: std.Io, str: []const u8) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(str);
    try stdout.writeByte('\n');
    try stdout.flush();
}
pub fn bufferedPrintf(io: std.Io, comptime fmt: []const u8, args: anytype) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(fmt, args);
    try stdout.flush();
}

test "bufferedPrint" {
    const io = std.testing.io;
    try bufferedPrint(io, "Hello, World!");
    try bufferedPrintln(io, "Hello, World with newline!");
    try bufferedPrintf(io, "Hello, {s} with formatted print!\n", .{"World"});
}
