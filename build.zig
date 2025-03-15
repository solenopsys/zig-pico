const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "picozig",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/request/test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    // Создаем шаг для запуска тестов
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
