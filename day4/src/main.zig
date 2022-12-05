const std = @import("std");
const common = @import("common");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const print = std.debug.print;

const RangeInclusive = struct {
    start: u64,
    end: u64,

    fn init(start: u64, end: u64) RangeInclusive {
        assert(start <= end);
        return .{ .start = start, .end = end };
    }

    fn contains(self: RangeInclusive, other: RangeInclusive) bool {
        return self.start <= other.start and other.end <= self.end;
    }

    fn overlappingRange(self: RangeInclusive, other: RangeInclusive) ?RangeInclusive {
        var start = std.math.max(self.start, other.start);
        var end = std.math.min(self.end, other.end);

        if (start > end) {
            return null;
        }

        return RangeInclusive.init(start, end);
    }

    const Iterator = struct {
        start: u64,
        end: u64,
        current: u64,

        fn next(self: *Iterator) ?u64 {
            self.current += 1;
            if (self.end < self.current) {
                return null;
            }

            return self.current - 1;
        }
    };

    fn iterator(self: RangeInclusive) Iterator {
        return .{ .start = self.start, .end = self.end, .current = self.start };
    }
};

const Parser = struct {
    lines: std.mem.SplitIterator(u8),
    fn init(chars: []const u8) Parser {
        return .{ .lines = std.mem.split(u8, chars, "\n") };
    }

    fn next(self: *Parser) !?struct { first: RangeInclusive, second: RangeInclusive } {
        var line = self.lines.next() orelse return null;
        if (std.mem.eql(u8, line, "")) return null;
        print("{s}\n", .{line});
        var ranges = std.mem.split(u8, line, ",");
        var range1 = ranges.next() orelse unreachable;
        var numbers1 = std.mem.split(u8, range1, "-");
        var start1 = try std.fmt.parseInt(u64, numbers1.next() orelse unreachable, 10);
        var end1 = try std.fmt.parseInt(u64, numbers1.next() orelse unreachable, 10);

        var range2 = ranges.next() orelse unreachable;
        var numbers2 = std.mem.split(u8, range2, "-");
        var start2 = try std.fmt.parseInt(u64, numbers2.next() orelse unreachable, 10);
        var end2 = try std.fmt.parseInt(u64, numbers2.next() orelse unreachable, 10);

        return .{ .first = RangeInclusive.init(start1, end1), .second = RangeInclusive.init(start2, end2) };
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

    print("{}\n", .{p});
}

fn solve1(allocator: Allocator, chars: []const u8) !u64 {
    _ = allocator;
    var p: u64 = 0;

    var parser = Parser.init(chars);
    while (try parser.next()) |pair| {
        if (pair.first.contains(pair.second) or pair.second.contains(pair.first)) {
            p += 1;
        }
    }
    return p;
}

fn solve2(allocator: Allocator, chars: []const u8) !u64 {
    _ = allocator;
    var p: u64 = 0;

    var parser = Parser.init(chars);
    while (try parser.next()) |pair| {
        _ = pair.first.overlappingRange(pair.second) orelse continue;
        p += 1;
    }

    return p;
}

const test_case =
    \\2-4,6-8
    \\2-3,4-5
    \\5-7,7-9
    \\2-8,3-7
    \\6-6,4-6
    \\2-6,4-8
;

test "given testcase from aoc" {
    var p = try solve1(std.testing.allocator, test_case);

    print("p = {}\n", .{p});
    assert(p == 2);
}

test "given testcase from aoc, part 2" {
    var p = try solve2(std.testing.allocator, test_case);

    print("p = {}\n", .{p});
    assert(p == 4);
}
