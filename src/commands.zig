const std = @import("std");
const builtin = @import("builtin");
const HUID = @import("huid.zig").HUID;
const TODO = @import("todo.zig").TODO;
const TODOPrintOptions = @import("todo.zig").TODOPrintOptions;
const storage = @import("storage.zig");
const io = @import("io.zig");

const build_version = "0.1.2";
const build_version_detail = "-nightly-2026-01-15";

pub fn init() !void {
    const cwd = std.fs.cwd();
    // Ensure the directory exists before opening it
    cwd.makeDir(".todo") catch |err| {
        if (err != std.fs.SelfExePathError.PathAlreadyExists) {
            return err;
        }
    };
    var todo_dir = try cwd.openDir(".todo", .{});
    defer todo_dir.close();
    // Ensure the /data directory exists
    todo_dir.makeDir("data") catch |err| {
        if (err != std.fs.SelfExePathError.PathAlreadyExists) {
            return err;
        }
    };
    var data_dir = try todo_dir.openDir("data", .{});
    defer data_dir.close();
    // Create the main.csv file if it doesn't exist
    var main_todo_file = try data_dir.createFile("main.csv", .{});
    defer main_todo_file.close();
    try io.bufferedPrintln("Todo list initialized.");
    return;
}

pub fn initHelp() !void {
    const init_help_msg =
        "Usage: todo init\n\nInitializes a new todo list in the current directory by creating a .todo directory with necessary files.\nIf the .todo directory already exists, it will not overwrite existing files.\nExample:\n    $ todo init\n    Todo list initialized.\n";
    try io.bufferedPrintln(init_help_msg);
}

pub fn addHelp() !void {
    const add_help_msg =
        \\Usage: todo add [-h | --help] [-m] <message> [-t <tag1,tag2,...>] [-d <deadline>]
        \\
        \\Adds a new todo item with the specified description, optional tags, and optional deadline.
        \\Generates a new HUID for the todo item and prints it.
        \\Options:
        \\    -d, --deadline <deadline>     Deadline for the todo item in HUID format (optional)
        \\    -h, --help                    When used alone, shows this help message and exits
        \\    -m, --message <message>       Description of the todo item (required, but the flag is optional)
        \\    -t, --tags <tag1,tag2,...>    Comma-separated list of tags for the todo item (optional)
        \\Example:
        \\    $ todo add -m "Finish the report" -t work,urgent -d 20210701-120000
        \\    Todo item added with HUID: 20210630-170000
        \\
    ;
    try io.bufferedPrintln(add_help_msg);
}

pub fn addError(comptime message: []const u8) !void {
    try io.bufferedPrintln("Error: " ++ message ++ "\nUse 'todo add --help' to see usage.");
}

pub fn addRun(
    allocator: std.mem.Allocator,
    message: []const u8,
    tags: []const []const u8,
    deadline_opt: ?[]const u8,
) !void {
    const huid = try HUID.initid(@divFloor(std.time.milliTimestamp(), 1000), allocator);
    var deadline_huid: ?HUID = null;
    if (deadline_opt) |dl_str| {
        const dl_huid = HUID.initstr(dl_str, allocator) catch |err| {
            huid.deinit();
            return err;
        };
        deadline_huid = dl_huid;
    }
    const todo = TODO.init(message, tags, huid, deadline_huid) catch |err| {
        huid.deinit();
        return err;
    };
    defer todo.deinit();
    storage.appendTODOToCSV(allocator, null, todo) catch {
        return addError("Failed to append todo item to CSV file.");
    };
    try io.bufferedPrintf("Todo item added with HUID: {s}\n", .{huid.id_str});
}

pub fn editHelp() !void {
    const edit_help_msg =
        \\Usage: todo edit [-h | --help] [-u] <huid> [-m <message>] [-a | -n | --append] [-t <tag1,tag2,...>] [-d <deadline>] [-c | --complete] [-x | --cancel] [-o | --open]
        \\
        \\Edits an existing todo item identified by its HUID. You can update the description, tags, deadline, or mark it as complete/canceled.
        \\Options:
        \\    -a, --append                      Append to the existing list of tags instead of replacing them, same as -n
        \\    -c, --complete                    Mark the todo item as completed
        \\    -d, --deadline [<deadline> | x]   New deadline for the todo item in HUID format (optional). Use 'x' to remove the deadline.
        \\    -h, --help                        When used alone, shows this help message and exits
        \\    -m, --message <message>           New description of the todo item (optional)
        \\    -n, --append                      Append to the existing list of tags instead of replacing them
        \\    -o, --open                        Mark the todo item as open (not completed nor canceled), overriding -c and -x
        \\    -t, --tags <tag1,tag2,...>        New comma-separated list of tags for the todo item (optional)
        \\    -u, --huid <huid>                 HUID of the todo item to edit (required)
        \\    -x, --cancel                      Mark the todo item as canceled
        \\    -tn                               Special alias for -t -n to append tags, followed by the tags
        \\Short option grouping:
        \\    -a, -c, -x, -o, and -n can be combined, e.g., -cn is equivalent to -c -n
        \\    Note that when -a and -n are combined, they have the same effect as just using one of them.
        \\    Note that when -o is included, -c and -x must not be used in the same option group.
        \\Example:
        \\    $ todo edit -u 20210630-170000 -m "Finish the updated report" -c
        \\
    ;
    try io.bufferedPrintln(edit_help_msg);
}

pub fn editRun(
    allocator: std.mem.Allocator,
    huid_str: []const u8,
    new_message: ?[]const u8,
    tags: ?[]const []const u8,
    append_tags: bool,
    new_deadline_str: ?[]const u8,
    mark_complete: bool,
    mark_canceled: bool,
    mark_open: bool,
) !void {
    var todo_list = try storage.readEntireCSVAsTODOs(allocator, null);
    defer todo_list.deinit(allocator);
    defer {
        for (todo_list.items) |todo| {
            todo.deinit();
        }
    }
    var idx: usize = 0;
    var found: bool = false;
    for (todo_list.items) |todo| {
        if (std.mem.eql(u8, todo.huid.id_str, huid_str)) {
            var new_todo = todo;
            // Found the todo to edit
            if (new_message) |msg| {
                new_todo = try todo.changeDescriptionTransferOwnerships(msg);
            }
            if (tags) |tags_vals| {
                if (append_tags) {
                    new_todo = try new_todo.addTagsTransferOwnerships(tags_vals);
                } else {
                    new_todo = try new_todo.changeTagsTransferOwnerships(tags_vals);
                }
            }
            if (new_deadline_str) |dl_str| {
                if (std.mem.eql(u8, dl_str, "x")) {
                    // Remove deadline
                    new_todo = new_todo.changeDeadlineTransferOwnerships(null);
                } else {
                    const new_deadline_huid = HUID.initstr(dl_str, allocator) catch {
                        return io.bufferedPrintln("Error: Invalid deadline HUID format.");
                    };
                    new_todo = new_todo.changeDeadlineTransferOwnerships(new_deadline_huid);
                }
            }
            if (mark_complete) {
                new_todo = new_todo.completeTransferOwnerships();
            }
            if (mark_canceled) {
                new_todo = new_todo.canceledTransferOwnerships();
            }
            if (mark_open) {
                new_todo = new_todo.openTransferOwnerships();
            }
            todo_list.items[idx] = new_todo;
            found = true;
            break;
        }
        idx += 1;
    }
    if (!found) {
        return io.bufferedPrintln("Error: Todo item with the specified HUID not found.");
    }
    const cwd = std.fs.cwd();
    var todo_dir = try cwd.openDir(".todo", .{});
    defer todo_dir.close();
    var data_dir = try todo_dir.openDir("data", .{});
    defer data_dir.close();
    var main_todo_file = try data_dir.createFile("main.csv", .{ .truncate = true, .read = false });
    defer main_todo_file.close();
    for (todo_list.items) |item| {
        const serialized = try item.serialize();
        defer allocator.free(serialized);
        try main_todo_file.writeAll(serialized);
        try main_todo_file.writeAll("\n");
    }
}

pub fn listHelp() !void {
    const list_help_msg =
        \\Usage: todo list [-h | --help] [-l | --long] [-a | --all] [-d | --deadline] [-s | --status] [-t | --tags] [-u | --huid]
        \\
        \\Lists all todo items with optional filters and display options.
        \\Options:
        \\    -a, --all       Show all items including completed ones
        \\    -d, --deadline  Show the deadline of each item
        \\    -h, --help      When used alone, shows this help message and exits
        \\    -l, --long      Show detailed information for each item (equivalent to -dstu)
        \\    -s, --status    Show the completion status of each item
        \\    -t, --tags      Show the tags associated with each item
        \\    -u, --huid      Show the HUID of each item
        \\Short option grouping:
        \\    All options can be combined, e.g., -asu is equivalent to -a -s -u
        \\    Note that -l can only be combined with -a, as it implies all other display options.
        \\Example:
        \\    $ todo list -a -s -u
        \\
    ;
    try io.bufferedPrintln(list_help_msg);
}

pub fn listRun(
    allocator: std.mem.Allocator,
    print_inactive: bool,
    show_status: bool,
    show_huid: bool,
    show_tags: bool,
    show_deadline: bool,
) !void {
    var todo_list = storage.readEntireCSVAsTODOs(allocator, null) catch {
        return io.bufferedPrint("Error: Failed to read todo list. Did you run 'todo init'?\n");
    };
    defer todo_list.deinit(allocator);
    for (todo_list.items) |todo| {
        if (!print_inactive and (todo.completed or todo.canceled)) {
            todo.deinit();
            continue;
        }
        const options = TODOPrintOptions{
            .print_inactive = print_inactive,
            .show_status = show_status,
            .show_huid = show_huid,
            .show_tags = show_tags,
            .show_deadline = show_deadline,
            .show_description = true,
        };
        const output = try todo.print(options);
        defer allocator.free(output);
        try io.bufferedPrintf("{s}\n", .{output});
        todo.deinit();
    }
}

pub fn remindHelp() !void {
    const remind_help_msg =
        \\Usage: todo remind [-h | --help] [-s <start_huid>] [-e <end_huid>] [-u] [-t] [-d]
        \\
        \\Reminds about todo items that are due within the specified time range.
        \\Options:
        \\    -d, --deadline Show the deadline of each item
        \\    -e, --end      End of the time range in HUID format (inclusive)
        \\    -s, --start    Start of the time range in HUID format (inclusive)
        \\    -t, --tags     Show the tags associated with each item
        \\    -u, --huid     Show the HUID of each item
        \\Short option grouping:
        \\    -u, -t, and -d can be combined, e.g., -ud is equivalent to -u -d
        \\Example:
        \\    $ todo remind -s 20210701-000000 -e 20210707-235959
        \\
    ;
    try io.bufferedPrintln(remind_help_msg);
}

pub fn remindRun(
    allocator: std.mem.Allocator,
    show_huid: bool,
    show_tags: bool,
    show_deadline: bool,
    start_huid_str: ?[]const u8,
    end_huid_str: ?[]const u8,
) !void {
    var start_huid: HUID = undefined;
    var end_huid: ?HUID = null;
    if (start_huid_str) |start_huid_val| {
        start_huid = HUID.initstr(start_huid_val, allocator) catch {
            return io.bufferedPrint("Error: Invalid start HUID format.\n");
        };
    } else {
        start_huid = HUID.initid(@divFloor(std.time.milliTimestamp(), 1000), allocator) catch {
            try io.bufferedPrint("Error: Failed to get current time for start HUID.\n");
            return;
        };
    }
    defer start_huid.deinit();
    if (end_huid_str) |end_huid_val| {
        end_huid = HUID.initstr(end_huid_val, allocator) catch {
            return io.bufferedPrint("Error: Invalid end HUID format.\n");
        };
    }
    defer {
        if (end_huid) |end_huid_val| {
            end_huid_val.deinit();
        }
    }
    var todo_list = storage.readEntireCSVAsTODOs(allocator, null) catch {
        return io.bufferedPrint("Error: Failed to read todo list. Did you run 'todo init'?\n");
    };
    defer todo_list.deinit(allocator);
    for (todo_list.items) |todo| {
        if (todo.deadline) |dl| {
            if (dl.compare(start_huid) >= 0 and
                (end_huid == null or dl.compare(end_huid.?) <= 0))
            {
                const output = try todo.print(TODOPrintOptions{
                    .print_inactive = false,
                    .show_status = true,
                    .show_huid = show_huid,
                    .show_tags = show_tags,
                    .show_deadline = show_deadline,
                    .show_description = true,
                });
                defer allocator.free(output);
                try io.bufferedPrintf("{s}\n", .{output});
            }
        }
        todo.deinit();
    }
}

pub fn cancelHelp() !void {
    const cancel_help_msg =
        \\Usage: todo cancel [-h | --help] [-u | --huid] <huid>
        \\
        \\Cancels a todo item with the specified HUID.
        \\Options:
        \\    -h, --help            When used alone, show this help message and exit
        \\    -u, --huid <huid>     HUID of the todo item to cancel (required, but the flag is optional)
        \\Example:
        \\    $ todo cancel 20210630-170000
        \\    Todo item with HUID 20210630-170000 has been canceled.
        \\
    ;
    try io.bufferedPrintln(cancel_help_msg);
}

pub fn cancelRun(
    allocator: std.mem.Allocator,
    huid_str: []const u8,
) !void {
    const huid = HUID.initstr(huid_str, allocator) catch {
        return io.bufferedPrint("Error: Invalid HUID format.\n");
    };
    defer huid.deinit();
    var todo_list = storage.readEntireCSVAsTODOs(allocator, null) catch {
        return io.bufferedPrint("Error: Failed to read todo list. Did you run 'todo init'?\n");
    };
    defer todo_list.deinit(allocator);
    var found = false;
    var count: usize = 0;
    for (todo_list.items) |todo| {
        if (todo.huid.compare(huid) == 0) {
            if (todo.completed) {
                try io.bufferedPrintf("Error: Todo item with HUID {s} is already completed and cannot be canceled.\n", .{huid.id_str});
                for (todo_list.items) |t| {
                    t.deinit();
                }
                return;
            }
            todo_list.items[count] = todo.canceledTransferOwnerships();
            found = true;
        }
        count += 1;
    }
    if (!found) {
        try io.bufferedPrintf("Error: Todo item with HUID {s} not found.\n", .{huid.id_str});
        for (todo_list.items) |todo| {
            todo.deinit();
        }
        return;
    } else {
        // Rewrite the CSV file
        const cwd = std.fs.cwd();
        var todo_dir = try cwd.openDir(".todo", .{});
        defer todo_dir.close();
        var data_dir = try todo_dir.openDir("data", .{});
        defer data_dir.close();
        var main_todo_file = try data_dir.createFile("main.csv", .{ .truncate = true, .read = false });
        defer main_todo_file.close();
        defer {
            for (todo_list.items) |todo| {
                todo.deinit();
            }
        }
        var first = true;
        for (todo_list.items) |todo| {
            const serialized = try todo.serialize();
            defer allocator.free(serialized);
            if (!first) {
                main_todo_file.writeAll("\n") catch {
                    try io.bufferedPrintln("Error: Failed to write to todo CSV file.");
                    return;
                };
            } else {
                first = false;
            }
            main_todo_file.writeAll(serialized) catch {
                try io.bufferedPrintln("Error: Failed to write to todo CSV file.");
                return;
            };
        }
        try io.bufferedPrintf("Todo item with HUID {s} has been canceled.\n", .{huid.id_str});
    }
}

pub fn finishHelp() !void {
    const finish_help_msg =
        \\Usage: todo finish [-h | --help] [-u | --huid] <huid>
        \\
        \\Marks a todo item with the specified HUID as completed.
        \\Options:
        \\    -h, --help            When used alone, show this help message and exit
        \\    -u, --huid <huid>     HUID of the todo item to mark as completed (required, but the flag is optional)
        \\Example:
        \\    $ todo finish 20210630-170000
        \\    Todo item with HUID 20210630-170000 has been marked as completed.
        \\
    ;
    try io.bufferedPrintln(finish_help_msg);
}

pub fn finishRun(
    allocator: std.mem.Allocator,
    huid_str: []const u8,
) !void {
    const huid = HUID.initstr(huid_str, allocator) catch {
        try io.bufferedPrint("Error: Invalid HUID format.\n");
        return finishHelp();
    };
    defer huid.deinit();
    var todo_list = storage.readEntireCSVAsTODOs(allocator, null) catch {
        try io.bufferedPrint("Error: Failed to read todo list. Did you run 'todo init'?\n");
        return finishHelp();
    };
    defer todo_list.deinit(allocator);
    var found = false;
    var count: usize = 0;
    for (todo_list.items) |todo| {
        if (todo.huid.compare(huid) == 0) {
            if (todo.completed) {
                try io.bufferedPrintf("Error: Todo item with HUID {s} is already completed.\n", .{huid.id_str});
                for (todo_list.items) |t| {
                    t.deinit();
                }
                return;
            } else if (todo.canceled) {
                try io.bufferedPrintf("Warning: Todo item with HUID {s} is canceled. Marking it as completed anyway.\n", .{huid.id_str});
            }
            todo_list.items[count] = todo.completeTransferOwnerships();
            found = true;
        }
        count += 1;
    }
    if (!found) {
        try io.bufferedPrintf("Error: Todo item with HUID {s} not found.\n", .{huid.id_str});
        for (todo_list.items) |todo| {
            todo.deinit();
        }
        return;
    } else {
        // Rewrite the CSV file
        const cwd = std.fs.cwd();
        var todo_dir = try cwd.openDir(".todo", .{});
        defer todo_dir.close();
        var data_dir = try todo_dir.openDir("data", .{});
        defer data_dir.close();
        var main_todo_file = try data_dir.createFile("main.csv", .{ .truncate = true, .read = false });
        defer main_todo_file.close();
        defer {
            for (todo_list.items) |todo| {
                todo.deinit();
            }
        }
        var first = true;
        for (todo_list.items) |todo| {
            const serialized = try todo.serialize();
            defer allocator.free(serialized);
            if (!first) {
                main_todo_file.writeAll("\n") catch {
                    try io.bufferedPrintln("Error: Failed to write to todo CSV file.");
                    return;
                };
            } else {
                first = false;
            }
            main_todo_file.writeAll(serialized) catch {
                try io.bufferedPrintln("Error: Failed to write to todo CSV file.");
                return;
            };
        }
        try io.bufferedPrintf("Todo item with HUID {s} has been marked as completed.\n", .{huid.id_str});
    }
}

pub fn removeHelp() !void {
    const remove_help_msg =
        \\Usage: todo remove [-h | --help] [-u | --huid] <huid>
        \\
        \\Removes a todo item with the specified HUID from the todo list.
        \\The operation is permanent and not recoverable.
        \\Options:
        \\    -h, --help            When used alone, show this help message and exit
        \\    -u, --huid <huid>     HUID of the todo item to remove (required, but the flag is optional)
        \\Example:
        \\    $ todo remove 20210630-170000
        \\    Todo item with HUID 20210630-170000 has been removed.
        \\
    ;
    try io.bufferedPrintln(remove_help_msg);
}

pub fn removeRun(
    allocator: std.mem.Allocator,
    huid_str: []const u8,
) !void {
    const huid = HUID.initstr(huid_str, allocator) catch {
        return io.bufferedPrint("Error: Invalid HUID format.\n");
    };
    defer huid.deinit();
    var todo_list = storage.readEntireCSVAsTODOs(allocator, null) catch {
        return io.bufferedPrint("Error: Failed to read todo list. Did you run 'todo init'?\n");
    };
    defer todo_list.deinit(allocator);
    var found = false;
    var count: usize = 0;
    for (todo_list.items) |todo| {
        if (todo.huid.compare(huid) == 0) {
            todo.deinit();
            found = true;
            // Skip incrementing count to remove the item
        } else {
            todo_list.items[count] = todo;
            count += 1;
        }
    }
    if (!found) {
        try io.bufferedPrintf("Error: Todo item with HUID {s} not found.\n", .{huid.id_str});
        for (todo_list.items) |todo| {
            todo.deinit();
        }
        return;
    } else {
        // Rewrite the CSV file
        const cwd = std.fs.cwd();
        var todo_dir = try cwd.openDir(".todo", .{});
        defer todo_dir.close();
        var data_dir = try todo_dir.openDir("data", .{});
        defer data_dir.close();
        var main_todo_file = try data_dir.createFile("main.csv", .{ .truncate = true, .read = false });
        defer main_todo_file.close();
        defer {
            for (todo_list.items[0..count]) |todo| {
                todo.deinit();
            }
        }
        var first = true;
        for (todo_list.items[0..count]) |todo| {
            const serialized = try todo.serialize();
            defer allocator.free(serialized);
            if (!first) {
                main_todo_file.writeAll("\n") catch {
                    try io.bufferedPrintln("Error: Failed to write to todo CSV file.");
                    return;
                };
            } else {
                first = false;
            }
            main_todo_file.writeAll(serialized) catch {
                try io.bufferedPrintln("Error: Failed to write to todo CSV file.");
                return;
            };
        }
        try io.bufferedPrintf("Todo item with HUID {s} has been removed.\n", .{huid.id_str});
    }
}

pub fn deferHelp() !void {
    const defer_help_msg =
        \\Usage: todo defer [-h | --help] [-u | --huid] <huid> [-w <weeks>] [-D <days>] [-H <hours>] [-m <minutes>] [-S <seconds>]
        \\
        \\Defers the deadline of a todo item with the specified HUID to a new deadline.
        \\Options:
        \\    -h, --help                      When used alone, show this help message and exit
        \\    -H, --hours <hours>             Number of hours to extend the deadline by (used with -e)
        \\    -m, --minutes <minutes>         Number of minutes to extend the deadline by (used with -e)
        \\    -S, --seconds <seconds>         Number of seconds to extend the deadline by (used with -e)
        \\    -w, --weeks <weeks>             Number of weeks to extend the deadline by (used with -e)
        \\    -u, --huid <huid>               HUID of the todo item to defer (required, but the flag is optional)
        \\Example:
        \\    $ todo defer 20210630-170000 -e -D 3 -H 5
        \\    Todo item with HUID 20210630-170000 has been deferred to new deadline 20210703-220000.
        \\
    ;
    try io.bufferedPrintln(defer_help_msg);
}

pub fn deferRun(
    allocator: std.mem.Allocator,
    huid_str: []const u8,
    weeks: u64,
    days: u64,
    hours: u64,
    minutes: u64,
    seconds: u64,
) !void {
    const huid = HUID.initstr(huid_str, allocator) catch {
        return io.bufferedPrint("Error: Invalid HUID format.\n");
    };
    defer huid.deinit();
    var delta_seconds: u64 = 0;
    delta_seconds += seconds;
    delta_seconds += minutes * 60;
    delta_seconds += hours * 3600;
    delta_seconds += days * 86400;
    delta_seconds += weeks * 604800;
    var todo_list = storage.readEntireCSVAsTODOs(allocator, null) catch {
        return io.bufferedPrint("Error: Failed to read todo list. Did you run 'todo init'?\n");
    };
    defer todo_list.deinit(allocator);
    var found = false;
    var copy_deadline: ?HUID = null;
    var count: usize = 0;
    for (todo_list.items) |todo| {
        if (todo.huid.compare(huid) == 0) {
            if (todo.completed) {
                try io.bufferedPrintf("Error: Todo item with HUID {s} is already completed and cannot be deferred.\n", .{huid.id_str});
                for (todo_list.items) |t| {
                    t.deinit();
                }
                return;
            } else if (todo.canceled) {
                try io.bufferedPrintf("Error: Todo item with HUID {s} is canceled and cannot be deferred.\n", .{huid.id_str});
                for (todo_list.items) |t| {
                    t.deinit();
                }
                return;
            }
            _ = todo.deadline orelse {
                try io.bufferedPrintf("Error: Todo item with HUID {s} has no deadline to extend.\n", .{huid.id_str});
                for (todo_list.items) |t| {
                    t.deinit();
                }
                return;
            };
            todo_list.items[count] = try todo.deferDeadlineTransferOwnerships(@as(i64, @intCast(delta_seconds)));
            copy_deadline = todo_list.items[count].deadline;
            found = true;
        }
        count += 1;
    }
    if (!found) {
        try io.bufferedPrintf("Error: Todo item with HUID {s} not found.\n", .{huid.id_str});
        for (todo_list.items) |todo| {
            todo.deinit();
        }
        return;
    } else {
        // Rewrite the CSV file
        const cwd = std.fs.cwd();
        var todo_dir = try cwd.openDir(".todo", .{});
        defer todo_dir.close();
        var data_dir = try todo_dir.openDir("data", .{});
        defer data_dir.close();
        var main_todo_file = try data_dir.createFile("main.csv", .{ .truncate = true, .read = false });
        defer main_todo_file.close();
        defer {
            for (todo_list.items) |todo| {
                todo.deinit();
            }
        }
        var first = true;
        for (todo_list.items) |todo| {
            const serialized = try todo.serialize();
            defer allocator.free(serialized);
            if (!first) {
                main_todo_file.writeAll("\n") catch {
                    try io.bufferedPrintln("Error: Failed to write to todo CSV file.");
                    return;
                };
            } else {
                first = false;
            }
            main_todo_file.writeAll(serialized) catch {
                try io.bufferedPrintln("Error: Failed to write to todo CSV file.");
                return;
            };
        }
        if (copy_deadline) |new_dl| {
            try io.bufferedPrintf("Todo item with HUID {s} has been deferred to new deadline {s}.\n", .{
                huid.id_str,
                new_dl.id_str,
            });
        } else {
            try io.bufferedPrintf("Todo item with HUID {s} has been deferred to new deadline.\n", .{
                huid.id_str,
            });
        }
    }
}

// grep: normal flags -t tags, -u huid, -s status, -d deadline, -a include inactive, -m message keyword
// grep: -b grep string in both description and tags, -i ignore case
pub fn grepHelp() !void {
    const grep_help_msg =
        \\Usage: todo grep [-h | --help] [options] [<keyword>]
        \\
        \\Searches todo items by keyword in description or tags with optional filters.
        \\Options:
        \\    -a, --all                 Include inactive items (completed or canceled)
        \\    -b, --both                Search keyword in both description and tags
        \\    -d, --deadline <deadline> Filter by deadline HUID
        \\    -h, --help                When used alone, show this help message and exit
        \\    -i, --ignore-case         Ignore case when searching for keyword
        \\    -m, --message             Search keyword in description of the TODO item
        \\    -s, --status <status>     Filter by status: 'o' for open, 'c' for completed, 'x' for canceled
        \\    -t, --tags                Search keyword in tags of the TODO item
        \\    -u, --huid <huid>         Filter by specific HUID
        \\Short option grouping:
        \\    -a, -b, -i, -m, -t can be combined, e.g., -abim is equivalent to -a -b -i -m
        \\    Note that when -b is included, -m and -t must not be used in the same option group.
        \\Example:
        \\    $ todo grep -ti report
        \\
    ;
    try io.bufferedPrintln(grep_help_msg);
}

pub fn grepRun(
    allocator: std.mem.Allocator,
    keyword: ?[]const u8,
    search_in_tags: bool,
    search_in_message: bool,
    huid_str: ?[]const u8,
    status_filter: ?u8,
    deadline_str: ?[]const u8,
    include_inactive: bool,
    ignore_case: bool,
) !void {
    var todo_list = storage.readEntireCSVAsTODOs(allocator, null) catch {
        try io.bufferedPrint("Error: Failed to read todo list. Did you run 'todo init'?\n");
        return;
    };
    defer todo_list.deinit(allocator);
    var huid_filter: ?HUID = null;
    if (huid_str) |huid_val| {
        huid_filter = HUID.initstr(huid_val, allocator) catch {
            try io.bufferedPrint("Error: Invalid HUID format for filter.\n");
            return;
        };
    }
    defer {
        if (huid_filter) |huid_val| {
            huid_val.deinit();
        }
    }
    var deadline_filter: ?HUID = null;
    if (deadline_str) |dl_val| {
        deadline_filter = HUID.initstr(dl_val, allocator) catch {
            try io.bufferedPrint("Error: Invalid deadline HUID format for filter.\n");
            return;
        };
    }
    defer {
        if (deadline_filter) |dl_val| {
            dl_val.deinit();
        }
    }
    for (todo_list.items) |todo| {
        if (!include_inactive and (todo.completed or todo.canceled)) {
            todo.deinit();
            continue;
        }
        if (huid_filter) |huid_val| {
            if (todo.huid.compare(huid_val) != 0) {
                todo.deinit();
                continue;
            }
        }
        if (status_filter) |status| {
            if (status == 'o' and (todo.completed or todo.canceled)) {
                todo.deinit();
                continue;
            } else if (status == 'c' and !todo.completed) {
                todo.deinit();
                continue;
            } else if (status == 'x' and !todo.canceled) {
                todo.deinit();
                continue;
            }
        }
        if (deadline_filter) |dl_val| {
            if (todo.deadline) |todo_dl| {
                if (todo_dl.compare(dl_val) != 0) {
                    todo.deinit();
                    continue;
                }
            } else {
                todo.deinit();
                continue;
            }
        }
        var found_in_message = false;
        if (keyword) |kw| {
            if (search_in_message) {
                if (ignore_case) {
                    if (todo.matchesDescriptionInsensitive(kw)) {
                        found_in_message = true;
                    }
                } else {
                    if (todo.matchesDescription(kw)) {
                        found_in_message = true;
                    }
                }
            }
            if (search_in_tags) {
                if (ignore_case) {
                    if (todo.matchesTagInsensitive(kw)) {
                        found_in_message = true;
                    }
                } else {
                    if (todo.matchesTag(kw)) {
                        found_in_message = true;
                    }
                }
            }
        } else {
            found_in_message = true; // No keyword means match all
        }
        if (found_in_message) {
            const output = try todo.print(TODOPrintOptions{
                .print_inactive = include_inactive,
                .show_status = true,
                .show_huid = true,
                .show_tags = true,
                .show_deadline = true,
                .show_description = true,
            });
            defer allocator.free(output);
            try io.bufferedPrintln(output);
        }
        todo.deinit();
    }
}

pub fn help() !void {
    const help_msg =
        \\Usage: todo [-v | --version] [-h | --help] <command> [<args>]
        \\Commands:
        \\    add       Add a new todo item and print generated HUID
        \\    author    Show author information
        \\    cancel    Cancel a todo item
        \\    defer     Defer a todo item's due time by a specified duration
        \\    edit      Edit the description or tags of a todo item
        \\    finish    Mark a todo item as completed
        \\    grep      Search todo items by keyword or tag
        \\    help      Show this help message and exit
        \\    huid      Generate a new HUID based on the current time
        \\    init      Creates an empty todo list in the current directory
        \\    list      List all todo items
        \\    listall   List all todo items including completed ones (equivalent to 'list -la')
        \\    remind    Remind about todo items due within a time range
        \\    remove    Remove a todo item
        \\    version   Show version information
        \\Common Options:
        \\    -h, --help       Show this help message and exit
        \\    -v, --version    Show version information and exit
        \\    -d, --deadline   Specify the deadline for the todo item in HUID format
        \\    -m, --message    Specify the description for the todo item (used with 'add' and 'edit' commands)
        \\    -t, --tags       Comma-separated list of tags for the todo item
        \\    -u, --huid       Specify the HUID of the todo item to operate on
        \\Short option grouping:
        \\    Most single-letter options can be grouped together. For example, -as is equivalent to -a -s.
        \\    When no command is specified, the supported options are -h/--help and -v/--version,
        \\    and option grouping between them is allowed (e.g., -vh is equivalent to -v -h).
        \\For detailed help on a specific command, run: todo <command> --help
    ;
    try io.bufferedPrintln(help_msg);
}

pub fn version() !void {
    try io.bufferedPrintln("todo (wannasleep) version " ++ build_version ++ " (Zig " ++ builtin.zig_version_string ++ ")");
}

pub fn versionHelp() !void {
    const version_help_msg =
        "todo (wannasleep) version " ++ build_version ++ "\nA simple command-line todo list manager written in Zig.\nBuild Information:\n    Build Version: " ++ build_version ++ build_version_detail ++ "\n    Zig Version: " ++ builtin.zig_version_string ++ "\nAuthor: William Wu";
    try io.bufferedPrintln(version_help_msg);
}

pub fn author() !void {
    try io.bufferedPrintln("Created by William Wu");
}

pub fn unknownCommand(cmd: []const u8) !void {
    try io.bufferedPrintf("'{s}' is not a recognized command. See 'todo --help' for a list of available commands.\n", .{cmd});
}

pub fn huidRun(allocator: std.mem.Allocator) !void {
    const huidid = try HUID.initid(@divFloor(std.time.milliTimestamp(), 1000), allocator);
    defer huidid.deinit();
    try io.bufferedPrintf("{s}\n", .{huidid.id_str});
}

pub fn huidHelp() !void {
    const huid_help_msg =
        "Usage: todo huid\n\nGenerates a new Human Readable Unique Identifier (HUID) based on the current time.\nThe HUID format is YYYYMMDD-HHMMSS, representing the year, month, day, hour, minute, and second of creation.\nTo avoid conflicts, you should not generated HUIDs very often.\nExample:\n    $ todo huid\n    20231220-153045\n";
    try io.bufferedPrintln(huid_help_msg);
}

pub fn huidExplain() !void {
    const huid_explain_msg =
        \\ HUID (Human Readable Unique Identifier):
        \\
        \\ A HUID is a unique identifier format designed to be both human-readable and sortable by creation time.
        \\ The format of a HUID is: YYYYMMDD-HHMMSS
        \\ Where:
        \\    YYYY - 4-digit year
        \\    MM   - 2-digit month (01 to 12)
        \\    DD   - 2-digit day of the month (01 to 31)
        \\    HH   - 2-digit hour in 24-hour format (00 to 23)
        \\    MM   - 2-digit minute (00 to 59)
        \\    SS   - 2-digit second (00 to 59)
        \\
        \\ Example HUID: 20231220-153045
        \\ This HUID represents December 20, 2023 at 15:30:45 (3:30:45 PM).
        \\ HUIDs are generated based on the current time when created.
        \\ This means that HUIDs are unique as long as they are not generated multiple times within the same second.
        \\ HUIDs are sortable in chronological order, making it easy to track the creation time of items.
        \\
        \\ Creator: Tsoding
        \\ Original Video: https://www.youtube.com/watch?v=QH6KOEVnSZA
        \\ Adapted by: William Wu (This is not an entirely faithful implementation of the original concept.)
    ;
    try io.bufferedPrintln(huid_explain_msg);
}
