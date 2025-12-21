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
    } else if (std.mem.eql(u8, first, "add")) {
        var second = it.next() orelse {
            try wannasleep.addError("No arguments provided for 'add' command.");
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.addHelp();
        } else {
            // Parse args: --message, --tags, --deadline
            var tags_array = try std.ArrayList([]const u8).initCapacity(allocator, 4);
            defer tags_array.deinit(allocator);
            var message: ?[]const u8 = null;
            var deadline: ?[]const u8 = null;
            while (true) {
                if (std.mem.eql(u8, second, "--message") or std.mem.eql(u8, second, "-m")) {
                    const msg = it.next() orelse {
                        try wannasleep.addError("No message provided for '--message' flag.");
                        return;
                    };
                    message = msg;
                } else if (std.mem.eql(u8, second, "--tags") or std.mem.eql(u8, second, "-t")) {
                    const tags_str = it.next() orelse {
                        try wannasleep.addError("No tags provided for '--tags' flag.");
                        return;
                    };
                    var tags_split = std.mem.splitAny(u8, tags_str, ",");
                    while (tags_split.next()) |tag| {
                        try tags_array.append(allocator, tag);
                    }
                } else if (std.mem.eql(u8, second, "--deadline") or std.mem.eql(u8, second, "-d")) {
                    const dl = it.next() orelse {
                        try wannasleep.addError("No deadline provided for '--deadline' flag.");
                        return;
                    };
                    deadline = dl;
                } else {
                    try wannasleep.addError("Unknown argument provided to 'add' command.");
                    return;
                }
                const next_arg = it.next() orelse break;
                second = next_arg;
            }
            if (message == null) {
                try wannasleep.addError("Missing required description for the todo item.");
                return;
            }
            const tags = try tags_array.toOwnedSlice(allocator);
            defer allocator.free(tags);
            wannasleep.addRun(allocator, message.?, tags, deadline) catch |err| switch (err) {
                wannasleep.Errors.InvalidHUIDString => {
                    try wannasleep.addError("Invalid deadline HUID string.");
                },
                else => return err,
            };
        }
    } else if (std.mem.eql(u8, first, "list")) {
        var second = it.next() orelse {
            try wannasleep.listRun(allocator, false, false, false, false, false);
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.listHelp();
        } else {
            // Parse flags: --show-status, --show-huid, --show-tags, --show-deadline, --print-inactive
            var show_status = false;
            var show_huid = false;
            var show_tags = false;
            var show_deadline = false;
            var print_inactive = false;
            while (true) {
                if (std.mem.eql(u8, second, "--status") or std.mem.eql(u8, second, "-s")) {
                    show_status = true;
                } else if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
                    show_huid = true;
                } else if (std.mem.eql(u8, second, "--tags") or std.mem.eql(u8, second, "-t")) {
                    show_tags = true;
                } else if (std.mem.eql(u8, second, "--deadline") or std.mem.eql(u8, second, "-d")) {
                    show_deadline = true;
                } else if (std.mem.eql(u8, second, "--all") or std.mem.eql(u8, second, "-a")) {
                    print_inactive = true;
                } else if ((second.len > 2 or second.len <= 6) and second[0] == '-') {
                    var seen = [_]bool{false} ** 5;
                    var truth_count: usize = 0;
                    for (second[1..]) |c| {
                        switch (c) {
                            'u' => if (seen[0]) break else {
                                truth_count += 1;
                                seen[0] = true;
                            },
                            's' => if (seen[1]) break else {
                                truth_count += 1;
                                seen[1] = true;
                            },
                            't' => if (seen[2]) break else {
                                truth_count += 1;
                                seen[2] = true;
                            },
                            'd' => if (seen[3]) break else {
                                truth_count += 1;
                                seen[3] = true;
                            },
                            'a' => if (seen[4]) break else {
                                truth_count += 1;
                                seen[4] = true;
                            },
                            else => break,
                        }
                    }
                    if (truth_count != second.len - 1) {
                        try wannasleep.bufferedPrintf("Error: Unknown flag {s} provided to 'list' command.\n", .{second});
                        return wannasleep.listHelp();
                    }
                    if (seen[0]) show_huid = true;
                    if (seen[1]) show_status = true;
                    if (seen[2]) show_tags = true;
                    if (seen[3]) show_deadline = true;
                    if (seen[4]) print_inactive = true;
                } else {
                    try wannasleep.bufferedPrintf("Error: Unknown flag {s} provided to 'list' command.\n", .{second});
                    return wannasleep.listHelp();
                }
                const next_arg = it.next() orelse break;
                second = next_arg;
            }
            try wannasleep.listRun(allocator, print_inactive, show_status, show_huid, show_tags, show_deadline);
        }
    } else if (std.mem.eql(u8, first, "cancel")) {
        const second = it.next() orelse {
            try wannasleep.bufferedPrint("Error: No arguments provided for 'cancel' command.\n");
            try wannasleep.cancelHelp();
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.cancelHelp();
        } else if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
            const huid_str = it.next() orelse {
                try wannasleep.bufferedPrint("Error: No HUID provided for '--huid' flag.\n");
                return wannasleep.cancelHelp();
            };
            try wannasleep.cancelRun(allocator, huid_str);
        } else {
            try wannasleep.cancelRun(allocator, second);
        }
    } else if (std.mem.eql(u8, first, "finish")) {
        const second = it.next() orelse {
            try wannasleep.bufferedPrint("Error: No arguments provided for 'finish' command.\n");
            try wannasleep.finishHelp();
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.finishHelp();
        } else if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
            const huid_str = it.next() orelse {
                try wannasleep.bufferedPrint("Error: No HUID provided for '--huid' flag.\n");
                return wannasleep.cancelHelp();
            };
            try wannasleep.finishRun(allocator, huid_str);
        } else {
            try wannasleep.finishRun(allocator, second);
        }
    } else if (std.mem.eql(u8, first, "remind")) {
        var second = it.next() orelse {
            try wannasleep.remindRun(allocator, false, false, false, null, null);
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.remindHelp();
        } else {
            // Parse flags: --show-huid, --show-tags, --show-deadline
            var show_huid = false;
            var show_tags = false;
            var show_deadline = false;
            var start_huid_str: ?[]const u8 = null;
            var end_huid_str: ?[]const u8 = null;
            while (true) {
                if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
                    show_huid = true;
                } else if (std.mem.eql(u8, second, "--tags") or std.mem.eql(u8, second, "-t")) {
                    show_tags = true;
                } else if (std.mem.eql(u8, second, "--deadline") or std.mem.eql(u8, second, "-d")) {
                    show_deadline = true;
                } else if (std.mem.eql(u8, second, "-ut") or std.mem.eql(u8, second, "-tu")) {
                    show_huid = true;
                    show_tags = true;
                } else if (std.mem.eql(u8, second, "-ud") or std.mem.eql(u8, second, "-du")) {
                    show_huid = true;
                    show_deadline = true;
                } else if (std.mem.eql(u8, second, "-td") or std.mem.eql(u8, second, "-dt")) {
                    show_tags = true;
                    show_deadline = true;
                } else if (std.mem.eql(u8, second, "-utd") or std.mem.eql(u8, second, "-udt") or
                    std.mem.eql(u8, second, "-tud") or std.mem.eql(u8, second, "-tdu") or
                    std.mem.eql(u8, second, "-dut") or std.mem.eql(u8, second, "-dtu"))
                {
                    show_huid = true;
                    show_tags = true;
                    show_deadline = true;
                } else if (std.mem.eql(u8, second, "--start") or std.mem.eql(u8, second, "-s")) {
                    const sh = it.next() orelse {
                        try wannasleep.bufferedPrintf("Error: No start HUID provided for '--start' flag.\n", .{});
                        return wannasleep.remindHelp();
                    };
                    start_huid_str = sh;
                } else if (std.mem.eql(u8, second, "--end") or std.mem.eql(u8, second, "-e")) {
                    const eh = it.next() orelse {
                        try wannasleep.bufferedPrintf("Error: No end HUID provided for '--end' flag.\n", .{});
                        return wannasleep.remindHelp();
                    };
                    end_huid_str = eh;
                } else {
                    try wannasleep.bufferedPrintf("Error: Unknown flag {s} provided to 'remind' command.\n", .{second});
                    return wannasleep.remindHelp();
                }
                const next_arg = it.next() orelse break;
                second = next_arg;
            }
            try wannasleep.remindRun(allocator, show_huid, show_tags, show_deadline, start_huid_str, end_huid_str);
        }
    } else if (std.mem.eql(u8, first, "remove")) {
        const second = it.next() orelse {
            try wannasleep.bufferedPrint("Error: No arguments provided for 'remove' command.\n");
            try wannasleep.removeHelp();
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.removeHelp();
        } else if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
            const huid_str = it.next() orelse {
                try wannasleep.bufferedPrint("Error: No HUID provided for '--huid' flag.\n");
                return wannasleep.removeHelp();
            };
            try wannasleep.removeRun(allocator, huid_str);
        } else {
            try wannasleep.removeRun(allocator, second);
        }
    } else if (std.mem.eql(u8, first, "author")) {
        try wannasleep.author(); // Why would you put any other arguments after author?
    } else {
        try wannasleep.unknownCommand(first);
    }
}
