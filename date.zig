const std = @import("std");
const testing = std.testing;
pub const MAX_DATE_LEN = 40;

const month_names = [_][]const u8{ "", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

pub fn write(writer: anytype, ts: i64) !void {
    const date = getDate(ts);
    const time = getTime(ts);

    var buf: [26]u8 = undefined;
    const formatted = try std.fmt.bufPrint(&buf, "{d:02} {s} {d} {d:02}:{d:02}:{d:02} +0000", .{ date.day, month_names[date.month], date.year, time.hour, time.min, time.sec });
    return writer.writeAll(formatted);
}

pub fn formatHttpDate(timestamp: i64, buffer: *[MAX_DATE_LEN]u8) ![]const u8 {
    // Преобразуем timestamp из миллисекунд в секунды
    const ts_seconds = @divTrunc(timestamp, 1000);

    // Получаем день недели
    const weekday_names = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };

    // 1970-01-01 был четвергом (4)
    // Дни с начала эпохи
    const days_since_epoch = @divTrunc(ts_seconds, 86400);
    // Остаток от деления на 7 дает нам день недели
    const weekday_idx = @mod(@as(u3, @intCast(@mod(days_since_epoch + 4, 7))), 7);

    // Получаем структуры даты и времени
    const date = getDate(ts_seconds);
    const time = getTime(ts_seconds);

    // Форматируем HTTP дату напрямую в буфер
    return std.fmt.bufPrint(buffer, "{s}, {d:0>2} {s} {d} {d:0>2}:{d:0>2}:{d:0>2} GMT", .{ weekday_names[weekday_idx], date.day, month_names[date.month], date.year, time.hour, time.min, time.sec });
}
const Date = struct {
    year: i16,
    month: u8,
    day: u8,
};

const Time = struct {
    hour: u8,
    min: u8,
    sec: u8,
};

fn getDate(ts: i64) Date {
    // 2000-03-01 (mod 400 year, immediately after feb29
    const leap_epoch = 946684800 + 86400 * (31 + 29);
    const days_per_400y = 365 * 400 + 97;
    const days_per_100y = 365 * 100 + 24;
    const days_per_4y = 365 * 4 + 1;

    // march-based
    const month_days = [_]u8{ 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 31, 29 };

    const secs = ts - leap_epoch;

    var days = @divTrunc(secs, 86400);
    if (@rem(secs, 86400) < 0) {
        days -= 1;
    }

    var qc_cycles = @divTrunc(days, days_per_400y);
    var rem_days = @rem(days, days_per_400y);
    if (rem_days < 0) {
        rem_days += days_per_400y;
        qc_cycles -= 1;
    }

    var c_cycles = @divTrunc(rem_days, days_per_100y);
    if (c_cycles == 4) {
        c_cycles -= 1;
    }
    rem_days -= c_cycles * days_per_100y;

    var q_cycles = @divTrunc(rem_days, days_per_4y);
    if (q_cycles == 25) {
        q_cycles -= 1;
    }
    rem_days -= q_cycles * days_per_4y;

    var rem_years = @divTrunc(rem_days, 365);
    if (rem_years == 4) {
        rem_years -= 1;
    }
    rem_days -= rem_years * 365;

    var year = rem_years + 4 * q_cycles + 100 * c_cycles + 400 * qc_cycles + 2000;

    var month: u8 = 0;
    while (month_days[month] <= rem_days) : (month += 1) {
        rem_days -= month_days[month];
    }

    month += 2;
    if (month >= 12) {
        year += 1;
        month -= 12;
    }

    return .{
        .year = @intCast(year),
        .month = month + 1,
        .day = @intCast(rem_days + 1),
    };
}

fn getTime(ts: i64) Time {
    const seconds = @mod(ts, 86400);
    return .{
        .hour = @intCast(@divTrunc(seconds, 3600)),
        .min = @intCast(@divTrunc(@rem(seconds, 3600), 60)),
        .sec = @intCast(@rem(seconds, 60)),
    };
}

test "HTTP date formatting - specific timestamps" {
    var buffer: [MAX_DATE_LEN]u8 = undefined;

    // Тестовые данные: timestamp -> ожидаемая строка
    const test_cases = [_]struct {
        timestamp: i64,
        expected: []const u8,
    }{
        .{ .timestamp = 0, .expected = "Thu, 01 Jan 1970 00:00:00 GMT" },
        .{ .timestamp = 1614556800000, .expected = "Mon, 01 Mar 2021 00:00:00 GMT" },
        .{ .timestamp = 1704067200000, .expected = "Mon, 01 Jan 2024 00:00:00 GMT" },
        .{ .timestamp = 2147483647000, .expected = "Tue, 19 Jan 2038 03:14:07 GMT" },
    };

    for (test_cases) |tc| {
        const formatted = try formatHttpDate(tc.timestamp, &buffer);
        try testing.expectEqualStrings(tc.expected, formatted);
    }
}

test "HTTP date formatting - format validation" {
    var buffer: [MAX_DATE_LEN]u8 = undefined;

    // Проверим текущее время
    const current_time = std.time.milliTimestamp();
    const formatted = try formatHttpDate(current_time, &buffer);

    // Проверяем структуру даты
    try testing.expect(formatted.len > 0);
    try testing.expect(formatted.len < MAX_DATE_LEN);

    // Проверяем наличие обязательных компонентов
    try testing.expect(std.mem.indexOf(u8, formatted, ", ") != null); // День недели
    try testing.expect(std.mem.indexOf(u8, formatted, " GMT") != null); // Часовой пояс

    // Проверяем формат времени (HH:MM:SS)
    const time_part = formatted[formatted.len - 12 .. formatted.len - 4];
    try testing.expect(time_part[2] == ':' and time_part[5] == ':'); // Разделители времени

    // Цифровые значения времени
    try testing.expect(std.ascii.isDigit(time_part[0]));
    try testing.expect(std.ascii.isDigit(time_part[1]));
    try testing.expect(std.ascii.isDigit(time_part[3]));
    try testing.expect(std.ascii.isDigit(time_part[4]));
    try testing.expect(std.ascii.isDigit(time_part[6]));
    try testing.expect(std.ascii.isDigit(time_part[7]));
}
