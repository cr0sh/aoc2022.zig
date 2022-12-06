const std = @import("std");
const common = @import("common");
const ctregex = @import("ctregex");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const BoundedArray = std.BoundedArray;
const assert = std.debug.assert;
const print = std.debug.print;

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

fn unique(comptime T: type, s: []const T) bool {
    if (s.len <= 1) return true;
    for (s) |x, i| {
        for (s[i + 1 ..]) |y| {
            if (x == y) return false;
        }
    }

    return true;
}

fn solve1(allocator: Allocator, chars: []const u8) !usize {
    _ = allocator;
    var i: usize = 0;
    while (i < chars.len - 4) : (i += 1) {
        if (unique(u8, chars[i .. i + 4])) return i + 4;
    }

    return error.NoMarkerFound;
}

fn solve2(allocator: Allocator, chars: []const u8) !usize {
    _ = allocator;
    var i: usize = 0;
    while (i < chars.len - 14) : (i += 1) {
        if (unique(u8, chars[i .. i + 14])) return i + 14;
    }

    return error.NoMarkerFound;
}

const test_cases = [_]struct { input: []const u8, output1: usize, output2: usize }{
    .{ .input = "mjqjpqmgbljsphdztnvjfqwrcgsmlb", .output1 = 7, .output2 = 19 },
    .{ .input = "bvwbjplbgvbhsrlpgdmjqwftvncz", .output1 = 5, .output2 = 23 },
    .{ .input = "nppdvjthqldpwncqszvftbrmjlhg", .output1 = 6, .output2 = 23 },
    .{ .input = "nznrnfrfntjfmvfwmzdfjlvtqnbhcprsg", .output1 = 10, .output2 = 29 },
    .{ .input = "zcfzfwzzqfrljwzlrfnpqdbhtmscgvjw", .output1 = 11, .output2 = 26 },
};

test "given testcase from aoc" {
    for (test_cases) |case, i| {
        print("testing case {}...\n", .{i + 1});
        var p = try solve1(std.testing.allocator, case.input);
        print("p = {}\n", .{p});
        assert(p == case.output1);
    }
}

test "given testcase from aoc, part 2" {
    for (test_cases) |case, i| {
        print("testing case {}...\n", .{i + 1});
        var p = try solve2(std.testing.allocator, case.input);
        print("p = {}\n", .{p});
        assert(p == case.output2);
    }
}
