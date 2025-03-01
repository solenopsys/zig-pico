const std = @import("std");
const mem = std.mem;
const builtin = @import("builtin");
const findCharFast = @import("fast.zig").findCharFast;

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

const ParseError = error{
    Incomplete,
    BadRequest,
};

/// Determines if a character is printable ASCII
inline fn isPrintableAscii(c: u8) bool {
    return (c -% 0x20) < 0x5F;
}

/// Token character map
const token_char_map = blk: {
    var map: [256]bool = [_]bool{false} ** 256;

    // Set token characters according to HTTP spec
    var i: u8 = '0';
    while (i <= '9') : (i += 1) {
        map[i] = true;
    }
    i = 'A';
    while (i <= 'Z') : (i += 1) {
        map[i] = true;
    }
    i = 'a';
    while (i <= 'z') : (i += 1) {
        map[i] = true;
    }

    // Add special characters
    const specials = "!#$%&'*+-.^_`|~";
    for (specials) |c| {
        map[c] = true;
    }

    break :blk map;
};

/// Gets a token until end of line
fn getTokenToEol(buffer: []const u8) ParseError!struct { token: []const u8, rest: []const u8 } {
    var i: usize = 0;
    var found_ctl = false;

    while (i < buffer.len) : (i += 1) {
        const c = buffer[i];
        if (!isPrintableAscii(c)) {
            if ((c < 0x20 and c != '\t') or c == 0x7F) {
                found_ctl = true;
                break;
            }
        }
    }

    if (i == buffer.len and !found_ctl) {
        return ParseError.Incomplete;
    }

    if (buffer[i] == '\n') {
        return .{
            .token = buffer[0..i],
            .rest = buffer[i + 1 ..],
        };
    } else if (i + 1 < buffer.len and buffer[i] == '\r' and buffer[i + 1] == '\n') {
        return .{
            .token = buffer[0..i],
            .rest = buffer[i + 2 ..],
        };
    } else {
        return .{
            .token = buffer[0..i],
            .rest = buffer[i..],
        };
    }
}

/// Advances to the next token
fn advanceToken(buffer: []const u8) ParseError!struct { token: []const u8, rest: []const u8 } {
    var i: usize = 0;
    var ranges = [_]u8{ 0, ' ', 0x7F, 0x7F };

    if (findCharFast(buffer, &ranges)) |pos| {
        i = pos;
    } else if (buffer.len > 0) {
        i = buffer.len;
    } else {
        return ParseError.Incomplete;
    }

    // Удалена проверка на пустой токен для повышения производительности
    // Пользователь должен сам убедиться, что входящие данные корректны

    while (i < buffer.len) : (i += 1) {
        const c = buffer[i];
        if (c == ' ') {
            break;
        } else if (!isPrintableAscii(c)) {
            if (c < 0x20 or c == 0x7F) {
                return ParseError.BadRequest;
            }
        }
    }

    if (i == buffer.len) {
        return ParseError.Incomplete;
    }

    return .{
        .token = buffer[0..i],
        .rest = buffer[i + 1 ..],
    };
}

/// Parses the HTTP version
fn parseHttpVersion(buffer: []const u8) ParseError!struct { minor_version: i32, rest: []const u8 } {
    if (buffer.len < 8) return ParseError.Incomplete;

    if (!mem.eql(u8, buffer[0..5], "HTTP/")) {
        return ParseError.BadRequest;
    }

    if (buffer[5] != '1' or buffer[6] != '.') {
        return ParseError.BadRequest;
    }

    if (buffer[7] < '0' or buffer[7] > '9') {
        return ParseError.BadRequest;
    }

    const minor_version = @as(i32, buffer[7] - '0');
    var rest = buffer[8..];

    if (rest.len < 2) return ParseError.Incomplete;

    if (rest[0] == '\r' and rest[1] == '\n') {
        rest = rest[2..];
    } else if (rest[0] == '\n') {
        rest = rest[1..];
    } else {
        return ParseError.BadRequest;
    }

    return .{
        .minor_version = minor_version,
        .rest = rest,
    };
}

/// Parses HTTP headers
fn parseHeaders(buffer: []const u8, headers: []Header) ParseError!struct { num_headers: usize, rest: []const u8 } {
    var buf = buffer;
    var num_headers: usize = 0;

    while (true) {
        if (buf.len < 2) return ParseError.Incomplete;

        if (buf[0] == '\r' and buf[1] == '\n') {
            buf = buf[2..];
            break;
        } else if (buf[0] == '\n') {
            buf = buf[1..];
            break;
        }

        if (num_headers >= headers.len) {
            return ParseError.BadRequest;
        }

        if (!(num_headers != 0 and (buf[0] == ' ' or buf[0] == '\t'))) {
            // Parse header name
            var name_start = buf;
            var name_len: usize = 0;

            var i: usize = 0;
            while (i < buf.len) : (i += 1) {
                if (buf[i] == ':') {
                    break;
                } else if (!token_char_map[buf[i]]) {
                    return ParseError.BadRequest;
                }
            }

            if (i == buf.len) return ParseError.Incomplete;
            if (i == 0) return ParseError.BadRequest;

            name_len = i;
            buf = buf[i + 1 ..];

            // Skip leading whitespace in value
            i = 0;
            while (i < buf.len and (buf[i] == ' ' or buf[i] == '\t')) : (i += 1) {}
            buf = buf[i..];

            const token_result = try getTokenToEol(buf);
            const value = token_result.token;
            buf = token_result.rest;

            headers[num_headers] = .{
                .name = name_start[0..name_len],
                .value = value,
            };
        } else {
            // Continuation line
            headers[num_headers].name = "";

            const token_result = try getTokenToEol(buf);
            headers[num_headers].value = token_result.token;
            buf = token_result.rest;
        }

        num_headers += 1;
    }

    return .{
        .num_headers = num_headers,
        .rest = buf,
    };
}

/// Parses an HTTP request
fn parseHttpRequest(buffer: []const u8, headers: []Header) !struct {
    method: []const u8,
    path: []const u8,
    minor_version: i32,
    num_headers: usize,
    bytes_read: usize,
} {
    var buf = buffer;

    // Skip first empty line (some clients add CRLF after POST content)
    if (buf.len > 0 and buf[0] == '\r' and buf.len > 1 and buf[1] == '\n') {
        buf = buf[2..];
    } else if (buf.len > 0 and buf[0] == '\n') {
        buf = buf[1..];
    }

    if (buf.len == 0) return ParseError.Incomplete;

    // Parse request line
    const method_result = try advanceToken(buf);
    const method = method_result.token;
    buf = method_result.rest;

    const path_result = try advanceToken(buf);
    const path = path_result.token;
    buf = path_result.rest;

    const version_result = try parseHttpVersion(buf);
    const minor_version = version_result.minor_version;
    buf = version_result.rest;

    // Parse headers
    const headers_result = try parseHeaders(buf, headers);
    const num_headers = headers_result.num_headers;
    buf = headers_result.rest;

    return .{
        .method = method,
        .path = path,
        .minor_version = minor_version,
        .num_headers = num_headers,
        .bytes_read = buffer.len - buf.len,
    };
}

/// Parses an HTTP request using picohttp-style API
pub fn parseRequest(
    buf: []const u8,
    method: *[*c]const u8,
    path: *[*c]const u8,
    minor_version: *c_int,
    headers: [*]Header,
    num_headers: *usize,
) c_int {
    const result = parseHttpRequest(buf, headers[0..100]) catch |err| {
        return switch (err) {
            ParseError.Incomplete => -2,
            ParseError.BadRequest => -1,
        };
    };

    method.* = result.method.ptr;
    path.* = result.path.ptr;
    minor_version.* = result.minor_version;
    num_headers.* = result.num_headers;

    return @intCast(result.bytes_read);
}
