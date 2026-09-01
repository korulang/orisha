const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = .ReleaseFast;

    const backend = b.addModule("backend", .{
        .root_source_file = b.path("output_emitted.zig"),
        .target = target,
        .optimize = optimize,
    });

    const root = b.createModule(.{
        .root_source_file = b.path("bench.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "backend", .module = backend },
        },
    });

    const exe = b.addExecutable(.{
        .name = "router-dispatch-bench",
        .root_module = root,
    });

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);

    const run_step = b.step("run", "Run dispatch microbench");
    run_step.dependOn(&run.step);
}
