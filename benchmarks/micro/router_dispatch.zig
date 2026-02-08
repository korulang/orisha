const std = @import("std");

// Uses the generated code from the dynamic Orisha benchmark.
const backend = @import("../dynamic/orisha/output_emitted.zig");

fn runBench(
    label: []const u8,
    handler: anytype,
    requests: []backend.main_module.orisha.Request,
    iterations: usize,
) !void {
    var timer = try std.time.Timer.start();
    var sum: usize = 0;
    var idx: usize = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        var req = requests[idx];
        idx += 1;
        if (idx == requests.len) idx = 0;

        const res = handler(.{ .req = &req });
        switch (res) {
            .response => |r| {
                sum += r.status;
                sum += r.body.len;
            },
        }
    }

    const elapsed = timer.read();
    std.mem.doNotOptimizeAway(sum);

    const iters_f = @as(f64, @floatFromInt(iterations));
    const elapsed_f = @as(f64, @floatFromInt(elapsed));
    const ns_per = elapsed_f / iters_f;
    const rps = iters_f / (elapsed_f / 1_000_000_000.0);

    std.debug.print(
        "{s}: {d} iters, {d:.2} ns/op, {d:.2} ops/sec\n",
        .{ label, iterations, ns_per, rps },
    );
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var iterations: usize = 10_000_000;
    if (args.len > 1) {
        iterations = try std.fmt.parseInt(usize, args[1], 10);
    }

    const requests = [_]backend.main_module.orisha.Request{
        .{ .method = "GET", .path = "/plaintext", .body = null, .allocator = allocator },
        .{ .method = "GET", .path = "/json", .body = null, .allocator = allocator },
        .{ .method = "GET", .path = "/api/health", .body = null, .allocator = allocator },
        .{ .method = "GET", .path = "/api/users/42", .body = null, .allocator = allocator },
        .{ .method = "GET", .path = "/nope", .body = null, .allocator = allocator },
    };

    const handler = backend.main_module.orisha.handler_event.handler;
    try runBench("router_dispatch", handler, &requests, iterations);
}
