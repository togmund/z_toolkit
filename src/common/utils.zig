const std = @import("std");
const Allocator = std.mem.Allocator;

/// Normalize whitespace in a string by replacing multiple whitespace chars with single spaces
pub fn normalizeWhitespace(allocator: Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    defer result.deinit(allocator);

    var in_whitespace = false;
    var start_trimmed = false;

    for (text) |char| {
        if (std.ascii.isWhitespace(char)) {
            if (!in_whitespace and start_trimmed) {
                try result.append(allocator, ' ');
                in_whitespace = true;
            }
        } else {
            try result.append(allocator, char);
            in_whitespace = false;
            start_trimmed = true;
        }
    }

    // Trim trailing space
    const slice = result.items;
    if (slice.len > 0 and slice[slice.len - 1] == ' ') {
        return allocator.dupe(u8, slice[0 .. slice.len - 1]);
    }

    return allocator.dupe(u8, slice);
}

/// Calculate Levenshtein distance between two strings
pub fn levenshteinDistance(allocator: Allocator, a: []const u8, b: []const u8) !usize {
    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;

    // Create matrix
    const rows = a.len + 1;
    const cols = b.len + 1;
    var matrix = try allocator.alloc([]usize, rows);
    defer allocator.free(matrix);

    for (0..rows) |i| {
        matrix[i] = try allocator.alloc(usize, cols);
        defer allocator.free(matrix[i]);
    }

    // Initialize first row and column
    for (0..rows) |i| {
        matrix[i][0] = i;
    }
    for (0..cols) |j| {
        matrix[0][j] = j;
    }

    // Fill matrix
    for (1..rows) |i| {
        for (1..cols) |j| {
            const cost: usize = if (a[i - 1] == b[j - 1]) 0 else 1;
            matrix[i][j] = @min(@min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1), matrix[i - 1][j - 1] + cost);
        }
    }

    return matrix[a.len][b.len];
}

/// Remove common leading indentation from a multi-line string
pub fn removeIndentation(allocator: Allocator, text: []const u8) ![]u8 {
    var lines = std.mem.splitSequence(u8, text, "\n");
    var line_list = std.ArrayList([]const u8){};
    defer line_list.deinit(allocator);

    // Collect all lines
    while (lines.next()) |line| {
        try line_list.append(allocator, line);
    }

    if (line_list.items.len == 0) return allocator.dupe(u8, text);

    // Find minimum indentation of non-empty lines
    var min_indent: ?usize = null;
    for (line_list.items) |line| {
        if (std.mem.trim(u8, line, " \t").len == 0) continue; // Skip empty lines

        var indent: usize = 0;
        for (line) |char| {
            if (char == ' ' or char == '\t') {
                indent += 1;
            } else {
                break;
            }
        }

        if (min_indent == null or indent < min_indent.?) {
            min_indent = indent;
        }
    }

    if (min_indent == null or min_indent.? == 0) {
        return allocator.dupe(u8, text);
    }

    // Build result without common indentation
    var result = std.ArrayList(u8){};
    defer result.deinit(allocator);

    for (line_list.items, 0..) |line, i| {
        if (i > 0) try result.append(allocator, '\n');

        if (std.mem.trim(u8, line, " \t").len == 0) {
            try result.appendSlice(allocator, line); // Keep empty lines as-is
        } else if (line.len > min_indent.?) {
            try result.appendSlice(allocator, line[min_indent.?..]);
        } else {
            try result.appendSlice(allocator, line);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Unescape common escape sequences in a string
pub fn unescapeString(allocator: Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    defer result.deinit(allocator);

    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '\\' and i + 1 < text.len) {
            switch (text[i + 1]) {
                'n' => try result.append(allocator, '\n'),
                't' => try result.append(allocator, '\t'),
                'r' => try result.append(allocator, '\r'),
                '\'' => try result.append(allocator, '\''),
                '"' => try result.append(allocator, '"'),
                '`' => try result.append(allocator, '`'),
                '\\' => try result.append(allocator, '\\'),
                '$' => try result.append(allocator, '$'),
                else => {
                    try result.append(allocator, text[i]);
                    try result.append(allocator, text[i + 1]);
                },
            }
            i += 2;
        } else {
            try result.append(allocator, text[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}
