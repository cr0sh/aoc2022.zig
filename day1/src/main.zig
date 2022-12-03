const std = @import("std");

fn lessThan(ctx: void, a: u64, b: u64) std.math.Order {
    _ = ctx;
    return std.math.order(b, a);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var pq = std.PriorityQueue(u64, void, lessThan).init(allocator, void{});

    var stdin = std.io.getStdIn().reader();
    var done: bool = false;

    while (!done) {
        var n: u64 = 0;
        while (!done) {
            var s = stdin.readUntilDelimiterAlloc(allocator, '\n', 1024) catch |err| {
                if (err == error.EndOfStream) {
                    done = true;
                    break;
                } else {
                    return err;
                }
            };
            var s_ = std.mem.trim(u8, s, "\n");
            if (std.mem.eql(u8, s_, "")) {
                break;
            }
            n += try std.fmt.parseInt(u64, s_, 10);
        }
        try pq.add(n);
    }

    done = false;
    var n = pq.remove();
    std.debug.print("{}\n", .{n});
    n += pq.remove();
    n += pq.remove();
    std.debug.print("{}\n", .{n});
}
