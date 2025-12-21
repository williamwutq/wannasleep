const std = @import("std");
const builtin = @import("builtin");

const build_version = "0.1.2";
const build_version_detail = "-nightly-2025-12-20";

// TODO:
// todo add
// todo list
// todo finish
// todo remind
// todo remove
// todo grep
// todo edit
// todo defer

/// A "todo" item
/// Contains a description, completion status, tags, and a HUID.
pub const TODO = struct {
    completed: bool,
    canceled: bool,
    description: []const u8,
    tags: []const []const u8,
    allocator: std.mem.Allocator,
    huid: HUID,
    deadline: ?HUID,
    /// Initialize a new "todo" item, infer allocator from huid.
    /// The ownership of the huid is transferred to the "todo" item, but the strings are copied.
    pub fn init(
        description: []const u8,
        tags: []const []const u8,
        huid: HUID,
    ) !TODO {
        const allocator = huid.allocator;
        var tag_list = try std.ArrayList([]const u8).initCapacity(allocator, tags.len);
        for (tags) |tag| {
            const dup_tag = try allocator.dupe(u8, tag);
            try tag_list.append(allocator, dup_tag);
        }
        const all_tags = try tag_list.toOwnedSlice(allocator);
        const description_copy = try allocator.dupe(u8, description);
        return TODO{
            .completed = false,
            .canceled = false,
            .description = description_copy,
            .tags = all_tags,
            .allocator = allocator,
            .deadline = null,
            .huid = huid,
        };
    }
    /// Initialize a "todo" item from a CSV row.
    pub fn fromRow(row: []const u8, allocator: std.mem.Allocator) !TODO {
        // Format: huid,[status],deadline,description,tag1,tag2,...
        // Status is either "c" for completed, "x" for canceled, or "o" for pending
        var parts = std.mem.splitAny(u8, row, ",");
        const huid_str = parts.next() orelse return error.InvalidTODOFormat;
        const huid = try HUID.initstr(huid_str, allocator);
        const status_str = parts.next() orelse return error.InvalidTODOFormat;
        var completed: bool = false;
        var canceled: bool = false;
        if (std.mem.eql(u8, status_str, "c")) {
            completed = true;
        } else if (std.mem.eql(u8, status_str, "x")) {
            canceled = true;
        } else if (std.mem.eql(u8, status_str, "o")) {
            // pending
        } else {
            return error.InvalidTODOFormat;
        }
        const deadline_str = parts.next() orelse return error.InvalidTODOFormat;
        var deadline: ?HUID = null;
        if (!std.mem.eql(u8, deadline_str, "")) {
            deadline = try HUID.initstr(deadline_str, allocator);
        }
        const description = parts.next() orelse return error.InvalidTODOFormat;
        var tag_list = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        while (true) {
            const tag = parts.next() orelse break;
            const dup_tag = try allocator.dupe(u8, tag);
            try tag_list.append(allocator, dup_tag);
        }
        const all_tags = try tag_list.toOwnedSlice(allocator);
        return TODO{
            .completed = completed,
            .canceled = canceled,
            .description = try allocator.dupe(u8, description),
            .tags = all_tags,
            .allocator = allocator,
            .huid = huid,
            .deadline = deadline,
        };
    }
    /// Serialize the "todo" item into a CSV row.
    /// Reverse of fromRow().
    ///
    /// You do need to call allocator.free() on the returned slice after use,
    /// and you also need to deinitialize the "todo" item separately.
    pub fn serialize(self: TODO) ![]const u8 {
        var allocating = std.io.Writer.Allocating.init(self.allocator);
        var writer = &allocating.writer;
        try writer.print("{s},", .{self.huid.id_str});
        if (self.completed) {
            try writer.print("c,", .{});
        } else if (self.canceled) {
            try writer.print("x,", .{});
        } else {
            try writer.print("o,", .{});
        }
        if (self.deadline) |dl| {
            try writer.print("{s},", .{dl.id_str});
        } else {
            try writer.print(",", .{});
        }
        try writer.print("{s}", .{self.description});
        for (self.tags) |tag| {
            try writer.print(",{s}", .{tag});
        }
        const result = try allocating.toOwnedSlice();
        return result;
    }
    /// Deinitialize the "todo" item, freeing allocated memory.
    pub fn deinit(self: TODO) void {
        for (self.tags) |tag| self.allocator.free(tag);
        self.allocator.free(self.tags);
        self.huid.deinit();
        if (self.deadline) |dl| {
            dl.deinit();
        }
        self.allocator.free(self.description);
    }
};

test "TODO init and deinit" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initid(1625072400, allocator);
    const tags = [_][]const u8{ "work", "urgent" };
    const todo = try TODO.init("Finish the report", &tags, huid);
    defer todo.deinit();
    try std.testing.expect(!todo.completed);
    try std.testing.expectEqualStrings("Finish the report", todo.description);
    try std.testing.expectEqualStrings("work", todo.tags[0]);
    try std.testing.expectEqualStrings("urgent", todo.tags[1]);
}

test "TODO fromRow and serialize" {
    const allocator = std.testing.allocator;
    const row = "20210630-170000,o,20210701-120000,Finish the report,work,urgent";
    const todo = try TODO.fromRow(row, allocator);
    defer todo.deinit();
    try std.testing.expect(!todo.completed);
    try std.testing.expectEqualStrings("Finish the report", todo.description);
    try std.testing.expectEqualStrings("work", todo.tags[0]);
    try std.testing.expectEqualStrings("urgent", todo.tags[1]);
    try std.testing.expectEqual(1625072400, todo.huid.unix_time);
    const deadline = todo.deadline orelse return error.InvalidTODOFormat;
    try std.testing.expectEqual(1625140800, deadline.unix_time);
    const serialized = try todo.serialize();
    defer allocator.free(serialized);
    std.debug.print("Serialized: {s}\n", .{serialized});
    try std.testing.expectEqualStrings(row, serialized);
}

test "TODO fromRow and serialize no deadline" {
    const allocator = std.testing.allocator;
    const row = "20210630-170000,c,,Finish the report,work,urgent";
    const todo = try TODO.fromRow(row, allocator);
    defer todo.deinit();
    try std.testing.expect(todo.completed);
    try std.testing.expectEqualStrings("Finish the report", todo.description);
    try std.testing.expectEqualStrings("work", todo.tags[0]);
    try std.testing.expectEqualStrings("urgent", todo.tags[1]);
    try std.testing.expectEqual(1625072400, todo.huid.unix_time);
    try std.testing.expect(todo.deadline == null);
    const serialized = try todo.serialize();
    defer allocator.free(serialized);
    std.debug.print("Serialized: {s}\n", .{serialized});
    try std.testing.expectEqualStrings(row, serialized);
}

/// HUIDs: Human Readable Unique Identifiers
/// See: https://www.youtube.com/watch?v=QH6KOEVnSZA
///
/// The unix time is the time in seconds, and the id string is the string representation of the huid.
pub const HUID = struct {
    id_str: []const u8,
    unix_time: i64,
    allocator: std.mem.Allocator,
    /// Initialize a new HUID from the given unix time.
    ///
    /// Note: to obtain the unix time, use std.time.milliTimestamp() / 1000
    ///
    /// Must be deinitialized with deinit() to free the allocated string or altered with add()/sub()
    pub fn initid(
        unix_time: i64,
        alloc: std.mem.Allocator,
    ) !HUID {
        const unsigned_time = @as(u64, @intCast(unix_time));
        const ts = std.time.epoch.EpochSeconds{ .secs = unsigned_time };
        const ds = ts.getDaySeconds();
        const yd = ts.getEpochDay().calculateYearDay();
        const md = yd.calculateMonthDay();
        const year = yd.year;
        const month = md.month;
        const day = md.day_index + 1;
        const hour = ds.getHoursIntoDay();
        const minute = ds.getMinutesIntoHour();
        const second = ds.getSecondsIntoMinute();
        const str = try std.fmt.allocPrint(
            alloc,
            "{d:0>4}{d:0>2}{d:0>2}-{d:0>2}{d:0>2}{d:0>2}",
            .{ year, month, day, hour, minute, second },
        );
        return HUID{
            .id_str = str,
            .unix_time = unix_time,
            .allocator = alloc,
        };
    }
    /// From the string representation of the HUID, get the ID string
    ///
    /// The string is copied into allocated memory.
    ///
    /// Must be deinitialized with deinit() to free the allocated string or altered with add()/sub()
    pub fn initstr(
        id_str: []const u8,
        alloc: std.mem.Allocator,
    ) !HUID {
        // Parse into unix time
        const unix_time = try parse(id_str);
        // Copy the string
        const str = try alloc.dupe(u8, id_str);
        return HUID{
            .id_str = str,
            .unix_time = unix_time,
            .allocator = alloc,
        };
    }
    /// Free the allocated ID string.
    pub fn deinit(self: HUID) void {
        self.allocator.free(self.id_str);
    }
    /// Parse a HUID from a string representation.
    /// Returns an error if the string is invalid.
    pub fn parse(id_str: []const u8) !i64 {
        // Expect length
        if (id_str.len != 15) {
            return error.InvalidHUIDString;
        }
        // Expect numbers and - and then numbers
        if (!isnumber(id_str[1]) or
            !isnumber(id_str[2]) or
            !isnumber(id_str[3]) or
            !isnumber(id_str[4]) or
            !isnumber(id_str[5]) or
            !isnumber(id_str[6]) or
            !isnumber(id_str[7]) or
            id_str[8] != '-' or
            !isnumber(id_str[9]) or
            !isnumber(id_str[10]) or
            !isnumber(id_str[11]) or
            !isnumber(id_str[12]) or
            !isnumber(id_str[13]) or
            !isnumber(id_str[14]))
        {
            return error.InvalidHUIDString;
        }
        const year = std.fmt.parseInt(u16, id_str[0..4], 10) catch {
            return error.InvalidHUIDString;
        };
        const month = std.fmt.parseInt(u16, id_str[4..6], 10) catch {
            return error.InvalidHUIDString;
        };
        const day = std.fmt.parseInt(u16, id_str[6..8], 10) catch {
            return error.InvalidHUIDString;
        };
        const hour = std.fmt.parseInt(u16, id_str[9..11], 10) catch {
            return error.InvalidHUIDString;
        };
        const minute = std.fmt.parseInt(u16, id_str[11..13], 10) catch {
            return error.InvalidHUIDString;
        };
        const second = std.fmt.parseInt(u16, id_str[13..15], 10) catch {
            return error.InvalidHUIDString;
        };
        const time_month = switch (month) {
            1 => std.time.epoch.Month.jan,
            2 => std.time.epoch.Month.feb,
            3 => std.time.epoch.Month.mar,
            4 => std.time.epoch.Month.apr,
            5 => std.time.epoch.Month.may,
            6 => std.time.epoch.Month.jun,
            7 => std.time.epoch.Month.jul,
            8 => std.time.epoch.Month.aug,
            9 => std.time.epoch.Month.sep,
            10 => std.time.epoch.Month.oct,
            11 => std.time.epoch.Month.nov,
            12 => std.time.epoch.Month.dec,
            else => return error.InvalidHUIDString,
        };
        const time_year = @as(std.time.epoch.Year, year);
        const days_in_month = std.time.epoch.getDaysInMonth(time_year, time_month);
        if (day < 1 or day > days_in_month) {
            return error.InvalidHUIDString;
        }
        const day_index = day - 1;
        var days_in_year: u16 = 0;
        for (std.enums.values(std.time.epoch.Month)) |m| {
            if (m == time_month) break;
            days_in_year += std.time.epoch.getDaysInMonth(time_year, m);
        }
        days_in_year += day_index;
        var days_since_epoch: i64 = 0;
        // If negative
        const epo: u16 = 1970;
        if (year < 1970) {
            for (time_year..epo) |y| {
                days_since_epoch -= std.time.epoch.getDaysInYear(@as(std.time.epoch.Year, @truncate(y)));
            }
        } else {
            for (epo..time_year) |y| {
                days_since_epoch += std.time.epoch.getDaysInYear(@as(std.time.epoch.Year, @truncate(y)));
            }
        }
        days_since_epoch += days_in_year;
        const seconds_in_years = @as(i64, days_since_epoch) * 86400;
        // Check hour, minute, second ranges
        if (hour >= 24 or minute >= 60 or second >= 60) {
            return error.InvalidHUIDString;
        }
        const seconds_in_day = @as(u32, hour) * 3600 + @as(u32, minute) * 60 + @as(u32, second);
        const unix_time = @as(i64, seconds_in_years + @as(i64, seconds_in_day));
        return unix_time;
    }
    fn isnumber(char: u8) bool {
        return char >= '0' and char <= '9';
    }
    pub fn compare(self: HUID, other: HUID) i2 {
        // Directly compare ints
        if (self.unix_time < other.unix_time) {
            return -1;
        } else if (self.unix_time > other.unix_time) {
            return 1;
        } else {
            return 0;
        }
    }
    /// INCLUSIVE on both ends
    pub fn inrange(self: HUID, start: HUID, end: HUID) bool {
        return self.unix_time >= start.unix_time and self.unix_time <= end.unix_time;
    }
    // Not an iterator, not named "next"
    pub fn inc(self: HUID) !HUID {
        // TODO: This is a bit dumb
        return HUID.initid(self.unix_time + 1, self.allocator);
    }
    /// Add seconds to the HUID, returning a new HUID. The old HUID is deinitialized.
    pub fn add(self: HUID, seconds: i64) !HUID {
        defer self.deinit();
        return HUID.initid(self.unix_time + seconds, self.allocator);
    }
    /// Subtract seconds from the HUID, returning a new HUID. The old HUID is deinitialized.
    pub fn sub(self: HUID, seconds: i64) !HUID {
        defer self.deinit();
        return HUID.initid(self.unix_time - seconds, self.allocator);
    }
    /// Get the millisecond timestamp of the HUID.
    ///
    /// To get the second time, use the unix_time field directly.
    pub fn asMilliTimestamp(self: HUID) i64 {
        return self.unix_time * 1000;
    }
    /// Detect all HUIDs in the given haystack of byte slices.
    ///
    /// Need to free the array and all the HUIDs in it after use.
    pub fn detect(haystack: []const []const u8, allocator: std.mem.Allocator) ![]HUID {
        var arrlst = try std.ArrayList(HUID).initCapacity(allocator, 24);
        for (haystack) |item| {
            // Search each position for a valid HUID
            const len = item.len;
            var i: usize = 0;
            while (i + 15 <= len) : (i += 1) {
                const potential_huid = item[i .. i + 15];
                _ = HUID.parse(potential_huid) catch {
                    // Not a valid huid, continue
                    continue;
                };
                const huid = try HUID.initstr(potential_huid, allocator);
                try arrlst.append(allocator, huid);
                i += 15; // Move past this huid
            }
        }
        return arrlst.toOwnedSlice(allocator);
    }
};

test "Test huid" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initid(1625072400, allocator);
    defer huid.deinit();
    try std.testing.expectEqualStrings("20210630-170000", huid.id_str);
    const parsed_huid = try HUID.initstr(huid.id_str, allocator);
    defer parsed_huid.deinit();
    try std.testing.expectEqual(huid.unix_time, parsed_huid.unix_time);
}

test "Test huid now" {
    const allocator = std.testing.allocator;
    const now = @divFloor(std.time.milliTimestamp(), 1000);
    const huid = try HUID.initid(now, allocator);
    defer huid.deinit();
    const parsed_huid = try HUID.initstr(huid.id_str, allocator);
    defer parsed_huid.deinit();
    try std.testing.expectEqual(huid.unix_time, parsed_huid.unix_time);
}

test "Test invalid huid" {
    const allocator = std.testing.allocator;
    const invalid_ids = [_][]const u8{
        "20210630-17000", // too short
        "20210630-1700000", // too long
        "20211330-170000", // invalid month
        "20210631-170000", // invalid day
        "20210630-240000", // invalid hour
        "20210630-176000", // invalid minute
        "20210630-170060", // invalid second
        "2021A630-170000", // invalid character
        "20210630_170000", // invalid separator
        "2021-0630170000", // wrong format
    };
    for (invalid_ids) |id_str| {
        const result = HUID.initstr(id_str, allocator);
        try std.testing.expect(result == error.InvalidHUIDString);
    }
}

test "HUID Compare" {
    const allocator = std.testing.allocator;
    const huid1 = try HUID.initid(1625072400, allocator);
    defer huid1.deinit();
    const huid2 = try HUID.initid(1625076000, allocator);
    defer huid2.deinit();
    const huid3 = try HUID.initid(1625072400, allocator);
    defer huid3.deinit();
    try std.testing.expect(huid1.compare(huid2) == -1);
    try std.testing.expect(huid2.compare(huid1) == 1);
    try std.testing.expect(huid1.compare(huid3) == 0);
}

test "HUID InRange" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initid(1625072400, allocator);
    defer huid.deinit();
    const start = try HUID.initid(1625068800, allocator);
    defer start.deinit();
    const end = try HUID.initid(1625076000, allocator);
    defer end.deinit();
    try std.testing.expect(huid.inrange(start, end));
    const before = try HUID.initid(1625065200, allocator);
    defer before.deinit();
    try std.testing.expect(!before.inrange(start, end));
    const after = try HUID.initid(1625079600, allocator);
    defer after.deinit();
    try std.testing.expect(!after.inrange(start, end));
}
test "HUID Inc" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initid(1625072400, allocator);
    defer huid.deinit();
    const next_huid = try huid.inc();
    defer next_huid.deinit();
    try std.testing.expectEqual(huid.unix_time + 1, next_huid.unix_time);
}
test "HUID Add/Sub" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initid(1625072400, allocator);
    const added_huid = try huid.add(3600);
    try std.testing.expectEqual(huid.unix_time + 3600, added_huid.unix_time);
    const subbed_huid = try added_huid.sub(3600);
    defer subbed_huid.deinit();
    try std.testing.expectEqual(huid.unix_time, subbed_huid.unix_time);
}
test "HUID asMilliTimestamp" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initid(1625072400, allocator);
    defer huid.deinit();
    try std.testing.expectEqual(1625072400000, huid.asMilliTimestamp());
}
test "HUID Detect" {
    const allocator = std.testing.allocator;
    const haystack = [_][]const u8{
        "No HUID here",
        "Here is one: 20210630-170000 in the text",
        "Multiple HUIDs: 20210701-120000 and 20210702-130000 end",
    };
    const huids = try HUID.detect(&haystack, allocator);
    defer allocator.free(huids);
    defer for (huids) |huid| huid.deinit();
    try std.testing.expectEqual(3, huids.len);
    try std.testing.expectEqual(1625072400, huids[0].unix_time);
    try std.testing.expectEqual(1625140800, huids[1].unix_time);
    try std.testing.expectEqual(1625230800, huids[2].unix_time);
}
test "HUID Detect No HUIDs" {
    const allocator = std.testing.allocator;
    const haystack = [_][]const u8{
        "No HUID here",
        "Still no HUID",
    };
    const huids = try HUID.detect(&haystack, allocator);
    defer allocator.free(huids);
    try std.testing.expectEqual(0, huids.len);
}

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
    try bufferedPrintln("Todo list initialized.");
    return;
}

pub fn initHelp() !void {
    const init_help_msg =
        "Usage: todo init\n\nInitializes a new todo list in the current directory by creating a .todo directory with necessary files.\nIf the .todo directory already exists, it will not overwrite existing files.\nExample:\n    $ todo init\n    Todo list initialized.\n";
    try bufferedPrintln(init_help_msg);
}

// TODO:
// todo add
// todo cancel
// todo list
// todo finish
// todo remind
// todo remove
// todo grep
// todo edit
// todo defer

pub fn help() !void {
    const help_msg =
        \\Usage: todo <command> [<args>]
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
        \\    remind    Remind about todo items due within a time range
        \\    remove    Remove a todo item
        \\    version   Show version information
        \\Common Options:
        \\    -h, --help       Show this help message and exit
        \\    -v, --version    Show version information and exit
        \\    -m, --message    Specify the description for the todo item (used with 'add' and 'edit' commands)
        \\    -t, --tags       Comma-separated list of tags for the todo item
        \\    -i, --id         Specify the HUID of the todo item to operate on
        \\For detailed help on a specific command, run: todo <command> --help
    ;
    try bufferedPrintln(help_msg);
}

pub fn version() !void {
    try bufferedPrintln("todo (wannasleep) version " ++ build_version ++ " (Zig " ++ builtin.zig_version_string ++ ")");
}

pub fn versionHelp() !void {
    const version_help_msg =
        "todo (wannasleep) version " ++ build_version ++ "\nA simple command-line todo list manager written in Zig.\nBuild Information:\n    Build Version: " ++ build_version ++ build_version_detail ++ "\n    Zig Version: " ++ builtin.zig_version_string ++ "\nAuthor: William Wu";
    try bufferedPrintln(version_help_msg);
}

pub fn author() !void {
    try bufferedPrintln("Created by William Wu");
}

pub fn unknownCommand(cmd: []const u8) !void {
    try bufferedPrintf("'{s}' is not a recognized command. See 'todo --help' for a list of available commands.\n", .{cmd});
}

pub fn huidRun(allocator: std.mem.Allocator) !void {
    const huidid = try HUID.initid(@divFloor(std.time.milliTimestamp(), 1000), allocator);
    defer huidid.deinit();
    try bufferedPrintf("{s}\n", .{huidid.id_str});
}

pub fn huidHelp() !void {
    const huid_help_msg =
        "Usage: todo huid\n\nGenerates a new Human Readable Unique Identifier (HUID) based on the current time.\nThe HUID format is YYYYMMDD-HHMMSS, representing the year, month, day, hour, minute, and second of creation.\nTo avoid conflicts, you should not generated HUIDs very often.\nExample:\n    $ todo huid\n    20231220-153045\n";
    try bufferedPrintln(huid_help_msg);
}

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
