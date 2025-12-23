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
    if (std.mem.eql(u8, first, "help") or std.mem.eql(u8, first, "--help") or std.mem.eql(u8, first, "-h")) {
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
    } else if (std.mem.eql(u8, first, "version") or std.mem.eql(u8, first, "--version") or std.mem.eql(u8, first, "-v")) {
        const second = it.next() orelse {
            try wannasleep.version();
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.versionHelp();
        } else {
            try wannasleep.version();
        }
    } else if (std.mem.eql(u8, first, "-vh") or std.mem.eql(u8, first, "-hv")) {
        try wannasleep.versionHelp();
    } else if (std.mem.eql(u8, first, "huid") or std.mem.eql(u8, first, "--huid") or std.mem.eql(u8, first, "-u")) {
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
            return;
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
                    if (message != null) {
                        try wannasleep.addError("Unknown flag provided to 'add' command.");
                        return;
                    }
                    message = second;
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
    } else if (std.mem.eql(u8, first, "edit")) {
        var second = it.next() orelse {
            try wannasleep.bufferedPrintln("No arguments provided for 'edit' command.\nRun `todo edit --help` for more information.");
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.editHelp();
            return;
        } else {
            // Parse args: --huid, --message, --tags, --deadline, --complete, --cancel
            var huid_str: ?[]const u8 = null;
            var message: ?[]const u8 = null;
            var tags_array = try std.ArrayList([]const u8).initCapacity(allocator, 4);
            defer tags_array.deinit(allocator);
            var deadline: ?[]const u8 = null;
            var mark_complete = false;
            var mark_canceled = false;
            var mark_open = false;
            var append_tags = false;
            while (true) {
                if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
                    const huid_arg = it.next() orelse {
                        try wannasleep.bufferedPrintln("No HUID provided for '--huid' flag.\nRun `todo edit --help` for more information.");
                        return;
                    };
                    huid_str = huid_arg;
                } else if (std.mem.eql(u8, second, "--message") or std.mem.eql(u8, second, "-m")) {
                    const msg = it.next() orelse {
                        try wannasleep.bufferedPrintln("No message provided for '--message' flag.\nRun `todo edit --help` for more information.");
                        return;
                    };
                    message = msg;
                } else if (std.mem.eql(u8, second, "--tags") or std.mem.eql(u8, second, "-t")) {
                    const tags_str = it.next() orelse {
                        try wannasleep.bufferedPrintln("No tags provided for '--tags' flag.\nRun `todo edit --help` for more information.");
                        return;
                    };
                    var tags_split = std.mem.splitAny(u8, tags_str, ",");
                    while (tags_split.next()) |tag| {
                        try tags_array.append(allocator, tag);
                    }
                } else if (std.mem.eql(u8, second, "--append") or std.mem.eql(u8, second, "-n")) {
                    append_tags = true;
                } else if (std.mem.eql(u8, second, "--deadline") or std.mem.eql(u8, second, "-d")) {
                    const dl = it.next() orelse {
                        try wannasleep.bufferedPrintln("No deadline provided for '--deadline' flag.\nRun `todo edit --help` for more information.");
                        return;
                    };
                    deadline = dl;
                } else if (std.mem.eql(u8, second, "--complete") or std.mem.eql(u8, second, "-c")) {
                    mark_complete = true;
                } else if (std.mem.eql(u8, second, "--cancel") or std.mem.eql(u8, second, "-x")) {
                    mark_canceled = true;
                } else if (std.mem.eql(u8, second, "--open") or std.mem.eql(u8, second, "-o")) {
                    mark_open = true;
                } else if ((second.len > 2 or second.len <= 5) and second[0] == '-') {
                    var seen = [_]bool{false} ** 4;
                    var truth_count: usize = 0;
                    for (second[1..]) |c| {
                        switch (c) {
                            'c' => if (seen[0]) break else {
                                truth_count += 1;
                                seen[0] = true;
                            },
                            'x' => if (seen[1]) break else {
                                truth_count += 1;
                                seen[1] = true;
                            },
                            'o' => if (seen[2]) break else {
                                truth_count += 1;
                                seen[2] = true;
                            },
                            'n' => if (seen[3]) break else {
                                truth_count += 1;
                                seen[3] = true;
                            },
                            else => break,
                        }
                    }
                    if (truth_count != second.len - 1) {
                        try wannasleep.bufferedPrintf("Error: Unknown flag {s} provided to 'edit' command.\nRun `todo edit --help` for more information.\n", .{second});
                        return;
                    }
                    // If o is included, c and x must not be used
                    if (seen[2]) {
                        if (seen[0] or seen[1]) {
                            try wannasleep.bufferedPrintf("Error: Conflicting flags provided to 'edit' command.\nRun `todo edit --help` for more information.\n", .{});
                            return;
                        }
                    }
                    if (seen[0]) mark_complete = true;
                    if (seen[1]) mark_canceled = true;
                    if (seen[2]) mark_open = true;
                    if (seen[3]) append_tags = true;
                } else {
                    huid_str = second;
                }
                const next_arg = it.next() orelse break;
                second = next_arg;
            }
            if (huid_str == null) {
                try wannasleep.bufferedPrintln("Missing required HUID for the todo item to edit.\nRun `todo edit --help` for more information.");
                return;
            }
            const tags = try tags_array.toOwnedSlice(allocator);
            defer allocator.free(tags);
            try wannasleep.editRun(
                allocator,
                huid_str.?,
                message,
                tags,
                append_tags,
                deadline,
                mark_complete,
                mark_canceled,
                mark_open,
            );
        }
    } else if (std.mem.eql(u8, first, "list")) {
        var second = it.next() orelse {
            try wannasleep.listRun(allocator, false, false, false, false, false);
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.listHelp();
        } else {
            // Parse flags: --status, --huid, --tags, --deadline, --all
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
                } else if (std.mem.eql(u8, second, "--long") or std.mem.eql(u8, second, "-l")) {
                    // As -dstu
                    show_deadline = true;
                    show_status = true;
                    show_huid = true;
                    show_tags = true;
                } else if (std.mem.eql(u8, second, "-al") or std.mem.eql(u8, second, "-la")) {
                    // As -adstu
                    show_deadline = true;
                    show_status = true;
                    show_huid = true;
                    show_tags = true;
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
                        try wannasleep.bufferedPrintf("Error: Unknown flag {s} provided to 'list' command.\nRun `todo list --help` for more information.\n", .{second});
                        return;
                    }
                    if (seen[0]) show_huid = true;
                    if (seen[1]) show_status = true;
                    if (seen[2]) show_tags = true;
                    if (seen[3]) show_deadline = true;
                    if (seen[4]) print_inactive = true;
                } else {
                    try wannasleep.bufferedPrintf("Error: Unknown flag {s} provided to 'list' command.\nRun `todo list --help` for more information.\n", .{second});
                    return;
                }
                const next_arg = it.next() orelse break;
                second = next_arg;
            }
            try wannasleep.listRun(allocator, print_inactive, show_status, show_huid, show_tags, show_deadline);
        }
    } else if (std.mem.eql(u8, first, "grep")) {
        var second = it.next() orelse {
            try wannasleep.grepRun(
                allocator,
                "",
                false,
                true,
                null,
                null,
                null,
                false,
                false,
            );
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.grepHelp();
        } else {
            // Parse flags
            var search_tags = false;
            var search_message = true;
            var print_inactive = false;
            var keyword: ?[]const u8 = null;
            var huid_str: ?[]const u8 = null;
            var status_filter_char: ?u8 = null;
            var deadline_str: ?[]const u8 = null;
            var ignore_case = false;
            while (true) {
                if (std.mem.eql(u8, second, "--status") or std.mem.eql(u8, second, "-s")) {
                    const status_str = it.next() orelse {
                        try wannasleep.bufferedPrint("Error: No status character provided for '--status' flag.\nRun `todo grep --help` for more information.\n");
                        return;
                    };
                    if (status_str.len != 1 or
                        (status_str[0] != 'x' and status_str[0] != 'c' and status_str[0] != 'o'))
                    {
                        try wannasleep.bufferedPrintf("Error: Invalid status character {s} provided for '--status' flag.\nRun `todo grep --help` for more information.\n", .{status_str});
                        return;
                    }
                    status_filter_char = status_str[0];
                } else if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
                    const huid_str_arg = it.next() orelse {
                        try wannasleep.bufferedPrint("Error: No HUID provided for '--huid' flag.\nRun `todo grep --help` for more information.\n");
                        return;
                    };
                    huid_str = huid_str_arg;
                } else if (std.mem.eql(u8, second, "--deadline") or std.mem.eql(u8, second, "-d")) {
                    const dl_str = it.next() orelse {
                        try wannasleep.bufferedPrint("Error: No deadline HUID provided for '--deadline' flag.\nRun `todo grep --help` for more information.\n");
                        return;
                    };
                    deadline_str = dl_str;
                } else if (std.mem.eql(u8, second, "--ignore-case") or std.mem.eql(u8, second, "-i")) {
                    ignore_case = true;
                } else if (std.mem.eql(u8, second, "--message") or std.mem.eql(u8, second, "-m")) {
                    search_message = true;
                } else if (std.mem.eql(u8, second, "--tags") or std.mem.eql(u8, second, "-t")) {
                    search_tags = true;
                } else if (std.mem.eql(u8, second, "--both") or std.mem.eql(u8, second, "-b") or
                    std.mem.eql(u8, second, "-mt") or std.mem.eql(u8, second, "-tm"))
                {
                    search_message = true;
                    search_tags = true;
                } else if (std.mem.eql(u8, second, "--all") or std.mem.eql(u8, second, "-a")) {
                    print_inactive = true;
                } else if ((second.len > 2 or second.len <= 6) and second[0] == '-') {
                    var seen = [_]bool{false} ** 5;
                    var truth_count: usize = 0;
                    for (second[1..]) |c| {
                        switch (c) {
                            'i' => if (seen[0]) break else {
                                truth_count += 1;
                                seen[0] = true;
                            },
                            'm' => if (seen[1]) break else {
                                truth_count += 1;
                                seen[1] = true;
                            },
                            't' => if (seen[2]) break else {
                                truth_count += 1;
                                seen[2] = true;
                            },
                            'b' => if (seen[3]) break else {
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
                        try wannasleep.bufferedPrintf("Error: Unknown flag {s} provided to 'grep' command.\nRun `todo grep --help` for more information.\n", .{second});
                        return;
                    }
                    // If b, not m and t
                    if (seen[3]) {
                        if (seen[1] or seen[2]) {
                            try wannasleep.bufferedPrint("Error: Conflicting flags provided to 'grep' command.\nRun `todo grep --help` for more information.\n");
                            return;
                        }
                    }
                    if (seen[0]) ignore_case = true;
                    if (seen[1]) search_message = true;
                    if (seen[2]) search_tags = true;
                    if (seen[3]) {
                        search_message = true;
                        search_tags = true;
                    }
                    if (seen[4]) print_inactive = true;
                } else if (keyword == null) {
                    keyword = second;
                } else {
                    try wannasleep.bufferedPrintf("Error: Unknown flag {s} provided to 'grep' command.\nRun `todo grep --help` for more information.\n", .{second});
                    return;
                }
                const next_arg = it.next() orelse break;
                second = next_arg;
            }
            try wannasleep.grepRun(
                allocator,
                keyword,
                search_tags,
                search_message,
                huid_str,
                status_filter_char,
                deadline_str,
                print_inactive,
                ignore_case,
            );
        }
    } else if (std.mem.eql(u8, first, "cancel")) {
        const second = it.next() orelse {
            try wannasleep.bufferedPrint("Error: No arguments provided for 'cancel' command.\nRun `todo cancel --help` for more information.\n");
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.cancelHelp();
        } else if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
            const huid_str = it.next() orelse {
                try wannasleep.bufferedPrint("Error: No HUID provided for '--huid' flag.\nRun `todo cancel --help` for more information.\n");
                return;
            };
            try wannasleep.cancelRun(allocator, huid_str);
        } else {
            try wannasleep.cancelRun(allocator, second);
        }
    } else if (std.mem.eql(u8, first, "finish")) {
        const second = it.next() orelse {
            try wannasleep.bufferedPrint("Error: No arguments provided for 'finish' command.\nRun `todo finish --help` for more information.\n");
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.finishHelp();
        } else if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
            const huid_str = it.next() orelse {
                try wannasleep.bufferedPrint("Error: No HUID provided for '--huid' flag.\nRun `todo finish --help` for more information.\n");
                return;
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
            return;
        } else {
            // Parse flags: --huid, --tags, --deadline
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
                        try wannasleep.bufferedPrint("Error: No start HUID provided for '--start' flag.\nRun `todo remind --help` for more information.\n");
                        return;
                    };
                    start_huid_str = sh;
                } else if (std.mem.eql(u8, second, "--end") or std.mem.eql(u8, second, "-e")) {
                    const eh = it.next() orelse {
                        try wannasleep.bufferedPrint("Error: No end HUID provided for '--end' flag.\nRun `todo remind --help` for more information.\n");
                        return;
                    };
                    end_huid_str = eh;
                } else {
                    try wannasleep.bufferedPrintf("Error: Unknown flag {s} provided to 'remind' command.\nRun `todo remind --help` for more information.", .{second});
                    return;
                }
                const next_arg = it.next() orelse break;
                second = next_arg;
            }
            try wannasleep.remindRun(allocator, show_huid, show_tags, show_deadline, start_huid_str, end_huid_str);
        }
    } else if (std.mem.eql(u8, first, "remove")) {
        const second = it.next() orelse {
            try wannasleep.bufferedPrint("Error: No arguments provided for 'remove' command.\nRun `todo remove --help` for more information.\n");
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.removeHelp();
        } else if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
            const huid_str = it.next() orelse {
                try wannasleep.bufferedPrint("Error: No HUID provided for '--huid' flag.\nRun `todo remove --help` for more information.\n");
                return;
            };
            try wannasleep.removeRun(allocator, huid_str);
        } else {
            try wannasleep.removeRun(allocator, second);
        }
    } else if (std.mem.eql(u8, first, "defer")) {
        var second = it.next() orelse {
            try wannasleep.bufferedPrint("Error: No arguments provided for 'defer' command.\nRun `todo defer --help` for more information.\n");
            return;
        };
        if (std.mem.eql(u8, second, "--help") or std.mem.eql(u8, second, "-h")) {
            try wannasleep.deferHelp();
        } else {
            // Parse args: --huid, time delta
            var huid_str: ?[]const u8 = null;
            var weeks: u64 = 0;
            var days: u64 = 0;
            var hours: u64 = 0;
            var minutes: u64 = 0;
            var seconds: u64 = 0;
            while (true) {
                if (std.mem.eql(u8, second, "--huid") or std.mem.eql(u8, second, "-u")) {
                    const huid_arg = it.next() orelse {
                        try wannasleep.bufferedPrint("Error: No HUID provided for '--huid' flag.\nRun `todo defer --help` for more information.\n");
                        return;
                    };
                    huid_str = huid_arg;
                } else if (std.mem.eql(u8, second, "--weeks") or std.mem.eql(u8, second, "-w")) {
                    const weeks_str = it.next() orelse {
                        try wannasleep.bufferedPrint("Error: No weeks value provided for '--weeks' flag.\nRun `todo defer --help` for more information.\n");
                        return;
                    };
                    weeks = try std.fmt.parseInt(u64, weeks_str, 10);
                } else if (std.mem.eql(u8, second, "--days") or std.mem.eql(u8, second, "-D")) {
                    const days_str = it.next() orelse {
                        try wannasleep.bufferedPrint("Error: No days value provided for '--days' flag.\nRun `todo defer --help` for more information.\n");
                        return;
                    };
                    days = try std.fmt.parseInt(u64, days_str, 10);
                } else if (std.mem.eql(u8, second, "--hours") or std.mem.eql(u8, second, "-H")) {
                    const hours_str = it.next() orelse {
                        try wannasleep.bufferedPrint("Error: No hours value provided for '--hours' flag.\nRun `todo defer --help` for more information.\n");
                        return;
                    };
                    hours = try std.fmt.parseInt(u64, hours_str, 10);
                } else if (std.mem.eql(u8, second, "--minutes") or std.mem.eql(u8, second, "-m")) {
                    const minutes_str = it.next() orelse {
                        try wannasleep.bufferedPrint("Error: No minutes value provided for '--minutes' flag.\nRun `todo defer --help` for more information.\n");
                        return;
                    };
                    minutes = try std.fmt.parseInt(u64, minutes_str, 10);
                } else if (std.mem.eql(u8, second, "--seconds") or std.mem.eql(u8, second, "-S")) {
                    const seconds_str = it.next() orelse {
                        try wannasleep.bufferedPrint("Error: No seconds value provided for '--seconds' flag.\nRun `todo defer --help` for more information.\n");
                        return;
                    };
                    seconds = try std.fmt.parseInt(u64, seconds_str, 10);
                } else {
                    huid_str = second;
                }
                const next_arg = it.next() orelse break;
                second = next_arg;
            }
            if (huid_str == null) {
                try wannasleep.bufferedPrint("Error: Missing required HUID for the todo item to defer.\nRun `todo defer --help` for more information.\n");
                return;
            }
            try wannasleep.deferRun(allocator, huid_str.?, weeks, days, hours, minutes, seconds);
        }
    } else if (std.mem.eql(u8, first, "author")) {
        try wannasleep.author(); // Why would you put any other arguments after author?
    } else {
        try wannasleep.unknownCommand(first);
    }
}
