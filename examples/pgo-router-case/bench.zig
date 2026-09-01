const std = @import("std");
const backend = @import("backend");

fn run(label: []const u8, handler: anytype, req: *backend.koru_orisha.Request, n: usize) !void {
    // Warm up — stabilize icache before timing.
    var sum: usize = 0;
    for (0..1000) |_| {
        const res = handler(.{ .req = req });
        sum +%= res.status +% res.body.len;
    }
    std.mem.doNotOptimizeAway(sum);

    var timer = try std.time.Timer.start();
    sum = 0;
    for (0..n) |i| {
        // Path stays /baseline11 at runtime but must not fold to a compile-time constant.
        req.path = blk: {
            const base: [*:0]const u8 = "/baseline11";
            std.mem.doNotOptimizeAway(&base);
            std.mem.doNotOptimizeAway(&i);
            break :blk base[0..11];
        };
        const res = handler(.{ .req = req });
        sum +%= res.status +% res.body.len;
    }
    std.mem.doNotOptimizeAway(sum);

    const ns = @as(f64, @floatFromInt(timer.read()));
    const iters = @as(f64, @floatFromInt(n));
    std.debug.print("{s}: {d:.1} ns/op  ({d:.2} Mop/s)\n", .{ label, ns / iters, iters / (ns / 1_000_000_000.0) / 1_000_000.0 });
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const n = if (args.len > 1) try std.fmt.parseInt(usize, args[1], 10) else 5_000_000;

    var req = backend.koru_orisha.Request{
        .method = "GET",
        .path = "/baseline11",
        .query = "a=13&b=42",
        .body = null,
        .allocator = allocator,
    };
    std.mem.doNotOptimizeAway(&req);

    const handler = backend.koru_orisha.handler_event.handler;
    try run("baseline11-dispatch", handler, &req, n);
}
