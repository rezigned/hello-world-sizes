// hello.zig
const std = @import("std");

pub fn main() !void {
    // zig < 0.15
    // const outw = std.io.getStdOut().writer();
    // try outw.print("Hello, world!\n", .{});

    // zig >= 0.15
    try std.fs.File.stdout().writeAll("Hello, world!\n");
}
