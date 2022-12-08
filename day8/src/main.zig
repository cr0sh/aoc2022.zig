const std = @import("std");
const common = @import("common");
const ctregex = @import("ctregex");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const BoundedArray = std.BoundedArray;
const expect = std.testing.expect;
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

const Direction = enum(u8) {
    const Self = @This();

    N = 0,
    E = 1,
    S = 2,
    W = 3,

    fn next(self: Self) Self {
        return @bitCast(Self, (@bitCast(u8, self) + 1) % 4);
    }

    fn dx(self: Self) isize {
        return switch (self) {
            Self.N, Self.S => 0,
            Self.W => -1,
            Self.E => 1,
        };
    }

    fn dy(self: Self) isize {
        return switch (self) {
            Self.W, Self.E => 0,
            Self.N => -1,
            Self.S => 1,
        };
    }
};

fn scan(map: ArrayList([]const u8), mark: ArrayList([]bool), dir: Direction, xlen: usize, ylen: usize, startx: usize, starty: usize) void {
    var x = startx;
    var y = starty;

    var highest: ?u8 = null;
    print("start scan: startx={}, starty={}, dir={}\n", .{ startx, starty, dir });

    while (0 <= x and x < xlen and 0 <= y and y < ylen) {
        print("x = {}, y = {}", .{ x, y });
        if (highest == null or highest orelse unreachable < map.items[y][x]) {
            highest = map.items[y][x];
            mark.items[y][x] = true;
            print(",mark", .{});
        }
        print("\n", .{});

        x = @bitCast(usize, @bitCast(isize, x) + dir.dx());
        y = @bitCast(usize, @bitCast(isize, y) + dir.dy());
    }
    print("end scan\n", .{});
}

fn countTrees(map: ArrayList([]const u8), dir: Direction, xlen: usize, ylen: usize, startx: usize, starty: usize) usize {
    var x = startx;
    var y = starty;

    var count: usize = 0;
    print("start countTrees: startx={}, starty={}, dir={}\n", .{ startx, starty, dir });

    while (0 <= x and x < xlen and 0 <= y and y < ylen) {
        print("x = {}, y = {}", .{ x, y });
        if (x == startx and y == starty) {
            print("\n", .{});
            x = @bitCast(usize, @bitCast(isize, x) + dir.dx());
            y = @bitCast(usize, @bitCast(isize, y) + dir.dy());
            continue;
        }
        count += 1;
        if (map.items[starty][startx] <= map.items[y][x]) {
            print(", break\n", .{});
            break;
        }

        print("\n", .{});

        x = @bitCast(usize, @bitCast(isize, x) + dir.dx());
        y = @bitCast(usize, @bitCast(isize, y) + dir.dy());
    }
    print("end scan, count={}\n", .{count});

    return count;
}

fn solve1(allocator: Allocator, chars: []const u8) !usize {
    var nums = try allocator.dupe(u8, std.mem.trimRight(u8, chars, "\n"));
    defer allocator.free(nums);
    for (nums) |*num| {
        if (num.* != '\n') {
            num.* -= '0';
        }
    }
    var map = ArrayList([]const u8).init(allocator);
    defer map.deinit();
    var sp = std.mem.split(u8, nums, "\n");

    while (sp.next()) |line| {
        try map.append(line);
    }

    var mark = ArrayList([]bool).init(allocator);
    defer {
        for (mark.items) |item| {
            allocator.free(item);
        }

        mark.deinit();
    }

    var xlen = map.items[0].len;
    var ylen = map.items.len;
    print("xlen = {}, ylen = {}\n", .{ xlen, ylen });

    var t: usize = 0;
    while (t < ylen) : (t += 1) {
        try mark.append(try allocator.alloc(bool, map.items[0].len));
    }

    {
        var y = ylen;
        while (y > 0) : (y -= 1) {
            scan(map, mark, .E, xlen, ylen, 0, y - 1);
            scan(map, mark, .W, xlen, ylen, xlen - 1, y - 1);
        }
    }
    {
        var x = xlen;
        while (x > 0) : (x -= 1) {
            scan(map, mark, .S, xlen, ylen, x - 1, 0);
            scan(map, mark, .N, xlen, ylen, x - 1, ylen - 1);
        }
    }

    print("\n---dump---\n", .{});
    var cnt: usize = 0;
    for (mark.items) |item| {
        for (item) |i| {
            if (i) {
                print("O", .{});
                cnt += 1;
            } else {
                print(" ", .{});
            }
        }
        print(";\n", .{});
    }

    return cnt;
}

fn solve2(allocator: Allocator, chars: []const u8) !usize {
    var nums = try allocator.dupe(u8, std.mem.trimRight(u8, chars, "\n"));
    defer allocator.free(nums);
    for (nums) |*num| {
        if (num.* != '\n') {
            num.* -= '0';
        }
    }
    var map = ArrayList([]const u8).init(allocator);
    defer map.deinit();
    var sp = std.mem.split(u8, nums, "\n");

    while (sp.next()) |line| {
        try map.append(line);
    }

    var mark = ArrayList([]bool).init(allocator);
    defer {
        for (mark.items) |item| {
            allocator.free(item);
        }

        mark.deinit();
    }

    var xlen = map.items[0].len;
    var ylen = map.items.len;
    print("xlen = {}, ylen = {}\n", .{ xlen, ylen });

    var max_score: usize = 0;
    var startx: usize = 1;
    var starty: usize = 1;
    while (startx < xlen - 1) : ({
        startx += 1;
        starty = 1;
    }) {
        while (starty < ylen - 1) : (starty += 1) {
            var score1 = countTrees(map, .N, xlen, ylen, startx, starty);
            var score2 = countTrees(map, .E, xlen, ylen, startx, starty);
            var score3 = countTrees(map, .S, xlen, ylen, startx, starty);
            var score4 = countTrees(map, .W, xlen, ylen, startx, starty);
            var score = score1 * score2 * score3 * score4;
            print("x = {}, y = {} score = {}\n", .{ startx, starty, score });
            if (score > max_score) {
                max_score = score;
            }
        }
    }
    return max_score;
}

const test_case =
    \\30373
    \\25512
    \\65332
    \\33549
    \\35390
;

test "given testcase from aoc" {
    var p = try solve1(std.testing.allocator, test_case);
    print("p = {}\n", .{p});
    try expect(p == 21);
}

test "given testcase from aoc, part 2" {
    var p = try solve2(std.testing.allocator, test_case);
    print("p = {}\n", .{p});
    try expect(p == 8);
}
