const std = @import("std");
const formatHttpDate = @import("./date.zig").formatHttpDate;
const MAX_DATE_LEN = @import("./date.zig").MAX_DATE_LEN;

/// Структура для представления HTTP-ответа
pub const HttpResponse = struct {
    status_code: u16,
    status_text: []const u8,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8,

    /// Инициализирует новый HTTP-ответ
    pub fn init(allocator: std.mem.Allocator, status_code: u16, status_text: []const u8) !HttpResponse {
        return HttpResponse{
            .status_code = status_code,
            .status_text = status_text,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = null,
        };
    }

    /// Добавляет заголовок к HTTP-ответу
    pub fn addHeader(self: *HttpResponse, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }

    /// Устанавливает тело HTTP-ответа
    pub fn setBody(self: *HttpResponse, body: []const u8) void {
        self.body = body;
    }

    /// Освобождает ресурсы, занятые HTTP-ответом
    pub fn deinit(self: *HttpResponse) void {
        self.headers.deinit();
    }

    /// Форматирует HTTP-ответ в виде строки
    pub fn format(self: *const HttpResponse, allocator: std.mem.Allocator) ![]const u8 {
        var response = std.ArrayList(u8).init(allocator);
        defer response.deinit();

        // Добавляем строку статуса
        try std.fmt.format(response.writer(), "HTTP/1.1 {d} {s}\r\n", .{ self.status_code, self.status_text });

        // Автоматически добавляем Content-Length, если есть тело
        if (self.body) |body| {
            try std.fmt.format(response.writer(), "Content-Length: {d}\r\n", .{body.len});
        } else {
            try response.appendSlice("Content-Length: 0\r\n");
        }

        // Добавляем заголовки
        var header_it = self.headers.iterator();
        while (header_it.next()) |entry| {
            try std.fmt.format(response.writer(), "{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        // Пустая строка отделяет заголовки от тела
        try response.appendSlice("\r\n");

        // Добавляем тело, если оно есть
        if (self.body) |body| {
            try response.appendSlice(body);
        }

        return response.toOwnedSlice();
    }
};

/// Создаёт HTTP-ответ с указанным статус-кодом и телом
pub fn generateHttpResponse(
    allocator: std.mem.Allocator,
    status_code: u16,
    content_type: []const u8,
    body: []const u8,
) ![]const u8 {
    var response = try HttpResponse.init(
        allocator,
        status_code,
        switch (status_code) {
            200 => "OK",
            201 => "Created",
            204 => "No Content",
            400 => "Bad Request",
            401 => "Unauthorized",
            403 => "Forbidden",
            404 => "Not Found",
            500 => "Internal Server Error",
            else => "Unknown",
        },
    );
    defer response.deinit();

    // Добавляем стандартные заголовки
    try response.addHeader("Content-Type", content_type);
    try response.addHeader("Server", "Zig HTTP Server");

    var buffer: [MAX_DATE_LEN]u8 = undefined;
    try response.addHeader("Date", formatHttpDate(std.time.milliTimestamp(), &buffer) catch unreachable);

    // Устанавливаем тело ответа
    response.setBody(body);

    // Форматируем и возвращаем весь ответ
    return response.format(allocator);
}

fn getHttpDate(allocator: std.mem.Allocator) ![]const u8 {

    // Форматируем время с помощью встроенной функции
    // Используем формат "Thu, 01 Dec 2022 16:00:00 GMT"
    var buf: [64]u8 = undefined;
    const posix_ts = std.time.milliTimestamp() / 1000;
    const formatted = try std.time.formatTimestampGmt(buf[0..], posix_ts, .rfc_2822);

    return try allocator.dupe(u8, formatted);
}
