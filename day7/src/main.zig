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

const File = struct {
    size: ?u64 = null,
};

const Directory = struct {
    const Self = @This();

    allocator: Allocator,
    items: ArrayList(Node),
    parent: ?*Directory,

    fn init(allocator: Allocator, parent: ?*Directory) Self {
        return .{ .allocator = allocator, .items = ArrayList(Node).init(allocator), .parent = parent };
    }

    fn deinit(self: Self) void {
        for (self.items.items) |item| {
            switch (item.kind) {
                .File => {},
                .Directory => |dir| dir.deinit(),
            }
        }
        self.items.deinit();
    }

    fn entry(self: *Self, name: []const u8) error{NotFound}!*Node {
        for (self.items.items) |*item| {
            if (std.mem.eql(u8, item.name, name)) {
                return item;
            }
        }

        return error.NotFound;
    }

    fn createFile(self: *Self, name: []const u8) !void {
        if (self.entry(name) != error.NotFound) {
            return error.AlreadyExists;
        }

        try self.items.append(Node.init(name, .{ .File = .{} }));
    }

    fn createDirectory(self: *Self, name: []const u8) !void {
        if (self.entry(name) != error.NotFound) {
            return error.AlreadyExists;
        }

        try self.items.append(Node.init(name, .{ .Directory = Self.init(self.allocator, self) }));
    }

    fn sumlessThan(self: *const Self, threshold: u64) u64 {
        var sum: u64 = 0;
        var mysum: u64 = 0;
        for (self.items.items) |item| {
            switch (item.kind) {
                NodeKind.File => |file| {
                    print("{s} is file\n", .{item.name});
                    mysum += file.size orelse @panic("uninitialized file");
                },
                NodeKind.Directory => |dir| {
                    print("> {s} is dir\n", .{item.name});
                    sum += dir.sumlessThan(threshold);
                    mysum += item.size();
                    print("< left {s}\n", .{item.name});
                },
            }
        }

        print("mysum = {}\n", .{mysum});
        if (mysum <= threshold) {
            sum += mysum;
        }

        return sum;
    }

    fn dirSizes(self: *const Self, sizes: *ArrayList(u64)) !u64 {
        var sum: u64 = 0;

        for (self.items.items) |item| {
            switch (item.kind) {
                NodeKind.File => |file| {
                    sum += file.size orelse @panic("uninitialized file");
                },
                NodeKind.Directory => |dir| {
                    sum += try dir.dirSizes(sizes);
                },
            }
        }

        try sizes.append(sum);
        return sum;
    }
};

const NodeKindTag = enum { File, Directory };

const NodeKind = union(NodeKindTag) {
    File: File,
    Directory: Directory,
};

const Node = struct {
    const Self = @This();

    name: []const u8,
    kind: NodeKind,

    fn init(name: []const u8, kind: NodeKind) Self {
        return .{ .name = name, .kind = kind };
    }

    fn size(self: *const Self) u64 {
        switch (self.kind) {
            NodeKind.File => |file| return file.size orelse @panic("uninitialized file"),
            NodeKind.Directory => |dir| {
                var s: u64 = 0;
                for (dir.items.items) |n| {
                    s += n.size();
                }
                return s;
            },
        }
    }

    fn dump(self: *const Self, level: usize) void {
        switch (self.kind) {
            NodeKind.File => |file| {
                print("{s}{s}: file, {?} bytes\n", .{ "                          "[0 .. level * 2], self.name, file.size });
            },
            NodeKind.Directory => |dir| {
                print("{s}{s}: directory\n", .{ "                          "[0 .. level * 2], self.name });
                for (dir.items.items) |item| {
                    item.dump(level + 1);
                }
            },
        }
    }
};

const Parser = struct {
    const Self = @This();

    allocator: Allocator,
    root: *Directory,
    cwd: *Directory,

    fn init(allocator: Allocator) !Self {
        var root = try allocator.create(Directory);
        root.* = Directory.init(allocator, null);
        root.parent = root;

        return .{ .allocator = allocator, .root = root, .cwd = root };
    }

    fn deinit(self: Self) void {
        self.root.deinit();
        self.allocator.destroy(self.root);
    }

    fn feedLine(self: *Self, line: []const u8) !void {
        if (line[0] == '$') {
            if (std.mem.eql(u8, line[2..4], "cd")) {
                try self.cd(line[5..]);
            }
        } else {
            try self.feedLsOutput(line);
        }
    }

    fn cd(self: *Self, dirname: []const u8) !void {
        print("cd {s}\n", .{dirname});
        if (std.mem.eql(u8, dirname, "..")) {
            self.cwd = self.cwd.parent orelse @panic("directory parent is null");
        } else if (std.mem.eql(u8, dirname, "/")) {
            self.cwd = self.root;
        } else {
            var n = try self.cwd.entry(dirname);
            switch (n.kind) {
                NodeKind.Directory => |*dir| {
                    self.cwd = dir;
                },
                else => return error.NodeNotDirectory,
            }
        }
    }

    fn feedLsOutput(self: *Self, str: []const u8) !void {
        var sp = std.mem.split(u8, str, " ");
        var size_str = sp.next() orelse return error.UnexpectedEndOfLine;
        var name = sp.next() orelse return error.UnexpectedEndOfLine;
        if (std.mem.eql(u8, size_str, "dir")) {
            if (self.cwd.entry(name) == error.NotFound) {
                print("create directory with name {s}\n", .{name});
                try self.cwd.createDirectory(name);
            }
        } else {
            var size = try std.fmt.parseUnsigned(u64, size_str, 10);
            if (self.cwd.entry(name) == error.NotFound) {
                print("create file with name {s}\n", .{name});
                try self.cwd.createFile(name);
            }
            var entry = self.cwd.entry(name) catch unreachable;
            switch (entry.kind) {
                NodeKind.Directory => return error.ExpectedFile,
                NodeKind.File => |*file| {
                    file.size = size;
                },
            }
        }
    }
};

fn solve1(allocator: Allocator, chars: []const u8) !usize {
    var tr = std.mem.trimRight(u8, chars, "\n");
    var lines = std.mem.split(u8, tr, "\n");
    var parser = try Parser.init(allocator);
    defer parser.deinit();

    while (lines.next()) |line| {
        try parser.feedLine(line);
    }

    for (parser.root.items.items) |item| {
        item.dump(0);
    }

    return parser.root.sumlessThan(100000);
}

fn solve2(allocator: Allocator, chars: []const u8) !usize {
    var tr = std.mem.trimRight(u8, chars, "\n");
    var lines = std.mem.split(u8, tr, "\n");
    var parser = try Parser.init(allocator);
    defer parser.deinit();

    while (lines.next()) |line| {
        try parser.feedLine(line);
    }

    var size_left: u64 = 70000000;
    for (parser.root.items.items) |item| {
        size_left -= item.size();
    }

    var need_size: u64 = 30000000 - size_left;
    print("need_size = {}\n", .{need_size});

    var arr = ArrayList(u64).init(allocator);
    defer arr.deinit();

    _ = try parser.root.dirSizes(&arr);
    std.sort.sort(u64, arr.items, {}, std.sort.asc(u64));

    var i: usize = 0;
    while (arr.items[i] < need_size)
        i += 1;
    return arr.items[i];
}

const test_case =
    \\$ cd /
    \\$ ls
    \\dir a
    \\14848514 b.txt
    \\8504156 c.dat
    \\dir d
    \\$ cd a
    \\$ ls
    \\dir e
    \\29116 f
    \\2557 g
    \\62596 h.lst
    \\$ cd e
    \\$ ls
    \\584 i
    \\$ cd ..
    \\$ cd ..
    \\$ cd d
    \\$ ls
    \\4060174 j
    \\8033020 d.log
    \\5626152 d.ext
    \\7214296 k
;

test "given testcase from aoc" {
    var p = try solve1(std.testing.allocator, test_case);
    print("p = {}\n", .{p});
    assert(p == 95437);
}

test "given testcase from aoc, part 2" {
    var p = try solve2(std.testing.allocator, test_case);
    print("p = {}\n", .{p});
    assert(p == 24933642);
}
