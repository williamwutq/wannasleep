const std = @import("std");

// TODO:
// todo add
// todo list
// todo finish
// todo remind
// todo remove
// todo grep
// todo edit
// todo defer

/// HUIDs
/// See: https://www.youtube.com/watch?v=QH6KOEVnSZA
pub const HUID = struct {
    id_str: []const u8,
    unix_time: i64,
    allocator: std.mem.Allocator,
    /// Initialize a new HUID from the given unix time.
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
    fn parse(id_str: []const u8) !i64 {
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
