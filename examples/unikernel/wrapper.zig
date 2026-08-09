// C-ABI seam between Unikraft's boot path and Koru's emitted flow.
const std = @import("std");
const app = @import("output_emitted.zig");

// A freestanding target has no page size to ask the OS about, so Zig refuses to
// guess one — `std.heap.PageAllocator` will not compile without being told
// (`error: freestanding/other page_size_max must provided with
// std.options.page_size_max`). That refusal was the second of the two things
// stopping Orisha from linking into a unikernel; the first was the libc time
// header, now gone from lib/index.kz.
//
// This is not a workaround: 4 KiB IS the page size on Unikraft/x86_64, and the
// root module is exactly where a fact about the target belongs. The compiler
// asked which machine this is, and this answers.
pub const std_options: std.Options = .{
    .page_size_min = 4096,
    .page_size_max = 4096,
};

export fn koru_main() void {
    app.main_module.koru_start_flow();
    app.main_module.flow0();
    app.main_module.koru_end_flow();
}
