// JSON round trip on std.json.Value: parse, serialize exactly as Python's json.dumps(separators=(',', ':')) does
// (ASCII-only escapes, shortest round-trip floats), print the MD5. 1.zig parses only canada.json's shape.
const std = @import("std");

const allocator = std.heap.c_allocator;
const Output = std.ArrayList(u8);

// Python's repr(float): shortest round-trip digits, positional for 1e-4 <= |x| < 1e16.
fn writeFloat(out: *Output, x: f64) !void {
    var buffer: [64]u8 = undefined;
    const sci = try std.fmt.bufPrint(&buffer, "{e}", .{@abs(x)}); // shortest digits, e.g. "6.5625e1"
    const e = std.mem.indexOfScalar(u8, sci, 'e').?;
    var exponent = try std.fmt.parseInt(i32, sci[e + 1 ..], 10);
    var digits_buffer: [32]u8 = undefined;
    var ndigits: usize = 0;
    for (sci[0..e]) |ch| {
        if (ch != '.') {
            digits_buffer[ndigits] = ch;
            ndigits += 1;
        }
    }
    var lead: usize = 0;
    while (lead < ndigits - 1 and digits_buffer[lead] == '0') : (lead += 1) exponent -= 1;
    var digits = digits_buffer[lead..ndigits];
    while (digits.len > 1 and digits[digits.len - 1] == '0') digits = digits[0 .. digits.len - 1];

    if (x < 0 or (x == 0 and std.math.signbit(x))) try out.append('-');
    if (exponent >= -4 and exponent < 16) {
        if (exponent < 0) {
            try out.appendSlice("0.");
            try out.appendNTimes('0', @intCast(-exponent - 1));
            try out.appendSlice(digits);
        } else {
            const whole: usize = @intCast(exponent + 1);
            if (digits.len > whole) {
                try out.appendSlice(digits[0..whole]);
                try out.append('.');
                try out.appendSlice(digits[whole..]);
            } else {
                try out.appendSlice(digits);
                try out.appendNTimes('0', whole - digits.len);
                try out.appendSlice(".0");
            }
        }
    } else {
        try out.append(digits[0]);
        if (digits.len > 1) {
            try out.append('.');
            try out.appendSlice(digits[1..]);
        }
        try out.writer().print("e{c}{d:0>2}", .{ @as(u8, if (exponent < 0) '-' else '+'), @abs(exponent) });
    }
}

fn writeString(out: *Output, s: []const u8) !void {
    try out.append('"');
    var view = try std.unicode.Utf8View.init(s);
    var it = view.iterator();
    while (it.nextCodepoint()) |cp| {
        switch (cp) {
            '"' => try out.appendSlice("\\\""),
            '\\' => try out.appendSlice("\\\\"),
            '\n' => try out.appendSlice("\\n"),
            '\r' => try out.appendSlice("\\r"),
            '\t' => try out.appendSlice("\\t"),
            8 => try out.appendSlice("\\b"),
            12 => try out.appendSlice("\\f"),
            else => {
                if (cp < 0x20 or (cp >= 0x80 and cp < 0x10000)) {
                    try out.writer().print("\\u{x:0>4}", .{cp});
                } else if (cp >= 0x10000) {
                    const v = cp - 0x10000;
                    try out.writer().print("\\u{x:0>4}\\u{x:0>4}", .{ 0xd800 + (v >> 10), 0xdc00 + (v & 0x3ff) });
                } else {
                    try out.append(@intCast(cp));
                }
            },
        }
    }
    try out.append('"');
}

fn dump(out: *Output, value: std.json.Value) !void {
    switch (value) {
        .null => try out.appendSlice("null"),
        .bool => |b| try out.appendSlice(if (b) "true" else "false"),
        .integer => |i| try out.writer().print("{d}", .{i}),
        .float => |f| try writeFloat(out, f),
        .number_string => |s| try out.appendSlice(s),
        .string => |s| try writeString(out, s),
        .array => |array| {
            try out.append('[');
            for (array.items, 0..) |item, i| {
                if (i > 0) try out.append(',');
                try dump(out, item);
            }
            try out.append(']');
        },
        .object => |object| {
            try out.append('{');
            var it = object.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try out.append(',');
                first = false;
                try writeString(out, entry.key_ptr.*);
                try out.append(':');
                try dump(out, entry.value_ptr.*);
            }
            try out.append('}');
        },
    }
}

fn printHash(writer: anytype, value: std.json.Value) !void {
    var out = Output.init(allocator);
    defer out.deinit();
    try dump(&out, value);
    var hash: [std.crypto.hash.Md5.digest_length]u8 = undefined;
    std.crypto.hash.Md5.hash(out.items, &hash, .{});
    try writer.print("{s}\n", .{std.fmt.fmtSliceHexLower(&hash)});
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const name = args.next() orelse "sample";
    const n = if (args.next()) |arg| try std.fmt.parseInt(usize, arg, 10) else 3;
    const file_name = try std.mem.concat(allocator, u8, &.{ name, ".json" });
    var text = try std.fs.cwd().readFileAlloc(allocator, file_name, 1 << 30);
    if (std.mem.startsWith(u8, text, "\xef\xbb\xbf")) text = text[3..];

    const stdout = std.io.getStdOut().writer();
    const single = try std.json.parseFromSlice(std.json.Value, allocator, text, .{});
    try printHash(stdout, single.value);

    var items = std.json.Array.init(allocator);
    for (0..n) |_| try items.append((try std.json.parseFromSlice(std.json.Value, allocator, text, .{})).value);
    try printHash(stdout, .{ .array = items });
}
