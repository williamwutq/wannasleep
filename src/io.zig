const std = @import("std");

pub fn bufferedPrint(str: []const u8) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(str);
    try stdout.flush();
}
pub fn bufferedPrintln(str: []const u8) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(str);
    try stdout.writeByte('\n');
    try stdout.flush();
}
pub fn bufferedPrintf(comptime fmt: []const u8, args: anytype) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(fmt, args);
    try stdout.flush();
}

test "bufferedPrint" {
    try bufferedPrint("Hello, World!");
    try bufferedPrintln("Hello, World with newline!");
    try bufferedPrintf("Hello, {s} with formatted print!\n", .{"World"});
}
