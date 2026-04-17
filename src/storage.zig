const std = @import("std");
const HUID = @import("huid.zig").HUID;
const TODO = @import("todo.zig").TODO;

pub fn readEntireCSVAsTODOs(
    allocator: std.mem.Allocator,
    path: ?[]const u8,
) !std.ArrayList(TODO) {
    const actual_path = if (path) |p| p else "main.csv";
    const cwd = std.fs.cwd();
    var todo_dir = try cwd.openDir(".todo", .{});
    defer todo_dir.close();
    var data_dir = try todo_dir.openDir("data", .{});
    defer data_dir.close();
    var main_todo_file = try data_dir.openFile(actual_path, .{});
    defer main_todo_file.close();
    const big_string = try main_todo_file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(big_string);
    var lines = std.mem.splitAny(u8, big_string, "\n");
    var todo_list = try std.ArrayList(TODO).initCapacity(allocator, 12);
    while (true) {
        const line = lines.next() orelse break;
        if (line.len == 0) continue; // Skip empty lines
        const todo = try TODO.fromRow(line, allocator);
        try todo_list.append(allocator, todo);
    }
    return todo_list;
}

pub fn readTODOWithHUID(
    allocator: std.mem.Allocator,
    path: ?[]const u8,
    huid: HUID,
) !?TODO {
    var todo_list = try readEntireCSVAsTODOs(allocator, path);
    defer todo_list.deinit(allocator);
    var result: ?TODO = null;
    for (todo_list.items) |todo| {
        if (todo.huid.compare(huid) == 0 and result == null) {
            result = todo;
        } else {
            todo.deinit();
        }
    }
    return result;
}

pub fn appendTODOToCSV(
    allocator: std.mem.Allocator,
    path: ?[]const u8,
    todo: TODO,
) !void {
    const actual_path = if (path) |p| p else "main.csv";
    const cwd = std.fs.cwd();
    var todo_dir = try cwd.openDir(".todo", .{});
    defer todo_dir.close();
    var data_dir = try todo_dir.openDir("data", .{});
    defer data_dir.close();
    var main_todo_file = try data_dir.createFile(actual_path, .{ .truncate = false, .read = false });
    defer main_todo_file.close();
    const serialized = try todo.serialize();
    defer allocator.free(serialized);
    const stat = try main_todo_file.stat();
    try main_todo_file.seekTo(stat.size);
    try main_todo_file.writeAll("\n");
    try main_todo_file.writeAll(serialized);
}

test "ReadEntireCSVAsTODOs" {
    const allocator = std.testing.allocator;
    // Prepare a sample CSV file
    const sample_csv = "20210630-170000,o,,\"Finish the report, and do thing\",work,urgent\n20210701-120000,c,20210702-130000,\"Submit the assignment\",school\n";
    const cwd = std.fs.cwd();
    var todo_dir = try cwd.openDir(".todo", .{});
    defer todo_dir.close();
    var data_dir = try todo_dir.openDir("data", .{});
    defer data_dir.close();
    var sample_file = try data_dir.createFile("sample.csv", .{ .truncate = true, .read = true });
    defer sample_file.close();
    try sample_file.writeAll(sample_csv);
    // Read the CSV file
    var todo_list = try readEntireCSVAsTODOs(allocator, "sample.csv");
    defer todo_list.deinit(allocator);
    defer for (todo_list.items) |todo| todo.deinit();
    try std.testing.expectEqualStrings("Finish the report, and do thing", todo_list.items[0].description);
    try std.testing.expectEqualStrings("Submit the assignment", todo_list.items[1].description);
}

test "ReadTODOWithHUID" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initstr("20210630-170000", allocator);
    defer huid.deinit();
    const todo_opt = try readTODOWithHUID(allocator, "sample.csv", huid);
    const todo = todo_opt orelse return error.TODOItemNotFound;
    defer todo.deinit();
    try std.testing.expectEqualStrings("Finish the report, and do thing", todo.description);
}

test "AppendTODOToCSV" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initstr("20210703-140000", allocator);
    const tags = [_][]const u8{"personal"};
    const todo = try TODO.init("Buy groceries", &tags, huid, null);
    defer todo.deinit();
    try appendTODOToCSV(allocator, "sample.csv", todo);
    // Verify by reading back
    const read_todo_opt = try readTODOWithHUID(allocator, "sample.csv", huid);
    const read_todo = read_todo_opt orelse return error.TODOItemNotFound;
    defer read_todo.deinit();
    try std.testing.expectEqualStrings("Buy groceries", read_todo.description);
}

test "AppendTODOWithSpaceToCSV" {
    const allocator = std.testing.allocator;
    const huid = try HUID.initstr("20210812-140000", allocator);
    const deadline = try HUID.initstr("20200815-120000", allocator);
    const tags = [_][]const u8{"personal"};
    const todo_string = "Buy groceries\nThe list of things to buy are:\n1. Bananas\n2. Chicken Wings\n3. Orange Juice";
    const todo = try TODO.init(todo_string, &tags, huid, deadline);
    defer todo.deinit();
    try appendTODOToCSV(allocator, "sample.csv", todo);
    // Verify by reading back
    const read_todo_opt = try readTODOWithHUID(allocator, "sample.csv", huid);
    const read_todo = read_todo_opt orelse return error.TODOItemNotFound;
    defer read_todo.deinit();
    try std.testing.expectEqualStrings(todo_string, read_todo.description);
}
