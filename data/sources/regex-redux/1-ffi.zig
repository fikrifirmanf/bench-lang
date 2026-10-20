// regex-redux through Zig's C interop with PCRE2 and its JIT compiler (Zig's standard library has no regex).
const std = @import("std");
const c = @cImport({
    @cDefine("PCRE2_CODE_UNIT_WIDTH", "8");
    @cInclude("pcre2.h");
});

const allocator = std.heap.c_allocator;

const Regex = struct {
    code: *c.pcre2_code_8,
    match: *c.pcre2_match_data_8,

    fn init(pattern: []const u8) !Regex {
        var err: c_int = 0;
        var offset: usize = 0;
        const code = c.pcre2_compile_8(pattern.ptr, pattern.len, 0, &err, &offset, null) orelse return error.BadPattern;
        _ = c.pcre2_jit_compile_8(code, c.PCRE2_JIT_COMPLETE);
        const match = c.pcre2_match_data_create_from_pattern_8(code, null) orelse return error.OutOfMemory;
        return .{ .code = code, .match = match };
    }

    fn deinit(self: Regex) void {
        c.pcre2_match_data_free_8(self.match);
        c.pcre2_code_free_8(self.code);
    }

    // The [start, end) of the next match at or after `from`, or null.
    fn find(self: Regex, text: []const u8, from: usize) ?[2]usize {
        if (c.pcre2_jit_match_8(self.code, text.ptr, text.len, from, 0, self.match, null) < 0) return null;
        const ovector = c.pcre2_get_ovector_pointer_8(self.match);
        return .{ ovector[0], ovector[1] };
    }
};

fn countMatches(pattern: []const u8, text: []const u8) !usize {
    const re = try Regex.init(pattern);
    defer re.deinit();
    var count: usize = 0;
    var start: usize = 0;
    while (start < text.len) : (count += 1) {
        const span = re.find(text, start) orelse break;
        start = span[1];
    }
    return count;
}

fn replaceAll(pattern: []const u8, replacement: []const u8, text: []const u8) ![]u8 {
    const re = try Regex.init(pattern);
    defer re.deinit();
    var out = try std.ArrayList(u8).initCapacity(allocator, text.len);
    var start: usize = 0;
    while (start <= text.len) {
        const span = re.find(text, start) orelse break;
        try out.appendSlice(text[start..span[0]]);
        try out.appendSlice(replacement);
        start = span[1];
        if (span[0] == span[1]) {
            if (start == text.len) break;
            try out.append(text[start]);
            start += 1;
        }
    }
    if (start < text.len) try out.appendSlice(text[start..]);
    return out.toOwnedSlice();
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const file_name = args.next() orelse "25000_in";
    const input = try std.fs.cwd().readFileAlloc(allocator, file_name, 1 << 30);
    const seq = try replaceAll(">.*\n|\n", "", input);

    const stdout = std.io.getStdOut().writer();
    const variants = [_][]const u8{
        "agggtaaa|tttaccct",         "[cgt]gggtaaa|tttaccc[acg]", "a[act]ggtaaa|tttacc[agt]t",
        "ag[act]gtaaa|tttac[agt]ct", "agg[act]taaa|ttta[agt]cct", "aggg[acg]aaa|ttt[cgt]ccct",
        "agggt[cgt]aa|tt[acg]accct", "agggta[cgt]a|t[acg]taccct", "agggtaa[cgt]|[acg]ttaccct",
    };
    for (variants) |variant| try stdout.print("{s} {d}\n", .{ variant, try countMatches(variant, seq) });

    const substitutions = [_][2][]const u8{
        .{ "tHa[Nt]", "<4>" },     .{ "aND|caN|Ha[DS]|WaS", "<3>" }, .{ "a[NSt]|BY", "<2>" },
        .{ "<[^>]*>", "|" }, .{ "\\|[^|][^|]*\\|", "-" },
    };
    var replaced: []u8 = try allocator.dupe(u8, seq);
    for (substitutions) |pair| {
        const next = try replaceAll(pair[0], pair[1], replaced);
        allocator.free(replaced);
        replaced = next;
    }
    try stdout.print("\n{d}\n{d}\n{d}\n", .{ input.len, seq.len, replaced.len });
}
