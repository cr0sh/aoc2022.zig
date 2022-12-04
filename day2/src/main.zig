const std = @import("std");
const common = @import("common");

const GameResult = enum {
    win,
    draw,
    lose,
    fn score(self: GameResult) u64 {
        switch (self) {
            GameResult.win => return 6,
            GameResult.draw => return 3,
            GameResult.lose => return 0,
        }
    }

    fn fromMyString(x: []const u8) !GameResult {
        if (x.len != 1) {
            return error.InvalidLength;
        }

        return switch (x[0]) {
            'X' => GameResult.lose,
            'Y' => GameResult.draw,
            'Z' => GameResult.win,
            else => error.InvalidIdentifier,
        };
    }
};

const Shape = enum(u64) {
    rock = 0,
    paper = 1,
    scissor = 2,

    fn match(my: Shape, opponent: Shape) GameResult {
        return switch ((3 + @enumToInt(my) - @enumToInt(opponent)) % 3) {
            0 => GameResult.draw,
            1 => GameResult.win,
            2 => GameResult.lose,
            else => unreachable,
        };
    }

    fn myScore(self: Shape) u64 {
        return switch (self) {
            Shape.rock => 1,
            Shape.paper => 2,
            Shape.scissor => 3,
        };
    }

    fn fromOpponentString(x: []const u8) !Shape {
        if (x.len != 1) {
            return error.InvalidLength;
        }

        return switch (x[0]) {
            'A' => Shape.rock,
            'B' => Shape.paper,
            'C' => Shape.scissor,
            else => error.InvalidIdentifier,
        };
    }

    fn fromMyString(x: []const u8) !Shape {
        if (x.len != 1) {
            return error.InvalidLength;
        }

        return switch (x[0]) {
            'X' => Shape.rock,
            'Y' => Shape.paper,
            'Z' => Shape.scissor,
            else => error.InvalidIdentifier,
        };
    }

    fn findMyShape(self: Shape, result: GameResult) Shape {
        if (Shape.match(Shape.rock, self) == result) return Shape.rock;
        if (Shape.match(Shape.paper, self) == result) return Shape.paper;
        if (Shape.match(Shape.scissor, self) == result) return Shape.scissor;
        @panic("no matches");
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    var stage = try common.parseStageFromCli();

    var stdin = std.io.getStdIn().reader();
    var score: u64 = 0;

    while (true) {
        var s = stdin.readUntilDelimiterAlloc(alloc, '\n', 1024) catch |err| {
            if (err == error.EndOfStream) {
                break;
            } else {
                return err;
            }
        };

        var strim = std.mem.trim(u8, s, "\n\r");
        if (std.mem.eql(u8, strim, "")) {
            break;
        }

        var it = std.mem.split(u8, strim, " ");
        var op = try Shape.fromOpponentString(it.next() orelse return error.UnexpectedEndOfLine);
        switch (stage) {
            1 => {
                var my = try Shape.fromMyString(it.next() orelse return error.UnexpectedEndOfLine);
                std.debug.print("op={}, my={}, myscore={} gamescore={}\n", .{ op, my, my.myScore(), Shape.match(my, op).score() });
                score += my.myScore() + Shape.match(my, op).score();
            },
            2 => {
                var game_res = try GameResult.fromMyString(it.next() orelse return error.UnexpectedEndOfLine);
                var my = op.findMyShape(game_res);
                std.debug.print("op={}, my={}, game={}, myscore={} gamescore={}\n", .{ op, my, game_res, my.myScore(), Shape.match(my, op).score() });
                score += my.myScore() + Shape.match(my, op).score();
            },
            else => std.debug.panic("unable to handle stage {}", .{stage}),
        }
    }

    std.debug.print("{}\n", .{score});
}
