const std = @import("std");
const builtin = @import("builtin");

pub fn findCharFast(buffer: []const u8, ranges: []const u8) ?usize {
    if (buffer.len == 0 or ranges.len == 0 or ranges.len % 2 != 0) {
        return null;
    }

    const vector_size = switch (builtin.cpu.arch) {
        .x86_64, .aarch64 => 16, // 128-bit vector
        else => 8, // 64-bit vector
    };
    if (buffer.len < vector_size) {
        return findCharSequential(buffer, ranges);
    }

    const VectorType = @Vector(vector_size, u8);

    var i: usize = 0;
    while (i + vector_size <= buffer.len) {
        const data_vec = @as(VectorType, buffer[i..][0..vector_size].*);

        var j: usize = 0;
        while (j < vector_size) : (j += 1) {
            const c = data_vec[j];
            var range_idx: usize = 0;
            while (range_idx < ranges.len) : (range_idx += 2) {
                if (ranges[range_idx] <= c and c <= ranges[range_idx + 1]) {
                    return i + j;
                }
            }
        }

        i += vector_size;
    }

    if (i < buffer.len) {
        if (findCharSequential(buffer[i..], ranges)) |idx| {
            return i + idx;
        }
    }
    return null;
}

fn findCharSequential(buffer: []const u8, ranges: []const u8) ?usize {
    for (buffer, 0..) |c, i| {
        var j: usize = 0;
        while (j < ranges.len) : (j += 2) {
            if (ranges[j] <= c and c <= ranges[j + 1]) {
                return i;
            }
        }
    }
    return null;
}
