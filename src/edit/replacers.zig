const std = @import("std");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const utils = @import("../common/utils.zig");
const ReplacerResult = types.ReplacerResult;

const SINGLE_CANDIDATE_SIMILARITY_THRESHOLD = 0.0;
const MULTIPLE_CANDIDATES_SIMILARITY_THRESHOLD = 0.3;

/// Simple exact string matching replacer
pub fn simpleReplacer(allocator: Allocator, content: []const u8, find: []const u8) !ReplacerResult {
    var result = ReplacerResult.init(allocator);

    if (std.mem.indexOf(u8, content, find) != null) {
        try result.addMatch(find);
    }

    return result;
}

/// Line-by-line matching with trimming
pub fn lineTrimmedReplacer(allocator: Allocator, content: []const u8, find: []const u8) !ReplacerResult {
    var result = ReplacerResult.init(allocator);

    var content_lines = std.mem.splitSequence(u8, content, "\n");
    var content_line_list = std.ArrayList([]const u8){};
    defer content_line_list.deinit(allocator);

    // Collect content lines
    while (content_lines.next()) |line| {
        try content_line_list.append(allocator, line);
    }

    var find_lines = std.mem.splitSequence(u8, find, "\n");
    var find_line_list = std.ArrayList([]const u8){};
    defer find_line_list.deinit(allocator);

    // Collect find lines
    while (find_lines.next()) |line| {
        try find_line_list.append(allocator, line);
    }

    // Remove trailing empty line if present
    if (find_line_list.items.len > 0 and find_line_list.items[find_line_list.items.len - 1].len == 0) {
        _ = find_line_list.pop();
    }

    if (find_line_list.items.len == 0) return result;
    if (content_line_list.items.len < find_line_list.items.len) return result;

    // Search for matching blocks
    var i: usize = 0;
    while (i <= content_line_list.items.len - find_line_list.items.len) : (i += 1) {
        var matches = true;

        for (find_line_list.items, 0..) |find_line, j| {
            const content_trimmed = std.mem.trim(u8, content_line_list.items[i + j], " \t");
            const find_trimmed = std.mem.trim(u8, find_line, " \t");

            if (!std.mem.eql(u8, content_trimmed, find_trimmed)) {
                matches = false;
                break;
            }
        }

        if (matches) {
            // Calculate the exact substring match
            var match_start: usize = 0;
            var k: usize = 0;
            while (k < i) : (k += 1) {
                match_start += content_line_list.items[k].len + 1; // +1 for newline
            }

            var match_end = match_start;
            k = 0;
            while (k < find_line_list.items.len) : (k += 1) {
                match_end += content_line_list.items[i + k].len;
                if (k < find_line_list.items.len - 1) {
                    match_end += 1; // Add newline except for last line
                }
            }

            if (match_end <= content.len) {
                try result.addMatch(content[match_start..match_end]);
            }
        }
    }

    return result;
}

/// Whitespace-normalized matching
pub fn whitespaceNormalizedReplacer(allocator: Allocator, content: []const u8, find: []const u8) !ReplacerResult {
    var result = ReplacerResult.init(allocator);

    const normalized_find = try utils.normalizeWhitespace(allocator, find);
    defer allocator.free(normalized_find);

    // Single line matches
    var content_lines = std.mem.splitSequence(u8, content, "\n");
    var line_start: usize = 0;

    while (content_lines.next()) |line| {
        defer line_start += line.len + 1;

        const normalized_line = try utils.normalizeWhitespace(allocator, line);
        defer allocator.free(normalized_line);

        if (std.mem.eql(u8, normalized_line, normalized_find)) {
            try result.addMatch(line);
        } else if (std.mem.indexOf(u8, normalized_line, normalized_find) != null) {
            // Try to find the actual substring that matches
            var words = std.mem.splitSequence(u8, std.mem.trim(u8, find, " \t"), " ");
            var word_list = std.ArrayList([]const u8){};
            defer word_list.deinit(allocator);

            while (words.next()) |word| {
                if (word.len > 0) {
                    try word_list.append(allocator, word);
                }
            }

            if (word_list.items.len > 0) {
                // Simple approximation: look for the first word and match from there
                if (std.mem.indexOf(u8, line, word_list.items[0])) |start_pos| {
                    // Find a reasonable end position
                    const last_word = word_list.items[word_list.items.len - 1];
                    if (std.mem.indexOf(u8, line[start_pos..], last_word)) |relative_end| {
                        const end_pos = start_pos + relative_end + last_word.len;
                        if (end_pos <= line.len) {
                            try result.addMatch(line[start_pos..end_pos]);
                        }
                    }
                }
            }
        }
    }

    // Multi-line matches
    var find_lines = std.mem.splitSequence(u8, find, "\n");
    var find_line_list = std.ArrayList([]const u8){};
    defer find_line_list.deinit(allocator);

    while (find_lines.next()) |line| {
        try find_line_list.append(allocator, line);
    }

    if (find_line_list.items.len > 1) {
        content_lines = std.mem.splitSequence(u8, content, "\n");
        var content_line_list = std.ArrayList([]const u8){};
        defer content_line_list.deinit(allocator);

        while (content_lines.next()) |line| {
            try content_line_list.append(allocator, line);
        }

        var i: usize = 0;
        while (i <= content_line_list.items.len - find_line_list.items.len) : (i += 1) {
            var block_lines = std.ArrayList([]const u8){};
            defer block_lines.deinit(allocator);

            var j: usize = 0;
            while (j < find_line_list.items.len) : (j += 1) {
                try block_lines.append(allocator, content_line_list.items[i + j]);
            }

            const block = try std.mem.join(allocator, "\n", block_lines.items);
            defer allocator.free(block);

            const normalized_block = try utils.normalizeWhitespace(allocator, block);
            defer allocator.free(normalized_block);

            if (std.mem.eql(u8, normalized_block, normalized_find)) {
                try result.addMatch(block);
            }
        }
    }

    return result;
}

/// Indentation-flexible matching
pub fn indentationFlexibleReplacer(allocator: Allocator, content: []const u8, find: []const u8) !ReplacerResult {
    var result = ReplacerResult.init(allocator);

    const normalized_find = try utils.removeIndentation(allocator, find);
    defer allocator.free(normalized_find);

    var content_lines = std.mem.splitSequence(u8, content, "\n");
    var content_line_list = std.ArrayList([]const u8){};
    defer content_line_list.deinit(allocator);

    while (content_lines.next()) |line| {
        try content_line_list.append(allocator, line);
    }

    var find_lines = std.mem.splitSequence(u8, find, "\n");
    var find_line_list = std.ArrayList([]const u8){};
    defer find_line_list.deinit(allocator);

    while (find_lines.next()) |line| {
        try find_line_list.append(allocator, line);
    }

    if (find_line_list.items.len == 0) return result;
    if (content_line_list.items.len < find_line_list.items.len) return result;

    var i: usize = 0;
    while (i <= content_line_list.items.len - find_line_list.items.len) : (i += 1) {
        var block_lines = std.ArrayList([]const u8){};
        defer block_lines.deinit(allocator);

        var j: usize = 0;
        while (j < find_line_list.items.len) : (j += 1) {
            try block_lines.append(allocator, content_line_list.items[i + j]);
        }

        const block = try std.mem.join(allocator, "\n", block_lines.items);
        defer allocator.free(block);

        const normalized_block = try utils.removeIndentation(allocator, block);
        defer allocator.free(normalized_block);

        if (std.mem.eql(u8, normalized_block, normalized_find)) {
            try result.addMatch(block);
        }
    }

    return result;
}

/// Escape-normalized matching
pub fn escapeNormalizedReplacer(allocator: Allocator, content: []const u8, find: []const u8) !ReplacerResult {
    var result = ReplacerResult.init(allocator);

    const unescaped_find = try utils.unescapeString(allocator, find);
    defer allocator.free(unescaped_find);

    // Try direct match with unescaped find string
    if (std.mem.indexOf(u8, content, unescaped_find) != null) {
        try result.addMatch(unescaped_find);
    }

    // Also try finding escaped versions in content that match unescaped find
    var content_lines = std.mem.splitSequence(u8, content, "\n");
    var content_line_list = std.ArrayList([]const u8){};
    defer content_line_list.deinit(allocator);

    while (content_lines.next()) |line| {
        try content_line_list.append(allocator, line);
    }

    var find_lines = std.mem.splitSequence(u8, unescaped_find, "\n");
    var find_line_list = std.ArrayList([]const u8){};
    defer find_line_list.deinit(allocator);

    while (find_lines.next()) |line| {
        try find_line_list.append(allocator, line);
    }

    if (find_line_list.items.len == 0) return result;
    if (content_line_list.items.len < find_line_list.items.len) return result;

    var i: usize = 0;
    while (i <= content_line_list.items.len - find_line_list.items.len) : (i += 1) {
        var block_lines = std.ArrayList([]const u8){};
        defer block_lines.deinit(allocator);

        var j: usize = 0;
        while (j < find_line_list.items.len) : (j += 1) {
            try block_lines.append(allocator, content_line_list.items[i + j]);
        }

        const block = try std.mem.join(allocator, "\n", block_lines.items);
        defer allocator.free(block);

        const unescaped_block = try utils.unescapeString(allocator, block);
        defer allocator.free(unescaped_block);

        if (std.mem.eql(u8, unescaped_block, unescaped_find)) {
            try result.addMatch(block);
        }
    }

    return result;
}

/// Block anchor matching with similarity thresholds
pub fn blockAnchorReplacer(allocator: Allocator, content: []const u8, find: []const u8) !ReplacerResult {
    var result = ReplacerResult.init(allocator);

    var content_lines = std.mem.splitSequence(u8, content, "\n");
    var content_line_list = std.ArrayList([]const u8){};
    defer content_line_list.deinit(allocator);

    while (content_lines.next()) |line| {
        try content_line_list.append(allocator, line);
    }

    var find_lines = std.mem.splitSequence(u8, find, "\n");
    var find_line_list = std.ArrayList([]const u8){};
    defer find_line_list.deinit(allocator);

    while (find_lines.next()) |line| {
        try find_line_list.append(allocator, line);
    }

    // Remove trailing empty line if present
    if (find_line_list.items.len > 0 and find_line_list.items[find_line_list.items.len - 1].len == 0) {
        _ = find_line_list.pop();
    }

    if (find_line_list.items.len < 3) return result; // Need at least 3 lines

    const first_line_search = std.mem.trim(u8, find_line_list.items[0], " \t");
    const last_line_search = std.mem.trim(u8, find_line_list.items[find_line_list.items.len - 1], " \t");

    // Collect candidates
    var candidates = std.ArrayList(struct { start_line: usize, end_line: usize }){};
    defer candidates.deinit(allocator);

    for (content_line_list.items, 0..) |line, i| {
        const trimmed_line = std.mem.trim(u8, line, " \t");
        if (!std.mem.eql(u8, trimmed_line, first_line_search)) continue;

        // Look for matching last line
        var j = i + 2;
        while (j < content_line_list.items.len) : (j += 1) {
            const trimmed_end = std.mem.trim(u8, content_line_list.items[j], " \t");
            if (std.mem.eql(u8, trimmed_end, last_line_search)) {
                try candidates.append(allocator, .{ .start_line = i, .end_line = j });
                break;
            }
        }
    }

    if (candidates.items.len == 0) return result;

    if (candidates.items.len == 1) {
        // Single candidate with relaxed threshold
        const candidate = candidates.items[0];
        const actual_block_size = candidate.end_line - candidate.start_line + 1;
        const search_block_size = find_line_list.items.len;

        var similarity: f64 = 0.0;
        const lines_to_check = @min(search_block_size - 2, actual_block_size - 2);

        if (lines_to_check > 0) {
            var matching_score: f64 = 0.0;

            var j: usize = 1;
            while (j < search_block_size - 1 and j < actual_block_size - 1) : (j += 1) {
                const original_line = std.mem.trim(u8, content_line_list.items[candidate.start_line + j], " \t");
                const search_line = std.mem.trim(u8, find_line_list.items[j], " \t");
                const max_len = @max(original_line.len, search_line.len);

                if (max_len == 0) continue;

                const distance = try utils.levenshteinDistance(allocator, original_line, search_line);
                const line_similarity = 1.0 - (@as(f64, @floatFromInt(distance)) / @as(f64, @floatFromInt(max_len)));
                matching_score += line_similarity;
            }

            similarity = matching_score / @as(f64, @floatFromInt(lines_to_check));
        } else {
            similarity = 1.0; // No middle lines to compare
        }

        if (similarity >= SINGLE_CANDIDATE_SIMILARITY_THRESHOLD) {
            // Calculate match indices
            var match_start: usize = 0;
            var k: usize = 0;
            while (k < candidate.start_line) : (k += 1) {
                match_start += content_line_list.items[k].len + 1;
            }

            var match_end = match_start;
            k = candidate.start_line;
            while (k <= candidate.end_line) : (k += 1) {
                match_end += content_line_list.items[k].len;
                if (k < candidate.end_line) {
                    match_end += 1;
                }
            }

            if (match_end <= content.len) {
                try result.addMatch(content[match_start..match_end]);
            }
        }
    } else {
        // Multiple candidates - find best match
        var best_match: ?usize = null;
        var max_similarity: f64 = -1.0;

        for (candidates.items, 0..) |candidate, idx| {
            const actual_block_size = candidate.end_line - candidate.start_line + 1;
            const search_block_size = find_line_list.items.len;

            var similarity: f64 = 0.0;
            const lines_to_check = @min(search_block_size - 2, actual_block_size - 2);

            if (lines_to_check > 0) {
                var matching_score: f64 = 0.0;

                var j: usize = 1;
                while (j < search_block_size - 1 and j < actual_block_size - 1) : (j += 1) {
                    const original_line = std.mem.trim(u8, content_line_list.items[candidate.start_line + j], " \t");
                    const search_line = std.mem.trim(u8, find_line_list.items[j], " \t");
                    const max_len = @max(original_line.len, search_line.len);

                    if (max_len == 0) continue;

                    const distance = try utils.levenshteinDistance(allocator, original_line, search_line);
                    const line_similarity = 1.0 - (@as(f64, @floatFromInt(distance)) / @as(f64, @floatFromInt(max_len)));
                    matching_score += line_similarity;
                }

                similarity = matching_score / @as(f64, @floatFromInt(lines_to_check));
            } else {
                similarity = 1.0;
            }

            if (similarity > max_similarity) {
                max_similarity = similarity;
                best_match = idx;
            }
        }

        if (max_similarity >= MULTIPLE_CANDIDATES_SIMILARITY_THRESHOLD and best_match != null) {
            const candidate = candidates.items[best_match.?];

            // Calculate match indices
            var match_start: usize = 0;
            var k: usize = 0;
            while (k < candidate.start_line) : (k += 1) {
                match_start += content_line_list.items[k].len + 1;
            }

            var match_end = match_start;
            k = candidate.start_line;
            while (k <= candidate.end_line) : (k += 1) {
                match_end += content_line_list.items[k].len;
                if (k < candidate.end_line) {
                    match_end += 1;
                }
            }

            if (match_end <= content.len) {
                try result.addMatch(content[match_start..match_end]);
            }
        }
    }

    return result;
}
