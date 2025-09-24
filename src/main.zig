const std = @import("std");
const edit = @import("edit.zig");

// Export the main replace function for C FFI
export fn replace(content_ptr: [*:0]const u8, old_ptr: [*:0]const u8, new_ptr: [*:0]const u8, replace_all: bool) ?[*:0]u8 {
    const allocator = std.heap.c_allocator;

    const content = std.mem.span(content_ptr);
    const old = std.mem.span(old_ptr);
    const new = std.mem.span(new_ptr);

    const result = edit.replace(allocator, content, old, new, replace_all) catch {
        // Handle errors by returning null
        return null;
    };

    // Convert to null-terminated string for C FFI
    const c_str = allocator.dupeZ(u8, result) catch return null;
    allocator.free(result);

    return c_str.ptr;
}

// Free function for C FFI
export fn free_string(ptr: ?[*:0]u8) void {
    if (ptr) |p| {
        std.heap.c_allocator.free(std.mem.span(p));
    }
}

// JSON input structure for OpenCode integration
const EditRequest = struct {
    content: []const u8,
    oldString: []const u8,
    newString: []const u8,
    replaceAll: bool,
};

// Main entry point that can handle both CLI and JSON input
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read from stdin if available, otherwise run simple test
    const stdin_file = std.fs.File{ .handle = std.posix.STDIN_FILENO };

    // Try to read JSON input
    const input = stdin_file.readToEndAlloc(allocator, 1024 * 1024) catch {
        // No input, run simple test
        return runSimpleTest(allocator);
    };
    defer allocator.free(input);

    if (input.len == 0) {
        return runSimpleTest(allocator);
    }

    // Parse JSON input
    var parsed = std.json.parseFromSlice(EditRequest, allocator, input, .{}) catch {
        std.debug.print("Error: Invalid JSON input\n", .{});
        return;
    };
    defer parsed.deinit();

    const request = parsed.value;

    // Perform the replacement
    const result = edit.replace(allocator, request.content, request.oldString, request.newString, request.replaceAll) catch |err| {
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
    defer allocator.free(result);

    // Output the result to stdout
    const stdout_file = std.fs.File{ .handle = std.posix.STDOUT_FILENO };
    _ = try stdout_file.writeAll(result);
}

fn runSimpleTest(allocator: std.mem.Allocator) !void {
    // Simple test
    const content = "hello world";
    const old = "world";
    const new = "universe";

    const result = try edit.replace(allocator, content, old, new, false);
    defer allocator.free(result);

    std.debug.print("Original: {s}\n", .{content});
    std.debug.print("Result: {s}\n", .{result});
}
