// Prime sieve as a chain of stackful coroutines: a generator of 2, 3, 4, ... and one filter per prime found.
// Zig dropped async/await after 0.10 (which 1.zig needs), so the coroutines switch with libc's ucontext.
const std = @import("std");
const c = @cImport(@cInclude("ucontext.h"));

const STACK_SIZE = 32 * 1024;
const allocator = std.heap.c_allocator;

const Coro = struct {
    context: c.ucontext_t = undefined,
    caller: *c.ucontext_t = undefined,
    source: ?*Coro,
    prime: u32,
    value: u32 = 0,
    started: bool = false,

    fn yield(self: *Coro, value: u32) void {
        self.value = value;
        _ = c.swapcontext(&self.context, self.caller);
    }

    fn next(self: *Coro) u32 {
        var here: c.ucontext_t = undefined;
        if (!self.started) {
            // A body reads its own Coro from here on its first run.
            self.started = true;
            current = self;
        }
        self.caller = &here;
        _ = c.swapcontext(&here, &self.context);
        return self.value;
    }
};

var current: *Coro = undefined;

fn generate() callconv(.C) void {
    const self = current;
    var i: u32 = 2;
    while (true) : (i += 1) self.yield(i);
}

fn filter() callconv(.C) void {
    const self = current;
    while (true) {
        const value = self.source.?.next();
        if (value % self.prime != 0) self.yield(value);
    }
}

fn spawn(body: *const fn () callconv(.C) void, source: ?*Coro, prime: u32) !*Coro {
    const coro = try allocator.create(Coro);
    coro.* = .{ .source = source, .prime = prime };
    _ = c.getcontext(&coro.context);
    const stack = try allocator.alloc(u8, STACK_SIZE);
    coro.context.uc_stack.ss_sp = stack.ptr;
    coro.context.uc_stack.ss_size = STACK_SIZE;
    coro.context.uc_link = null;
    c.makecontext(&coro.context, body, 0);
    return coro;
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const n = if (args.next()) |arg| try std.fmt.parseInt(u32, arg, 10) else 100;
    var out = std.io.bufferedWriter(std.io.getStdOut().writer());
    var chain = try spawn(generate, null, 0);
    for (0..n) |_| {
        const prime = chain.next();
        try out.writer().print("{d}\n", .{prime});
        chain = try spawn(filter, chain, prime);
    }
    try out.flush();
}
