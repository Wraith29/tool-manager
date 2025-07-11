const std = @import("std");
const Module = std.Build.Module;
const Step = std.Build.Step;
const ResolvedTarget = std.Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod, const exe = buildExecutable(b, target, optimize);
    addRunStep(b, exe);
    addUnitTests(b, exe_mod);

    addGenCmdStep(b);
}

fn buildExecutable(
    b: *std.Build,
    target: ResolvedTarget,
    optimize: OptimizeMode,
) struct { *Module, *Step.Compile } {
    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "tool_manager",
        .root_module = exe_module,
    });

    b.installArtifact(exe);

    return .{ exe_module, exe };
}

fn addRunStep(b: *std.Build, exe: *Step.Compile) void {
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn addUnitTests(b: *std.Build, exe_mod: *Module) void {
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn addGenCmdStep(b: *std.Build) void {
    const gencmd_exe = b.addExecutable(.{
        .name = "gencmd",
        .root_source_file = b.path("tools/gencmd.zig"),
        .target = b.graph.host,
    });

    const run_step = b.addRunArtifact(gencmd_exe);

    if (b.args) |args| {
        run_step.addArgs(args);
    }

    const gencmd_step = b.step("gencmd", "Generate a new command from the example_cmd.zig template");
    gencmd_step.dependOn(&run_step.step);
}
