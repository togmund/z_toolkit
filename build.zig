const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a simple executable for testing
    const exe = b.addExecutable(.{
        .name = "z_toolkit_test",
        .root_module = b.addModule("root", .{
            .root_source_file = .{ .cwd_relative = "src/main.zig" },
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the test executable");
    run_step.dependOn(&run_cmd.step);

    // Create Zig tests
    const lib_unit_tests = b.addTest(.{
        .root_module = b.addModule("test", .{
            .root_source_file = .{ .cwd_relative = "src/edit.zig" },
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
