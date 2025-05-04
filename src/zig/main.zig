// hello.zig
const std = @import("std");

pub fn main() !void {
    const outw = std.io.getStdOut().writer();
    try outw.print("Hello, world!\n", .{});
}
