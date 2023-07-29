const std = @import("std");

const Self = @This();
pub const Error = error{OutOfMemory};

// Stored GPA, used for allocations internally
inner_gpa: std.heap.GeneralPurposeAllocator(.{}),

pub fn init() Self {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    return Self{
        .inner_gpa = gpa,
    };
}

pub fn deinit(self: *Self) std.heap.Check {
    return self.inner_gpa.deinit();
}

pub fn allocator(self: *Self) std.mem.Allocator {
    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = alloc,
            .free = free,
            .resize = resize,
        },
    };
}

fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.inner_gpa.allocator().rawAlloc(len, ptr_align, ret_addr);
}

fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.inner_gpa.allocator().rawResize(buf, buf_align, new_len, ret_addr);
}

fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.inner_gpa.allocator().rawFree(buf, buf_align, ret_addr);
}

test "can allocate and deallocate a small object" {
    var gca = init();
    defer std.testing.expect(gca.deinit() == std.heap.Check.ok) catch @panic("leak");
    const allocator_ = gca.allocator();

    const T = struct { a: u32 };
    var memory = try allocator_.create(T);
    memory.* = T{ .a = 10 };
    allocator_.destroy(memory);
}
