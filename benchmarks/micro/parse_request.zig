const std = @import("std");

const ParseResult = struct {
    method: []const u8,
    path: []const u8,
};

fn parseIndexOf(request: []const u8) ParseResult {
    var method: []const u8 = "GET";
    var path: []const u8 = "/";
    if (std.mem.indexOf(u8, request, " ")) |method_end| {
        method = request[0..method_end];
        const after_method = request[method_end + 1 ..];
        if (std.mem.indexOf(u8, after_method, " ")) |path_end| {
            path = after_method[0..path_end];
        }
    }
    return .{ .method = method, .path = path };
}

fn parseLoop(request: []const u8) ParseResult {
    var method: []const u8 = "GET";
    var path: []const u8 = "/";

    var i: usize = 0;
    while (i < request.len and request[i] != ' ') : (i += 1) {}
    if (i < request.len) {
        method = request[0..i];
        i += 1;
        var j = i;
        while (j < request.len and request[j] != ' ') : (j += 1) {}
        if (j <= request.len) {
            path = request[i..j];
        }
    }

    return .{ .method = method, .path = path };
}

fn runBench(
    label: []const u8,
    parser: anytype,
    requests: []const []const u8,
    iterations: usize,
) !void {
    var timer = try std.time.Timer.start();
    var sum: usize = 0;
    var idx: usize = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const req = requests[idx];
        idx += 1;
        if (idx == requests.len) idx = 0;

        const res = parser(req);
        sum += res.method.len + res.path.len;
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

    var iterations: usize = 5_000_000;
    if (args.len > 1) {
        iterations = try std.fmt.parseInt(usize, args[1], 10);
    }

    const requests = [_][]const u8{
        "GET /plaintext HTTP/1.1\r\nHost: localhost\r\n\r\n",
        "GET /api/users/42 HTTP/1.1\r\nHost: localhost\r\n\r\n",
        "GET /api/health HTTP/1.1\r\nHost: localhost\r\n\r\n",
        "POST /api/users/42 HTTP/1.1\r\nHost: localhost\r\nContent-Length: 0\r\n\r\n",
        "GET /json HTTP/1.1\r\nHost: localhost\r\n\r\n",
    };

    try runBench("parseLoop", parseLoop, &requests, iterations);
    try runBench("parseIndexOf", parseIndexOf, &requests, iterations);
}
