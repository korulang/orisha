const std = @import("std");

fn buildResponse(allocator: std.mem.Allocator, status: u16, body: []const u8) usize {
    var response_buf: std.ArrayList(u8) = .empty;
    defer response_buf.deinit(allocator);

    const status_text = switch (status) {
        200 => "OK",
        201 => "Created",
        204 => "No Content",
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        500 => "Internal Server Error",
        else => "Unknown",
    };

    response_buf.appendSlice(allocator, "HTTP/1.1 ") catch {};
    var status_buf: [3]u8 = undefined;
    _ = std.fmt.bufPrint(&status_buf, "{}", .{status}) catch {};
    response_buf.appendSlice(allocator, &status_buf) catch {};
    response_buf.appendSlice(allocator, " ") catch {};
    response_buf.appendSlice(allocator, status_text) catch {};
    response_buf.appendSlice(allocator, "\r\n") catch {};

    response_buf.appendSlice(allocator, "Content-Type: text/plain\r\n") catch {};
    response_buf.appendSlice(allocator, "Content-Length: ") catch {};
    var len_buf: [20]u8 = undefined;
    const len_str = std.fmt.bufPrint(&len_buf, "{}", .{body.len}) catch "0";
    response_buf.appendSlice(allocator, len_str) catch {};
    response_buf.appendSlice(allocator, "\r\nConnection: close\r\n\r\n") catch {};

    response_buf.appendSlice(allocator, body) catch {};

    return response_buf.items.len;
}

fn runBench(label: []const u8, bodies: []const []const u8, iterations: usize) !void {
    var timer = try std.time.Timer.start();
    var sum: usize = 0;
    var idx: usize = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const body = bodies[idx];
        idx += 1;
        if (idx == bodies.len) idx = 0;

        sum += buildResponse(std.heap.page_allocator, 200, body);
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

    var iterations: usize = 1_000_000;
    if (args.len > 1) {
        iterations = try std.fmt.parseInt(usize, args[1], 10);
    }

    const bodies = [_][]const u8{
        "Hello, World!",
        "{\"message\":\"Hello, World!\"}",
        "{\"status\":\"ok\"}",
        "Not Found",
        "user_42",
    };

    try runBench("response_build", &bodies, iterations);
}
