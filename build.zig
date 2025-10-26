const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the tproxy library
    const tproxy_lib = b.addStaticLibrary(.{
        .name = "tproxy",
        .root_source_file = b.path("src/tproxy.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(tproxy_lib);

    // Create the example executable
    const example = b.addExecutable(.{
        .name = "tproxy_example",
        .root_source_file = b.path("example/tproxy_example.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(example);

    // Add run step for the example
    const run_cmd = b.addRunArtifact(example);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the example application");
    run_step.dependOn(&run_cmd.step);
}
