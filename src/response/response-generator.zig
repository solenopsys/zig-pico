const std = @import("std");
const formatHttpDate = @import("./date.zig").formatHttpDate;
const MAX_DATE_LEN = @import("./date.zig").MAX_DATE_LEN;

pub const HttpResponse = struct {
    status_code: u16,
    status_text: []const u8,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator, status_code: u16, status_text: []const u8) !HttpResponse {
        return HttpResponse{
            .status_code = status_code,
            .status_text = status_text,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = null,
        };
    }

    pub fn addHeader(self: *HttpResponse, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }

    pub fn setBody(self: *HttpResponse, body: []const u8) void {
        self.body = body;
    }

    pub fn deinit(self: *HttpResponse) void {
        self.headers.deinit();
    }

    pub fn format(self: *const HttpResponse, allocator: std.mem.Allocator) ![]const u8 {
        var response = std.ArrayList(u8).init(allocator);
        defer response.deinit();

        try std.fmt.format(response.writer(), "HTTP/1.1 {d} {s}\r\n", .{ self.status_code, self.status_text });

        if (self.body) |body| {
            try std.fmt.format(response.writer(), "Content-Length: {d}\r\n", .{body.len});
        } else {
            try response.appendSlice("Content-Length: 0\r\n");
        }

        var header_it = self.headers.iterator();
        while (header_it.next()) |entry| {
            try std.fmt.format(response.writer(), "{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        try response.appendSlice("\r\n");

        if (self.body) |body| {
            try response.appendSlice(body);
        }

        return response.toOwnedSlice();
    }
};

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

    try response.addHeader("Content-Type", content_type);
    try response.addHeader("Server", "Zig HTTP Server");

    var buffer: [MAX_DATE_LEN]u8 = undefined;
    try response.addHeader("Date", formatHttpDate(std.time.milliTimestamp(), &buffer) catch unreachable);

    response.setBody(body);

    return response.format(allocator);
}

fn getHttpDate(allocator: std.mem.Allocator) ![]const u8 {
    var buf: [64]u8 = undefined;
    const posix_ts = std.time.milliTimestamp() / 1000;
    const formatted = try std.time.formatTimestampGmt(buf[0..], posix_ts, .rfc_2822);

    return try allocator.dupe(u8, formatted);
}
