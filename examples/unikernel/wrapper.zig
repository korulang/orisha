// C-ABI seam between Unikraft's boot path and Koru's emitted flow.
const app = @import("output_emitted.zig");

export fn koru_main() void {
    app.main_module.koru_start_flow();
    app.main_module.flow0();
    app.main_module.koru_end_flow();
}
