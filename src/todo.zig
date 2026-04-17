const std = @import("std");
const HUID = @import("huid.zig").HUID;

pub const TODOPrintOptions = struct {
    print_inactive: bool,
    show_status: bool,
    show_huid: bool,
    show_tags: bool,
    show_deadline: bool,
    show_description: bool,
};

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
        deadline: ?HUID,
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
            .deadline = deadline,
            .huid = huid,
        };
    }
    /// Initialize a "todo" item from a CSV row.
    pub fn fromRow(row: []const u8, allocator: std.mem.Allocator) !TODO {
        // Format: huid,[status],deadline,"description",tag1,tag2,...
        // Status is either "c" for completed, "x" for canceled, or "o" for pending
        var parts = std.mem.splitAny(u8, row, ",");
        const huid_str = parts.next() orelse return error.InvalidTODOFormat;
        const huid = try HUID.initstr(huid_str, allocator);
        const status_str = parts.next() orelse {
            huid.deinit();
            return error.InvalidTODOFormat;
        };
        var completed: bool = false;
        var canceled: bool = false;
        if (std.mem.eql(u8, status_str, "c")) {
            completed = true;
        } else if (std.mem.eql(u8, status_str, "x")) {
            canceled = true;
        } else if (std.mem.eql(u8, status_str, "o")) {
            // pending
        } else {
            huid.deinit();
            return error.InvalidTODOFormat;
        }
        const deadline_str = parts.next() orelse {
            huid.deinit();
            return error.InvalidTODOFormat;
        };
        var deadline: ?HUID = null;
        if (!std.mem.eql(u8, deadline_str, "")) {
            deadline = try HUID.initstr(deadline_str, allocator);
        }
        const rest = parts.rest();
        // This should be "description",tags... or description,tags...
        var description: []const u8 = undefined;
        var tags: []const u8 = undefined;
        var is_quoted = false;
        if (rest.len > 0 and rest[0] == '"') {
            // Quoted description
            is_quoted = true;
            var desc_end_index: usize = 0;
            var in_quotes: bool = false;
            var i: usize = 0;
            while (i < rest.len) : (i += 1) {
                const c = rest[i];
                if (c == '"') {
                    in_quotes = !in_quotes;
                    if (!in_quotes) {
                        desc_end_index = i;
                        break;
                    }
                }
            }
            if (in_quotes) {
                huid.deinit();
                return error.InvalidTODOFormat;
            }
            // rest[0] == '"', so description is rest[1..desc_end_index]
            const raw_desc = rest[1..desc_end_index];
            description = try unescapeFromCSV(allocator, raw_desc);
            // tags start after the closing quote and comma
            if (desc_end_index + 1 < rest.len and rest[desc_end_index + 1] == ',') {
                tags = rest[desc_end_index + 2 ..];
            } else if (desc_end_index + 1 == rest.len) {
                tags = "";
            } else {
                allocator.free(description);
                huid.deinit();
                if (deadline) |dl| dl.deinit();
                return error.InvalidTODOFormat;
            }
        } else {
            // Unquoted description: up to first comma
            var comma_index: ?usize = null;
            for (rest, 0..) |c, idx| {
                if (c == ',') {
                    comma_index = idx;
                    break;
                }
            }
            if (comma_index) |ci| {
                description = rest[0..ci];
                tags = rest[ci + 1 ..];
            } else {
                // No tags, only description
                description = rest;
                tags = "";
            }
        }
        var tags_iter = std.mem.splitAny(u8, tags, ",");
        var tag_list = try std.ArrayList([]const u8).initCapacity(allocator, 4);
        while (true) {
            const tag = tags_iter.next() orelse break;
            // If tag is empty, continue
            if (tag.len == 0) {
                continue;
            }
            const dup_tag = try allocator.dupe(u8, tag);
            try tag_list.append(allocator, dup_tag);
        }
        const all_tags = try tag_list.toOwnedSlice(allocator);
        const final_description = try allocator.dupe(u8, description);
        if (is_quoted) allocator.free(description);
        return TODO{
            .completed = completed,
            .canceled = canceled,
            .description = final_description,
            .tags = all_tags,
            .allocator = allocator,
            .huid = huid,
            .deadline = deadline,
        };
    }
    pub fn canceledTransferOwnerships(self: TODO) TODO {
        return TODO{
            .completed = self.completed,
            .canceled = true,
            .description = self.description,
            .tags = self.tags,
            .allocator = self.allocator,
            .huid = self.huid,
            .deadline = self.deadline,
        };
    }
    pub fn completeTransferOwnerships(self: TODO) TODO {
        return TODO{
            .completed = true,
            .canceled = self.canceled,
            .description = self.description,
            .tags = self.tags,
            .allocator = self.allocator,
            .huid = self.huid,
            .deadline = self.deadline,
        };
    }
    pub fn openTransferOwnerships(self: TODO) TODO {
        return TODO{
            .completed = false,
            .canceled = false,
            .description = self.description,
            .tags = self.tags,
            .allocator = self.allocator,
            .huid = self.huid,
            .deadline = self.deadline,
        };
    }
    pub fn changeDeadlineTransferOwnerships(self: TODO, new_deadline: ?HUID) TODO {
        if (self.deadline) |old_deadline| {
            old_deadline.deinit();
        }
        return TODO{
            .completed = self.completed,
            .canceled = self.canceled,
            .description = self.description,
            .tags = self.tags,
            .allocator = self.allocator,
            .huid = self.huid,
            .deadline = new_deadline,
        };
    }
    pub fn deferDeadlineTransferOwnerships(self: TODO, seconds: i64) !TODO {
        var new_deadline: ?HUID = null;
        if (self.deadline) |dl| {
            new_deadline = try dl.add(seconds);
        }
        return TODO{
            .completed = self.completed,
            .canceled = self.canceled,
            .description = self.description,
            .tags = self.tags,
            .allocator = self.allocator,
            .huid = self.huid,
            .deadline = new_deadline,
        };
    }
    pub fn changeDescriptionTransferOwnerships(self: TODO, new_description: []const u8) !TODO {
        const new_description_copy = try self.allocator.dupe(u8, new_description);
        self.allocator.free(self.description);
        return TODO{
            .completed = self.completed,
            .canceled = self.canceled,
            .description = new_description_copy,
            .tags = self.tags,
            .allocator = self.allocator,
            .huid = self.huid,
            .deadline = self.deadline,
        };
    }
    pub fn changeTagsTransferOwnerships(self: TODO, new_tags: []const []const u8) !TODO {
        var tag_list = try std.ArrayList([]const u8).initCapacity(self.allocator, new_tags.len);
        for (new_tags) |tag| {
            const dup_tag = try self.allocator.dupe(u8, tag);
            try tag_list.append(self.allocator, dup_tag);
        }
        const all_tags = try tag_list.toOwnedSlice(self.allocator);
        for (self.tags) |tag| self.allocator.free(tag);
        self.allocator.free(self.tags);
        return TODO{
            .completed = self.completed,
            .canceled = self.canceled,
            .description = self.description,
            .tags = all_tags,
            .allocator = self.allocator,
            .huid = self.huid,
            .deadline = self.deadline,
        };
    }
    pub fn addTagTransferOwnerships(self: TODO, new_tag: []const u8) !TODO {
        const dup_tag = try self.allocator.dupe(u8, new_tag);
        var tag_list = try std.ArrayList([]const u8).initCapacity(self.allocator, self.tags.len + 1);
        for (self.tags) |tag| {
            try tag_list.append(self.allocator, tag);
        }
        try tag_list.append(self.allocator, dup_tag);
        const all_tags = try tag_list.toOwnedSlice(self.allocator);
        self.allocator.free(self.tags);
        return TODO{
            .completed = self.completed,
            .canceled = self.canceled,
            .description = self.description,
            .tags = all_tags,
            .allocator = self.allocator,
            .huid = self.huid,
            .deadline = self.deadline,
        };
    }
    pub fn addTagsTransferOwnerships(self: TODO, new_tags: []const []const u8) !TODO {
        var tag_list = try std.ArrayList([]const u8).initCapacity(self.allocator, self.tags.len + new_tags.len);
        for (self.tags) |tag| {
            try tag_list.append(self.allocator, tag);
        }
        for (new_tags) |tag| {
            const dup_tag = try self.allocator.dupe(u8, tag);
            try tag_list.append(self.allocator, dup_tag);
        }
        const all_tags = try tag_list.toOwnedSlice(self.allocator);
        self.allocator.free(self.tags);
        return TODO{
            .completed = self.completed,
            .canceled = self.canceled,
            .description = self.description,
            .tags = all_tags,
            .allocator = self.allocator,
            .huid = self.huid,
            .deadline = self.deadline,
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
        const escaped_desc = try escapeForCSV(self.allocator, self.description);
        defer self.allocator.free(escaped_desc);
        try writer.print("\"{s}\"", .{escaped_desc});
        for (self.tags) |tag| {
            try writer.print(",{s}", .{tag});
        }
        const result = try allocating.toOwnedSlice();
        return result;
    }
    pub fn print(self: TODO, options: TODOPrintOptions) ![]const u8 {
        var allocating = std.io.Writer.Allocating.init(self.allocator);
        var writer = &allocating.writer;
        if (options.show_status) {
            if (self.completed) {
                if (options.print_inactive) {
                    try writer.print("[x] ", .{});
                } else {
                    allocating.deinit();
                    return self.allocator.dupe(u8, "");
                }
            } else if (self.canceled) {
                if (options.print_inactive) {
                    try writer.print("[-] ", .{});
                } else {
                    allocating.deinit();
                    return self.allocator.dupe(u8, "");
                }
            } else {
                try writer.print("[ ] ", .{});
            }
        }
        if (options.show_huid) {
            try writer.print("({s}) ", .{self.huid.id_str});
        }
        if (options.show_deadline) {
            if (self.deadline) |dl| {
                try writer.print("Deadline: {s} ", .{dl.id_str});
            }
        }
        if (options.show_description) {
            try writer.print("{s} ", .{self.description});
        }
        if (options.show_tags) {
            if (self.tags.len > 0) {
                try writer.print("[", .{});
                var isFirst: bool = true;
                for (self.tags) |tag| {
                    if (!isFirst) {
                        try writer.print(", ", .{});
                    } else {
                        isFirst = false;
                    }
                    try writer.print("{s}", .{tag});
                }
                try writer.print("] ", .{});
            }
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
    pub fn matchesTag(self: TODO, tag: []const u8) bool {
        for (self.tags) |t| {
            if (std.mem.eql(u8, t, tag)) {
                return true;
            }
        }
        return false;
    }
    pub fn matchesTagInsensitive(self: TODO, tag: []const u8) bool {
        for (self.tags) |t| {
            if (std.ascii.eqlIgnoreCase(t, tag)) {
                return true;
            }
        }
        return false;
    }
    pub fn hasDeadline(self: TODO) bool {
        return self.deadline != null;
    }
    pub fn matchesDescription(self: TODO, substr: []const u8) bool {
        return std.mem.indexOf(u8, self.description, substr) != null;
    }
    pub fn matchesDescriptionInsensitive(self: TODO, substr: []const u8) bool {
        return std.ascii.indexOfIgnoreCase(self.description, substr) != null;
    }
};

fn escapeForCSV(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, str.len);
    defer result.deinit(allocator);
    for (str) |c| {
        switch (c) {
            '"' => try result.appendSlice(allocator, "\\\""),
            '\\' => try result.appendSlice(allocator, "\\\\"),
            '\n' => try result.appendSlice(allocator, "\\n"),
            '\r' => try result.appendSlice(allocator, "\\r"),
            '\t' => try result.appendSlice(allocator, "\\t"),
            else => try result.append(allocator, c),
        }
    }
    return try result.toOwnedSlice(allocator);
}

fn unescapeFromCSV(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, str.len);
    defer result.deinit(allocator);
    var i: usize = 0;
    while (i < str.len) {
        const c = str[i];
        if (c == '\\' and i + 1 < str.len) {
            const next = str[i + 1];
            switch (next) {
                '"' => try result.append(allocator, '"'),
                '\\' => try result.append(allocator, '\\'),
                'n' => try result.append(allocator, '\n'),
                'r' => try result.append(allocator, '\r'),
                't' => try result.append(allocator, '\t'),
                else => {
                    // Invalid escape, keep the backslash
                    try result.append(allocator, c);
                },
            }
            i += 2;
        } else {
            try result.append(allocator, c);
            i += 1;
        }
    }
    return try result.toOwnedSlice(allocator);
}

test "TODO init and deinit" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initid(1625072400, allocator);
    const tags = [_][]const u8{ "work", "urgent" };
    const todo = try TODO.init("Finish the report", &tags, huid, null);
    defer todo.deinit();
    try std.testing.expect(!todo.completed);
    try std.testing.expectEqualStrings("Finish the report", todo.description);
    try std.testing.expectEqualStrings("work", todo.tags[0]);
    try std.testing.expectEqualStrings("urgent", todo.tags[1]);
}

test "TODO print" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initid(1625072400, allocator);
    const tags = [_][]const u8{ "work", "urgent" };
    const todo = try TODO.init("Finish the report", &tags, huid, null);
    defer todo.deinit();
    const options = TODOPrintOptions{
        .print_inactive = false,
        .show_status = true,
        .show_huid = true,
        .show_tags = true,
        .show_deadline = false,
        .show_description = true,
    };
    const output = try todo.print(options);
    defer allocator.free(output);
    try std.testing.expectEqualStrings(
        "[ ] (20210630-170000) Finish the report [work, urgent] ",
        output,
    );
}

test "TODO fromRow and serialize" {
    const allocator = std.testing.allocator;
    const row = "20210630-170000,o,20210701-120000,\"Finish the report\",work,urgent";
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
    try std.testing.expectEqualStrings(row, serialized);
}

test "TODO fromRow and serialize no deadline" {
    const allocator = std.testing.allocator;
    const row = "20210630-170000,c,,\"Finish the report\",work,urgent";
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
    try std.testing.expectEqualStrings(row, serialized);
}

test "TODO fromRow unclosed quotes" {
    const allocator = std.testing.allocator;
    const row = "20210630-170000,o,,\"Finish the report,work,urgent";
    const result = TODO.fromRow(row, allocator);
    try std.testing.expect(result == error.InvalidTODOFormat);
}

test "TODO not quoted description" {
    const allocator = std.testing.allocator;
    const row = "20210630-170000,o,,Finish the report,work,urgent";
    const todo = try TODO.fromRow(row, allocator);
    defer todo.deinit();
    try std.testing.expect(!todo.completed);
    try std.testing.expectEqualStrings("Finish the report", todo.description);
    try std.testing.expectEqualStrings("work", todo.tags[0]);
    try std.testing.expectEqualStrings("urgent", todo.tags[1]);
}

test "TODO empty tags" {
    const allocator = std.testing.allocator;
    const row = "20210630-170000,o,,\"Finish the report\",";
    const todo = try TODO.fromRow(row, allocator);
    defer todo.deinit();
    try std.testing.expect(!todo.completed);
    try std.testing.expectEqualStrings("Finish the report", todo.description);
    try std.testing.expectEqual(todo.tags.len, 0);
}

test "TODO empty tags missing comma" {
    const allocator = std.testing.allocator;
    const row = "20210630-170000,o,,\"Finish the report\"";
    const todo = try TODO.fromRow(row, allocator);
    defer todo.deinit();
    try std.testing.expect(!todo.completed);
    try std.testing.expectEqualStrings("Finish the report", todo.description);
    try std.testing.expectEqual(0, todo.tags.len);
}

test "TODO quotes inside quotes" {
    const allocator = std.testing.allocator;
    const row = "20210630-170000,o,,\"Finish the \\\"report\\\"\",work";
    const result = TODO.fromRow(row, allocator);
    try std.testing.expect(result == error.InvalidTODOFormat);
}

test "TODO matches tags and description" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initid(1625072400, allocator);
    const tags = [_][]const u8{ "work", "urgent" };
    const todo = try TODO.init("Finish the report", &tags, huid, null);
    defer todo.deinit();
    try std.testing.expect(todo.matchesTag("work"));
    try std.testing.expect(!todo.matchesTag("personal"));
    try std.testing.expect(todo.matchesDescription("the rep"));
    try std.testing.expect(!todo.matchesDescription("not found"));
}

test "TODO matches tags and description insensitive" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initid(1625072400, allocator);
    const tags = [_][]const u8{ "Work", "Urgent" };
    const todo = try TODO.init("Finish the Report", &tags, huid, null);
    defer todo.deinit();
    try std.testing.expect(todo.matchesTagInsensitive("work"));
    try std.testing.expect(!todo.matchesTagInsensitive("personal"));
    try std.testing.expect(todo.matchesDescriptionInsensitive("the rep"));
    try std.testing.expect(!todo.matchesDescriptionInsensitive("not found"));
}
