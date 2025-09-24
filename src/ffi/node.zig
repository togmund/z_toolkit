const std = @import("std");

// Export C-compatible functions for Node.js FFI
extern "c" fn malloc(size: usize) ?*anyopaque;
extern "c" fn free(ptr: ?*anyopaque) void;

// C-compatible string structure
pub const CString = extern struct {
    data: [*:0]u8,
    len: usize,

    pub fn fromSlice(slice: []const u8) !CString {
        const ptr = malloc(slice.len + 1) orelse return error.OutOfMemory;
        const data: [*:0]u8 = @ptrCast(ptr);
        @memcpy(data[0..slice.len], slice);
        data[slice.len] = 0;
        return CString{
            .data = data,
            .len = slice.len,
        };
    }

    pub fn deinit(self: CString) void {
        free(self.data);
    }
};

// Error codes for C FFI
pub const ErrorCode = enum(c_int) {
    Success = 0,
    InvalidInput = 1,
    MultipleMatches = 2,
    OutOfMemory = 3,
    StringNotFound = 4,
};

// Result structure for C FFI
pub const EditResult = extern struct {
    data: ?[*:0]u8,
    len: usize,
    error_code: ErrorCode,

    pub fn success(content: []const u8) !EditResult {
        const c_str = try CString.fromSlice(content);
        return EditResult{
            .data = c_str.data,
            .len = c_str.len,
            .error_code = .Success,
        };
    }

    pub fn err(code: ErrorCode) EditResult {
        return EditResult{
            .data = null,
            .len = 0,
            .error_code = code,
        };
    }
};
