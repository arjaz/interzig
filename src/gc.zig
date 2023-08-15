const std = @import("std");
const VirtualMachine = @import("main.zig").VirtualMachine;
const Value = @import("main.zig").Value;
const Object = @import("main.zig").Object;
const CallFrame = @import("main.zig").CallFrame;
const GlobalsHashMap = @import("main.zig").GlobalsHashMap;

pub const GarbageCollectorOptions = struct {
    stress: bool = false,
    debug: bool = false,
};

pub fn GarbageCollector(comptime options: GarbageCollectorOptions) type {
    return struct {
        const Self = @This();
        pub const Error = error{OutOfMemory};

        // Stored GPA, used for allocations internally, TODO: make in configurable
        inner_gpa: std.heap.GeneralPurposeAllocator(.{}),

        // Pointers into the VM's tracked fields
        stack: ?*std.ArrayList(Value) = null,
        frames: ?*std.ArrayList(CallFrame) = null,
        upvalues: ?*std.SinglyLinkedList(*Object) = null,
        objects: ?*std.ArrayList(*Object) = null,
        constants: ?*std.ArrayList(Value) = null,
        globals: ?*GlobalsHashMap = null,

        pub fn link(self: *Self, vm: *VirtualMachine) void {
            self.stack = &vm.stack;
            self.frames = &vm.frames;
            self.upvalues = &vm.upvalues;
            self.objects = &vm.objects;
            self.constants = &vm.constants;
            self.globals = &vm.globals;
        }

        fn collectGarbage(self: *Self) void {
            if (options.debug) {
                std.debug.print("-- gc begin\n", .{});
            }

            self.markRoots();

            if (options.debug) {
                std.debug.print("-- gc end\n", .{});
            }
        }

        /// The following objects are accessible:
        /// * the stack values
        /// * the closures/functions of the call frames
        /// * the current upvalues
        /// * the globals
        /// * the constants
        fn markRoots(self: *Self) void {
            std.debug.assert(self.stack != null);
            std.debug.assert(self.frames != null);
            std.debug.assert(self.upvalues != null);
            std.debug.assert(self.objects != null);
            std.debug.assert(self.constants != null);
            std.debug.assert(self.globals != null);

            for (self.stack.?.items) |v| {
                self.markValue(v);
            }
            for (self.constants.?.items) |c| {
                self.markValue(c);
            }
            for (self.frames.?.items) |frame| {
                self.markObject(frame.function);
            }
            var globals_iterator = self.globals.?.iterator();
            while (globals_iterator.next()) |global| {
                self.markObject(global.key_ptr.*);
                self.markValue(global.value_ptr.*);
            }
            var upvalues_iterator = self.upvalues.?.first;
            while (upvalues_iterator) |upvalue| : (upvalues_iterator = upvalue.next) {
                self.markObject(upvalue.data);
            }
        }

        fn markObject(self: *Self, object: ?*Object) void {
            _ = self;
            if (object) |o| {
                o.*.marked = true;
                if (options.debug) {
                    std.debug.print("{} marked\n", .{object.*});
                }
            }
        }

        fn markValue(self: *Self, value: Value) void {
            switch (value) {
                .Object => |o| self.markObject(o),
                else => {},
            }
        }

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
    };
}

test "can allocate and deallocate a small object" {
    var gca = GarbageCollector(.{ .debug = false }).init();
    defer std.testing.expect(gca.deinit() == std.heap.Check.ok) catch @panic("leak");
    const allocator = gca.allocator();

    const T = struct { a: u32 };
    var memory = try allocator.create(T);
    memory.* = T{ .a = 10 };
    allocator.destroy(memory);
}

test "can allocate and deallocate a list" {
    var gca = GarbageCollector(.{ .debug = false }).init();
    defer std.testing.expect(gca.deinit() == std.heap.Check.ok) catch @panic("leak");
    const allocator = gca.allocator();

    var l = std.ArrayList(u32).init(allocator);
    defer l.deinit();
}

// That should fail in the future when the gc kicks in as we don't have the vm linked here
test "can allocate and deallocate a list with list resizes" {
    var gca = GarbageCollector(.{ .debug = false }).init();
    defer std.testing.expect(gca.deinit() == std.heap.Check.ok) catch @panic("leak");
    const allocator = gca.allocator();

    var l = std.ArrayList(usize).init(allocator);
    defer l.deinit();
    for (0..100) |i| {
        try l.append(i);
    }
}

test "can mark a single owned object in the constant pool" {
    const inner_allocator = std.testing.allocator;
    var gca = GarbageCollector(.{ .debug = false }).init();
    defer std.testing.expect(gca.deinit() == std.heap.Check.ok) catch @panic("leak");
    const gc_allocator = gca.allocator();

    var vm = try VirtualMachine.init(inner_allocator, gc_allocator);
    defer vm.deinit();
    gca.link(&vm);

    const s = std.ArrayList(u8).init(inner_allocator);

    var memory = try gc_allocator.create(Object);
    memory.* = Object.string(s);
    // TODO: Alright, there is a design decision, we have two options:
    // * make constant pool own the memory (current)
    // * make constant pool reference the memory
    _ = try vm.takeObjectOwnership(memory);
    _ = try vm.addConstant(.{ .Object = memory });

    try std.testing.expect(memory.*.marked == false);
    gca.markRoots();
    try std.testing.expect(memory.*.marked == true);
}
