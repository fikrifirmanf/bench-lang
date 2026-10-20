const std = @import("std");

// Upstream's build file, plus: a program that includes pcre2.h is linked against the system PCRE2 library.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{
        .name = "app",
        .root_source_file = b.path("app.zig"),
        .target = target,
        .optimize = std.builtin.Mode.ReleaseFast,
    });
    exe.linkLibC();
    const source = std.fs.cwd().readFileAlloc(b.allocator, "app.zig", 1 << 20) catch @panic("cannot read app.zig");
    if (std.mem.indexOf(u8, source, "pcre2.h") != null) exe.linkSystemLibrary("pcre2-8");
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
