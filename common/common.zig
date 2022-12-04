const std = @import("std");
const clap = @import("clap");

pub fn parseStageFromCli() !u32 {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help            Prints this help message
        \\-s, --stage <u32>     Stage 1/2 selector
    );
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{ .diagnostic = &diag }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    return res.args.stage orelse {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        std.c.exit(1);
    };
}
