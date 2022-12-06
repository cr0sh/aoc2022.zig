const std = @import("std");
const common = @import("common");
const ctregex = @import("ctregex");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const BoundedArray = std.BoundedArray;
const assert = std.debug.assert;
const print = std.debug.print;

fn Stacks(comptime max_stacks: usize) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        inner: BoundedArray(Stack, max_stacks),

        const Stack = ArrayList(u8);

        fn init(allocator: Allocator) !Self {
            return .{ .allocator = allocator, .inner = try BoundedArray(Stack, max_stacks).init(0) };
        }

        fn deinit(self: Self) void {
            for (self.inner.constSlice()) |item| item.deinit();
        }

        /// Ensures at least `ensure_count` stacks are in this `Stacks`.
        fn ensureStacks(self: *Self, ensure_count: usize) !void {
            while (self.inner.len < ensure_count)
                try self.inner.append(Stack.init(self.allocator));
        }

        fn reverseAll(self: *Self) void {
            for (self.inner.slice()) |stack| {
                std.mem.reverse(u8, stack.items);
            }
        }

        fn dump(self: *Self) void {
            for (self.inner.slice()) |stack, i| {
                print("{}: {s}\n", .{ i + 1, stack.items });
            }
        }

        fn pushItem(self: *Self, where: usize, item: u8) !void {
            assert(1 <= where);
            assert(where <= self.inner.len);

            try self.inner.slice()[where - 1].append(item);
        }

        fn move(self: *Self, from: usize, to: usize) !void {
            assert(1 <= from);
            assert(from <= self.inner.len);
            assert(1 <= to);
            assert(to <= self.inner.len);

            var item = self.inner.slice()[from - 1].popOrNull() orelse return error.NoElement;
            try self.inner.slice()[to - 1].append(item);
        }

        fn moveNTimes(self: *Self, n: usize, from: usize, to: usize) !void {
            var i: usize = 0;
            while (i < n) : (i += 1) {
                try self.move(from, to);
            }
        }

        fn moveAggregated(self: *Self, n: usize, from: usize, to: usize) !void {
            var f = &self.inner.slice()[from - 1];
            assert(f.items.len >= n);
            var t = &self.inner.slice()[to - 1];

            for (f.items[f.items.len - n ..]) |item| {
                try t.append(item);
            }

            f.shrinkAndFree(f.items.len - n);
        }

        const TopsIterator = struct {
            stacks: *const Self,
            current: usize,

            fn next(self: *TopsIterator) ?u8 {
                if (self.current >= self.stacks.inner.len) return null;
                for (self.stacks.inner.constSlice()[self.current..]) |stack, i| {
                    if (stack.items.len == 0) continue;
                    self.current += i + 1;
                    return stack.items[stack.items.len - 1];
                }
                return null;
            }
        };

        fn iterTops(self: *const Self) TopsIterator {
            return .{ .stacks = self, .current = 0 };
        }
    };
}

const StackParser = struct {
    const Self = @This();

    lines: std.mem.SplitIterator(u8),
    current_line: ?[]const u8 = null,
    current_pos: usize = 0,

    fn init(chars: []const u8) Self {
        return .{ .lines = std.mem.split(u8, chars, "\n") };
    }

    fn next(self: *Self) !?struct { where: usize, item: u8 } {
        while (true) {
            if (self.current_line == null) {
                self.current_line = self.lines.next() orelse return null;
                self.current_pos = 0;
            }

            if (self.current_pos >= self.current_line.?.len) {
                self.current_line = null;
                continue;
            }

            assert(self.current_line.?.len % 4 == 3);

            var chunk = self.current_line.?[self.current_pos .. self.current_pos + 3];
            if (chunk[0] == '[' and chunk[2] == ']') {
                var ret = .{ .where = self.current_pos / 4 + 1, .item = chunk[1] };
                self.current_pos += 4;
                return ret;
            }
            self.current_pos += 4;
        }

        return null;
    }
};

const ActionParser = struct {
    const Self = @This();

    lines: std.mem.SplitIterator(u8),

    fn init(chars: []const u8) Self {
        return .{ .lines = std.mem.split(u8, chars, "\n") };
    }

    fn next(self: *Self) !?struct { n: usize, from: usize, to: usize } {
        @setEvalBranchQuota(4096);
        var line = self.lines.next() orelse return null;
        var res = try ctregex.match("move\\ (\\d+)\\ from\\ (\\d+)\\ to\\ (\\d+)", .{}, line) orelse {
            return null;
        };
        return .{ .n = try std.fmt.parseUnsigned(usize, res.captures[0].?, 10), .from = try std.fmt.parseUnsigned(usize, res.captures[1].?, 10), .to = try std.fmt.parseUnsigned(usize, res.captures[2].?, 10) };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var stage = try common.parseStageFromCli();

    var stdin = std.io.getStdIn().reader();
    var chars = try stdin.readAllAlloc(allocator, 1 << 20);
    defer ArrayList(u8).fromOwnedSlice(allocator, chars).deinit();

    var p = switch (stage) {
        1 => try solve1(allocator, chars),
        2 => try solve2(allocator, chars),
        else => std.debug.panic("unhandled stage {}", .{stage}),
    };

    print("{s}\n", .{p});
}

fn solve1(allocator: Allocator, chars: []const u8) ![]const u8 {
    var sp = std.mem.split(u8, chars, "\n\n");
    var stack_str = sp.next() orelse unreachable;
    var action_str = sp.next() orelse unreachable;

    var stack_parser = StackParser.init(stack_str);
    var action_parser = ActionParser.init(action_str);

    var stacks = try Stacks(64).init(allocator);
    defer stacks.deinit();

    while (try stack_parser.next()) |s| {
        try stacks.ensureStacks(s.where);
        try stacks.pushItem(s.where, s.item);
    }

    stacks.dump();

    stacks.reverseAll();

    stacks.dump();

    while (try action_parser.next()) |a| {
        try stacks.moveNTimes(a.n, a.from, a.to);
    }

    stacks.dump();

    var ret = ArrayList(u8).init(allocator);
    var tops = stacks.iterTops();

    while (tops.next()) |top| try ret.append(top);

    return ret.toOwnedSlice();
}

fn solve2(allocator: Allocator, chars: []const u8) ![]const u8 {
    var sp = std.mem.split(u8, chars, "\n\n");
    var stack_str = sp.next() orelse unreachable;
    var action_str = sp.next() orelse unreachable;

    var stack_parser = StackParser.init(stack_str);
    var action_parser = ActionParser.init(action_str);

    var stacks = try Stacks(64).init(allocator);
    defer stacks.deinit();

    while (try stack_parser.next()) |s| {
        try stacks.ensureStacks(s.where);
        try stacks.pushItem(s.where, s.item);
    }

    stacks.dump();

    stacks.reverseAll();

    stacks.dump();

    while (try action_parser.next()) |a| {
        try stacks.moveAggregated(a.n, a.from, a.to);
    }

    stacks.dump();

    var ret = ArrayList(u8).init(allocator);
    var tops = stacks.iterTops();

    while (tops.next()) |top| try ret.append(top);

    return ret.toOwnedSlice();
}

const test_case =
    \\    [D]    
    \\[N] [C]    
    \\[Z] [M] [P]
    \\ 1   2   3 
    \\
    \\move 1 from 2 to 1
    \\move 3 from 1 to 3
    \\move 2 from 2 to 1
    \\move 1 from 1 to 2
;

test "manual testcase" {
    var stacks = try Stacks(3).init(std.testing.allocator);
    defer stacks.deinit();
    try stacks.ensureStacks(3);
    try stacks.pushItem(1, 'Z');
    try stacks.pushItem(1, 'N');
    try stacks.pushItem(2, 'M');
    try stacks.pushItem(2, 'C');
    try stacks.pushItem(2, 'D');
    try stacks.pushItem(3, 'P');
    try stacks.moveNTimes(1, 2, 1);
    try stacks.moveNTimes(3, 1, 3);
    try stacks.moveNTimes(2, 2, 1);
    try stacks.moveNTimes(1, 1, 2);

    var it = stacks.iterTops();
    // Cannot compare ?u8 with comptime int?
    var x = it.next() orelse @panic("null");
    assert(x == 'C');
    var y = it.next() orelse @panic("null");
    assert(y == 'M');
    var z = it.next() orelse @panic("null");
    assert(z == 'Z');
    assert(it.next() == null);
}

test "given testcase from aoc" {
    var p = try solve1(std.testing.allocator, test_case);
    defer std.testing.allocator.free(p);

    print("p = {s}\n", .{p});
    assert(std.mem.eql(u8, p, "CMZ"));
}

test "given testcase from aoc, part 2" {
    var p = try solve2(std.testing.allocator, test_case);
    defer std.testing.allocator.free(p);

    print("p = {s}\n", .{p});
    assert(std.mem.eql(u8, p, "MCD"));
}
