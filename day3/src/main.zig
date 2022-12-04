const std = @import("std");
const common = @import("common");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const assert = std.debug.assert;
const print = std.debug.print;

const Item = packed struct {
    char: u8,
    fn init(alphabet: u8) Item {
        return Item{
            .char = alphabet,
        };
    }

    fn priority(self: Item) !u8 {
        return switch (self.char) {
            'a'...'z' => 1 + self.char - 'a',
            'A'...'Z' => 27 + self.char - 'A',
            else => error.InvalidCharacter,
        };
    }
};

/// Returns two splitted slices of items with equal length.
/// Asserts that items.len is even.
pub fn splitItems(items: []const Item) struct { first: []const Item, second: []const Item } {
    print("items = {s}, len = {}\n", .{ @ptrCast([]const u8, items), items.len });
    assert(items.len % 2 == 0);

    return .{ .first = items[0 .. items.len / 2], .second = items[items.len / 2 .. items.len] };
}

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

fn common_items(allocator: Allocator, sack1: []const Item, sack2: []const Item) !ArrayList(Item) {
    var sack1set = std.hash_map.AutoHashMap(Item, void).init(allocator);
    defer sack1set.deinit();
    var sack2set = std.hash_map.AutoHashMap(Item, void).init(allocator);
    defer sack2set.deinit();

    var arr = ArrayList(Item).init(allocator);

    for (sack1) |item1| {
        try sack1set.put(item1, {});
    }

    for (sack2) |item1| {
        try sack2set.put(item1, {});
    }

    var keys = sack1set.keyIterator();
    while (keys.next()) |key| {
        if (sack2set.contains(key.*)) try arr.append(key.*);
    }

    return arr;
}

fn solve1(allocator: Allocator, chars: []const u8) !u64 {
    var p: u64 = 0;
    var split = std.mem.split(u8, chars, "\n");

    while (split.next()) |s| {
        var pair = splitItems(@ptrCast([]const Item, std.mem.trim(u8, s, "\n")));
        var commons = try common_items(allocator, pair.first, pair.second);
        defer commons.deinit();
        for (commons.items) |comm| {
            print("comm: {c}\n", .{comm.char});
            p += try comm.priority();
        }
    }

    return p;
}

fn solve2(allocator: Allocator, chars: []const u8) !u64 {
    var p: u64 = 0;
    var split = std.mem.split(u8, chars, "\n");

    var i: u64 = 0;
    var sacks = [3]?[]const Item{ null, null, null };
    while (split.next()) |s| {
        sacks[i] = @ptrCast([]const Item, std.mem.trim(u8, s, "\n"));
        i += 1;

        if (i == 3) {
            i = 0;
            var commons1 = try common_items(allocator, sacks[0] orelse unreachable, sacks[1] orelse unreachable);
            defer commons1.deinit();
            var commons2 = try common_items(allocator, commons1.items, sacks[2] orelse unreachable);
            defer commons2.deinit();
            for (commons2.items) |comm| {
                print("comm: {c}\n", .{comm.char});
                p += try comm.priority();
            }
        }
    }

    return p;
}

test "given testcase from aoc" {
    var chars =
        \\vJrwpWtwJgWrhcsFMMfFFhFp
        \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
        \\PmmdzqPrVvPwwTWBwg
        \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
        \\ttgJtRGJQctTZtZT
        \\CrZsJsPPZsGzwwsLwLmpwMDw
    ;

    var p = try solve1(std.testing.allocator, chars);

    print("p = {}\n", .{p});
    assert(p == 157);
}

test "given testcase from aoc, part 2" {
    var chars =
        \\vJrwpWtwJgWrhcsFMMfFFhFp
        \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
        \\PmmdzqPrVvPwwTWBwg
        \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
        \\ttgJtRGJQctTZtZT
        \\CrZsJsPPZsGzwwsLwLmpwMDw
    ;

    var p = try solve2(std.testing.allocator, chars);

    print("p = {}\n", .{p});
    assert(p == 70);
}
