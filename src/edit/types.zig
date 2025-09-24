const std = @import("std");

pub const ReplacerResult = struct {
    matches: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ReplacerResult {
        return ReplacerResult{
            .matches = std.ArrayList([]const u8){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ReplacerResult) void {
        for (self.matches.items) |match| {
            self.allocator.free(match);
        }
        self.matches.deinit(self.allocator);
    }

    pub fn addMatch(self: *ReplacerResult, match: []const u8) !void {
        const owned = try self.allocator.dupe(u8, match);
        try self.matches.append(self.allocator, owned);
    }
};

pub const EditOptions = struct {
    replace_all: bool = false,
};

pub const MatchContext = struct {
    start_index: usize,
    end_index: usize,
    content: []const u8,
    similarity: f64 = 1.0,
};
