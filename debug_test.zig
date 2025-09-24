const std = @import("std");
const edit = @import("src/edit.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test case 16: Should fail due to multiple matches
    const content16 = "test\ntest\ndifferent content\ntest";
    const old_string16 = "test";
    const new_string16 = "updated";
    const replace_all16 = false;

    std.debug.print("=== Testing Case 16 ===\n", .{});
    std.debug.print("Content: {s}\n", .{content16});
    std.debug.print("Find: {s}\n", .{old_string16});
    std.debug.print("Replace: {s}\n", .{new_string16});
    std.debug.print("ReplaceAll: {}\n", .{replace_all16});

    const result16 = edit.replace(allocator, content16, old_string16, new_string16, replace_all16);
    if (result16) |output| {
        std.debug.print("❌ UNEXPECTED SUCCESS: {s}\n", .{output});
        allocator.free(output);
    } else |err| {
        std.debug.print("✅ Expected failure: {}\n", .{err});
    }

    // Test case 41: Should fail due to multiple matches
    const content41 = "const a = 1;\nconst b = 1;\nconst c = 1;";
    const old_string41 = "= 1";
    const new_string41 = "= 2";
    const replace_all41 = false;

    std.debug.print("\n=== Testing Case 41 ===\n", .{});
    std.debug.print("Content: {s}\n", .{content41});
    std.debug.print("Find: {s}\n", .{old_string41});
    std.debug.print("Replace: {s}\n", .{new_string41});
    std.debug.print("ReplaceAll: {}\n", .{replace_all41});

    const result41 = edit.replace(allocator, content41, old_string41, new_string41, replace_all41);
    if (result41) |output| {
        std.debug.print("❌ UNEXPECTED SUCCESS: {s}\n", .{output});
        allocator.free(output);
    } else |err| {
        std.debug.print("✅ Expected failure: {}\n", .{err});
    }
}
