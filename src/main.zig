const std = @import("std");
const wannasleep = @import("wannasleep");

pub fn main() !void {
    // Initialize the general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    // Initialize buffset
    var buffset = std.BufSet.init(allocator);
    defer buffset.deinit();
    // Parse command line arguments and run the application
    var it = try std.process.argsWithAllocator(allocator); // ERR Out of memory
    defer it.deinit();
    _ = it.next() orelse {
        return error.InvalidArguments; // This should be program name and never fails
    };
    const first = it.next() orelse {
        try wannasleep.help();
        return;
    };
    if (std.mem.eql(u8, first, "help")) {
        const second = it.next() orelse {
            try wannasleep.help();
            return;
        };
        if (std.mem.eql(u8, second, "--version") or std.mem.eql(u8, second, "-v") or std.mem.eql(u8, second, "version")) {
            try wannasleep.versionHelp();
        } else if (std.mem.eql(u8, second, "huid")) {
            try wannasleep.versionHelp();
        } else if (std.mem.eql(u8, second, "init")) {
            try wannasleep.initHelp();
        } else {
            try wannasleep.help();
        }
    } else if (std.mem.eql(u8, first, "version")) {
        const second = it.next() orelse {
            try wannasleep.version();
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.versionHelp();
        } else {
            try wannasleep.version();
        }
    } else if (std.mem.eql(u8, first, "huid")) {
        const second = it.next() orelse {
            try wannasleep.huidRun(allocator);
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.huidHelp();
        } else {
            try wannasleep.huidRun(allocator);
        }
    } else if (std.mem.eql(u8, first, "init")) {
        const second = it.next() orelse {
            try wannasleep.init();
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.initHelp();
        } else {
            try wannasleep.init();
        }
    } else if (std.mem.eql(u8, first, "author")) {
        try wannasleep.author(); // Why would you put any other arguments after author?
    } else {
        try wannasleep.unknownCommand(first);
    }
}
