const std = @import("std");

pub const EditError = error{
    InvalidInput,
    MultipleMatches,
    OutOfMemory,
    StringNotFound,
};

pub fn errorToString(err: EditError) []const u8 {
    return switch (err) {
        EditError.InvalidInput => "Invalid input provided",
        EditError.MultipleMatches => "Multiple matches found, more context needed",
        EditError.OutOfMemory => "Out of memory",
        EditError.StringNotFound => "String not found in content",
    };
}
