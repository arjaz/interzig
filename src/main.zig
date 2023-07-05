const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        _ = deinit_status;
    }
    var vm = try VirtualMachine.init(allocator);
    defer vm.deinit();

    try vm.chunks.append(Chunk.init(allocator));
    const chunk = &vm.chunks.items[0];

    const index0 = try vm.addConstant(.{ .I64 = 42 });
    const index1 = try vm.addConstant(.{ .I64 = 10 });
    const objIndex0 = try vm.addObject(try string_from_u8_slice(allocator, "hello world"));
    const objIndex1 = try vm.addObject(try string_from_u8_slice(allocator, "I love Helga"));

    _ = try chunk.addInstruction(.{ .LoadConstant = index0 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadObject = objIndex0 }, 0);
    _ = try chunk.addInstruction(.{ .LoadObject = objIndex1 }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    chunk.disassemble("main");
    try vm.interpret();

    vm.printStack();
    vm.printObjects();
}

test "add i64 constant" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();
    const index = try vm.addConstant(.{ .I64 = 42 });
    try std.testing.expectEqual(@as(usize, 1), vm.constants.items.len);
    try std.testing.expectEqual(@as(i64, 42), vm.constants.items[index].I64);
}

test "add return instruction" {
    var chunk = Chunk.init(std.testing.allocator);
    defer chunk.deinit();
    _ = try chunk.addInstruction(.Return, 0);
    try std.testing.expectEqual(@as(usize, 1), chunk.code.items.len);
    try std.testing.expectEqual(OpCode.Return, chunk.code.items[0]);
}

test "interpret return" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
}

test "interpret constant" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index = try vm.addConstant(.{ .I64 = 42 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(@as(i64, 42), vm.stack.items[0].I64);
}

test "interpret 1 + 2" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .I64 = 2 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(@as(i64, 3), vm.stack.items[0].I64);
}

test "interpret 1 - 2" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .I64 = 2 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Sub, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(@as(i64, -1), vm.stack.items[0].I64);
}

test "interpret 10u64 - 7u64" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index1 = try vm.addConstant(.{ .U64 = 10 });
    const index2 = try vm.addConstant(.{ .U64 = 7 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Sub, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(@as(u64, 3), vm.stack.items[0].U64);
}

test "interpret not(nil)" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index = try vm.addConstant(.Nil);
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(Value.True, vm.stack.items[0]);
}

test "interpret not(10.7)" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index = try vm.addConstant(.{ .F64 = 10.7 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(Value.Nil, vm.stack.items[0]);
}

test "interpret (1 + 2.5) results in type mismatch" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .F64 = 2.5 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    vm.interpret() catch |err| {
        try std.testing.expectEqual(err, error.TypeMismatch);
        return;
    };
    try std.testing.expect(false);
}

test "interpret let nice = true" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const indexTrue = try vm.addConstant(.True);
    const globalNameIndex = try vm.addObject(try string_from_u8_slice(std.testing.allocator, "nice"));
    const globalConstantIndex = try vm.addConstant(.{ .Object = globalNameIndex });
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .StoreGlobal = globalConstantIndex }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(Value.True, vm.stack.items[0]);
    try std.testing.expectEqual(@as(?Value, .True), vm.globals.get("nice"));
}

test "interpret read global" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const indexTrue = try vm.addConstant(.True);
    const globalNameIndex = try vm.addObject(try string_from_u8_slice(std.testing.allocator, "nice"));
    const globalConstantIndex = try vm.addConstant(.{ .Object = globalNameIndex });
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .StoreGlobal = globalConstantIndex }, 0);
    _ = try chunk.addInstruction(.Pop, 0);
    _ = try chunk.addInstruction(.{ .LoadGlobal = globalConstantIndex }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(Value.True, vm.stack.items[0]);
}

test "interpret jump over one instruction" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const indexTrue = try vm.addConstant(.True);
    _ = try chunk.addInstruction(.{ .Jump = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret jump if false with nil on the stack" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const indexNil = try vm.addConstant(.Nil);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexNil }, 0);
    _ = try chunk.addInstruction(.{ .JumpIfFalse = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexNil }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
}

test "interpret jump if false with true on the stack" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const indexTrue = try vm.addConstant(.True);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .JumpIfFalse = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
    try std.testing.expectEqual(@as(usize, 2), vm.stack.items.len);
}

test "interpert jump back" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    _ = try chunk.addInstruction(.{ .Jump = 2 }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    _ = try chunk.addInstruction(.{ .JumpBack = 1 }, 0);
    try vm.chunks.append(chunk);

    try vm.interpret();
}

const VirtualMachine = struct {
    chunks: std.ArrayList(Chunk),
    stack: std.ArrayList(Value),
    constants: std.ArrayList(Value),
    objects: std.ArrayList(Object),
    globals: std.StringHashMap(Value),

    pub fn init(allocator: std.mem.Allocator) !VirtualMachine {
        return VirtualMachine{
            .chunks = std.ArrayList(Chunk).init(allocator),
            .stack = std.ArrayList(Value).init(allocator),
            .constants = std.ArrayList(Value).init(allocator),
            .objects = std.ArrayList(Object).init(allocator),
            .globals = std.StringHashMap(Value).init(allocator),
        };
    }

    pub fn deinit(self: *VirtualMachine) void {
        for (self.chunks.items) |*chunk| {
            chunk.deinit();
        }
        self.chunks.deinit();
        self.stack.deinit();
        self.constants.deinit();
        for (self.objects.items) |*object| {
            object.deinit();
        }
        self.objects.deinit();
        self.globals.deinit();
    }

    pub fn printStack(self: *VirtualMachine) void {
        std.debug.print("=== Stack ===\n", .{});
        for (self.stack.items) |value, offset| {
            switch (value) {
                .I64 => |v| std.debug.print("{x:4}    {} i64\n", .{ offset, v }),
                .U64 => |v| std.debug.print("{x:4}    {} u64\n", .{ offset, v }),
                .F64 => |v| std.debug.print("{x:4}    {} f64\n", .{ offset, v }),
                .True => std.debug.print("{x:4}    true\n", .{offset}),
                .Nil => std.debug.print("{x:4}    nil\n", .{offset}),
                .Object => |v| std.debug.print("{x:4}    {} object\n", .{ offset, v }),
            }
        }
    }

    pub fn printObjects(self: *VirtualMachine) void {
        std.debug.print("=== Objects ===\n", .{});
        for (self.objects.items) |object, offset| {
            switch (object) {
                .String => |s| {
                    std.debug.print("{x:4}    \"{s}\"\n", .{ offset, s.items });
                },
            }
        }
    }

    pub fn addConstant(self: *VirtualMachine, value: Value) !usize {
        try self.constants.append(value);
        return self.constants.items.len - 1;
    }

    pub fn addObject(self: *VirtualMachine, object: Object) !usize {
        try self.objects.append(object);
        return self.objects.items.len - 1;
    }

    pub fn interpret(self: *VirtualMachine) !void {
        var ip = @ptrCast([*]OpCode, &self.chunks.items[0].code.items[0]);

        // That is unsafe because we assume there is a return instruction which will be executed.
        // But we can easily overshoot the end of the chunk and read garbage if the bytecode is malformed.
        while (true) : (ip += 1) {
            const instruction = ip[0];
            switch (instruction) {
                .Return => {
                    return;
                },
                .Pop => {
                    _ = self.stack.pop();
                },
                .StoreGlobal => |index| {
                    try interpretStoreGlobal(self, index);
                },
                .LoadGlobal => |index| {
                    try interpretLoadGlobal(self, index);
                },
                .StoreLocal => |index| {
                    try interpretStoreLocal(self, index);
                },
                .LoadLocal => |index| {
                    try interpretLoadLocal(self, index);
                },
                .LoadConstant => |index| {
                    try interpretLoadConstant(self, index);
                },
                .LoadObject => |index| {
                    try interpretLoadObject(self, index);
                },
                .Jump => |offset| {
                    // Subtract 1 because the loop will increment the instruction pointer.
                    ip += offset - 1;
                },
                .JumpIfFalse => |offset| {
                    const value = self.stack.items[self.stack.items.len - 1];
                    if (value.falsey()) {
                        // Subtract 1 because the loop will increment the instruction pointer.
                        ip += offset - 1;
                    }
                },
                .JumpBack => |offset| {
                    // Adds 1 because the loop will increment the instruction pointer.
                    ip -= offset + 1;
                },
                .Add => {
                    try interpretAdd(self);
                },
                .Sub => {
                    try interpretSub(self);
                },
                .AddF => {
                    try interpretAddF(self);
                },
                .SubF => {
                    try interpretSubF(self);
                },
                .Not => {
                    try interpretNot(self);
                },
                .Equal => {
                    try interpretEqual(self);
                },
                .NotEqual => {
                    try interpretNotEqual(self);
                },
            }
        }
    }
};

const Object = union(enum) {
    String: std.ArrayList(u8),

    pub fn deinit(self: *Object) void {
        switch (self.*) {
            .String => {
                self.String.deinit();
            },
        }
    }
};

pub fn string_from_u8_slice(allocator: std.mem.Allocator, slice: []const u8) !Object {
    var string = std.ArrayList(u8).init(allocator);
    for (slice) |byte| {
        try string.append(byte);
    }
    return .{ .String = string };
}

const Value = union(enum) {
    I64: i64,
    U64: u64,
    F64: f64,
    True,
    Nil,
    Object: usize,

    pub fn print(self: Value) void {
        switch (self) {
            .I64 => |im| {
                std.debug.print("{} i64\n", .{im});
            },
            .U64 => |im| {
                std.debug.print("{} u64\n", .{im});
            },
            .F64 => |im| {
                std.debug.print("{} f64\n", .{im});
            },
            .Nil => {
                std.debug.print("nil\n", .{});
            },
            .True => {
                std.debug.print("true\n", .{});
            },
            .Object => |index| {
                std.debug.print("object {}\n", .{index});
            },
        }
    }

    pub fn truthy(self: Value) bool {
        return switch (self) {
            .True => true,
            else => false,
        };
    }

    pub fn falsey(self: Value) bool {
        return !self.truthy();
    }
};

const OpCode = union(enum) {
    // Returns from the current function.
    Return,
    // Pop a value from the stack.
    Pop,
    // Stores a value from the top of the stack in a local variable. Index into the name in the constant pool.
    StoreGlobal: usize,
    // Loads a value from a global variable and pushes it onto the stack. Index into the name in the constant pool.
    LoadGlobal: usize,
    // Stores a value from the top of the stack in a local variable. Index into the stack.
    StoreLocal: usize,
    // Loads a value from a local variable and pushes it onto the stack. Index into the stack.
    LoadLocal: usize,
    // Loads a constant from the constant pool and pushes it onto the stack.
    LoadConstant: usize,
    // Loads an object from the object pool and pushes it onto the stack.
    LoadObject: usize,
    // Jumps unconditionally. The jump offset is relative to the current instruction.
    Jump: u32,
    // Jumps if the value on the stack is falsey. The jump offset is relative to the current instruction.
    JumpIfFalse: u32,
    // Jumps back to the start of the loop (presumably). The jump offset is relative to the current instruction.
    JumpBack: u32,
    // Checks for strict equality between two values from the stack and pushes the result onto the stack.
    Equal,
    // Checks for strict inequality between two values from the stack and pushes the result onto the stack.
    NotEqual,
    // Adds two values from the stack and pushes the result onto the stack.
    Add,
    // Subtracts two values from the stack and pushes the result onto the stack.
    Sub,
    // Adds two floating point values from the stack and pushes the result onto the stack.
    AddF,
    // Subtracts two floating point values from the stack and pushes the result onto the stack.
    SubF,
    // Logical not, everything that is not nil is considered true.
    Not,
};

const Chunk = struct {
    code: std.ArrayList(OpCode),
    lineNumbers: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{
            .code = std.ArrayList(OpCode).init(allocator),
            .lineNumbers = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn deinit(self: *Chunk) void {
        self.code.deinit();
        self.lineNumbers.deinit();
    }

    pub fn disassemble(self: *const Chunk, name: []const u8) void {
        std.debug.print("== {s} ==\n", .{name});

        for (self.code.items) |instruction, offset| {
            const line = self.lineNumbers.items[offset];
            switch (instruction) {
                .Return => {
                    std.debug.print("{x:4}    {d} return\n", .{ offset, line });
                },
                .Pop => {
                    std.debug.print("{x:4}    {d} pop\n", .{ offset, line });
                },
                .StoreGlobal => {
                    std.debug.print("{x:4}    {d} store global {d}\n", .{ offset, line, instruction.StoreGlobal });
                },
                .LoadGlobal => {
                    std.debug.print("{x:4}    {d} load global {d}\n", .{ offset, line, instruction.LoadGlobal });
                },
                .StoreLocal => {
                    std.debug.print("{x:4}    {d} store local {d}\n", .{ offset, line, instruction.StoreLocal });
                },
                .LoadLocal => {
                    std.debug.print("{x:4}    {d} load local {d}\n", .{ offset, line, instruction.LoadLocal });
                },
                .LoadConstant => {
                    std.debug.print("{x:4}    {d} load constant {d}\n", .{ offset, line, instruction.LoadConstant });
                },
                .LoadObject => {
                    std.debug.print("{x:4}    {d} load object {d}\n", .{ offset, line, instruction.LoadObject });
                },
                .Jump => {
                    std.debug.print("{x:4}    {d} jump {d}\n", .{ offset, line, instruction.Jump });
                },
                .JumpIfFalse => {
                    std.debug.print("{x:4}    {d} jump if false {d}\n", .{ offset, line, instruction.JumpIfFalse });
                },
                .JumpBack => {
                    std.debug.print("{x:4}    {d} jump back {d}\n", .{ offset, line, instruction.JumpBack });
                },
                .Add => {
                    std.debug.print("{x:4}    {d} add\n", .{ offset, line });
                },
                .Sub => {
                    std.debug.print("{x:4}    {d} sub\n", .{ offset, line });
                },
                .AddF => {
                    std.debug.print("{x:4}    {d} addf\n", .{ offset, line });
                },
                .SubF => {
                    std.debug.print("{x:4}    {d} subf\n", .{ offset, line });
                },
                .Not => {
                    std.debug.print("{x:4}    {d} not\n", .{ offset, line });
                },
                .Equal => {
                    std.debug.print("{x:4}    {d} equal", .{ offset, line });
                },
                .NotEqual => {
                    std.debug.print("{x:4}    {d} not equal", .{ offset, line });
                },
            }
        }
    }

    pub fn addInstruction(self: *Chunk, instruction: OpCode, line: u32) !usize {
        try self.code.append(instruction);
        try self.lineNumbers.append(line);
        return self.code.items.len - 1;
    }
};

/// Stores the value on top of the stack in the global variable at the given index.
/// Does not pop the value from the stack.
fn interpretStoreGlobal(vm: *VirtualMachine, index: usize) !void {
    if (index >= vm.constants.items.len) {
        std.debug.print("Invalid global index\n", .{});
        return error.InvalidGlobalIndex;
    }
    const nameIndex = vm.constants.items[index];
    const nameObject = switch (nameIndex) {
        .Object => vm.objects.items[nameIndex.Object],
        else => {
            std.debug.print("Invalid global name index\n", .{});
            return error.InvalidGlobalNameIndex;
        },
    };
    const name = switch (nameObject) {
        .String => nameObject.String,
    };
    try vm.globals.put(name.items, vm.stack.items[vm.stack.items.len - 1]);
}

fn interpretLoadGlobal(vm: *VirtualMachine, index: usize) !void {
    if (index >= vm.constants.items.len) {
        std.debug.print("Invalid global index\n", .{});
        return error.InvalidGlobalIndex;
    }
    const nameIndex = vm.constants.items[index];
    const nameObject = switch (nameIndex) {
        .Object => vm.objects.items[nameIndex.Object],
        else => {
            std.debug.print("Invalid global name index\n", .{});
            return error.InvalidGlobalNameIndex;
        },
    };
    const name = switch (nameObject) {
        .String => nameObject.String,
    };
    const value = vm.globals.get(name.items) orelse {
        std.debug.print("Undefined global variable\n", .{});
        return error.UndefinedGlobalVariable;
    };
    try vm.stack.append(value);
}

/// Stores the value on top of the stack in the local variable at the given index.
/// Does not pop the value from the stack.
fn interpretStoreLocal(vm: *VirtualMachine, index: usize) !void {
    vm.stack.items[index] = vm.stack.items[vm.stack.items.len - 1];
}

fn interpretLoadLocal(vm: *VirtualMachine, index: usize) !void {
    try vm.stack.append(vm.stack.items[index]);
}

fn interpretLoadConstant(vm: *VirtualMachine, index: usize) !void {
    if (index >= vm.constants.items.len) {
        std.debug.print("Invalid constant index\n", .{});
        return error.InvalidConstantIndex;
    }
    const v = vm.constants.items[index];
    try vm.stack.append(v);
}

fn interpretLoadObject(vm: *VirtualMachine, index: usize) !void {
    if (index >= vm.objects.items.len) {
        std.debug.print("Invalid object index\n", .{});
        return error.InvalidObjectIndex;
    }
    try vm.stack.append(.{ .Object = index });
}

fn interpretAdd(vm: *VirtualMachine) !void {
    const b_ = vm.stack.pop();
    const a_ = vm.stack.pop();
    switch (a_) {
        .I64 => |a| {
            switch (b_) {
                .I64 => |b| {
                    try vm.stack.append(.{ .I64 = a + b });
                },
                else => {
                    std.debug.print("Unsupported type for add\n", .{});
                    return error.TypeMismatch;
                },
            }
        },
        .U64 => |a| {
            switch (b_) {
                .U64 => |b| {
                    try vm.stack.append(.{ .U64 = a + b });
                },
                else => {
                    std.debug.print("Unsupported type for add\n", .{});
                    return error.TypeMismatch;
                },
            }
        },
        else => {
            std.debug.print("Unsupported type for add\n", .{});
            return error.TypeMismatch;
        },
    }
}

fn interpretSub(vm: *VirtualMachine) !void {
    const b_ = vm.stack.pop();
    const a_ = vm.stack.pop();
    switch (a_) {
        .I64 => |a| {
            switch (b_) {
                .I64 => |b| {
                    try vm.stack.append(.{ .I64 = a - b });
                },
                else => {
                    std.debug.print("Unsupported type for sub\n", .{});
                    return error.TypeMismatch;
                },
            }
        },
        .U64 => |a| {
            switch (b_) {
                .U64 => |b| {
                    try vm.stack.append(.{ .U64 = a - b });
                },
                else => {
                    std.debug.print("Unsupported type for sub\n", .{});
                    return error.TypeMismatch;
                },
            }
        },
        else => {
            std.debug.print("Unsupported type for sub\n", .{});
            return error.TypeMismatch;
        },
    }
}

fn interpretAddF(vm: *VirtualMachine) !void {
    const b_ = vm.stack.pop();
    const a_ = vm.stack.pop();
    switch (a_) {
        .F64 => |a| {
            switch (b_) {
                .F64 => |b| {
                    try vm.stack.append(.{ .F64 = a + b });
                },
                else => {
                    std.debug.print("Unsupported type for add\n", .{});
                    return error.TypeMismatch;
                },
            }
        },
        else => {
            std.debug.print("Unsupported type for add\n", .{});
            return error.TypeMismatch;
        },
    }
}

fn interpretSubF(vm: *VirtualMachine) !void {
    const b_ = vm.stack.pop();
    const a_ = vm.stack.pop();
    switch (a_) {
        .F64 => |a| {
            switch (b_) {
                .F64 => |b| {
                    try vm.stack.append(.{ .F64 = a - b });
                },
                else => {
                    std.debug.print("Unsupported type for sub\n", .{});
                    return error.TypeMismatch;
                },
            }
        },
        else => {
            std.debug.print("Unsupported type for sub\n", .{});
            return error.TypeMismatch;
        },
    }
}

fn interpretNot(vm: *VirtualMachine) !void {
    const a_ = vm.stack.pop();
    switch (a_) {
        .Nil => {
            try vm.stack.append(.True);
        },
        else => {
            try vm.stack.append(.Nil);
        },
    }
}

fn interpretEqual(vm: *VirtualMachine) !void {
    const b_ = vm.stack.pop();
    const a_ = vm.stack.pop();
    switch (a_) {
        .U64 => |a| {
            switch (b_) {
                .U64 => |b| {
                    if (a == b) {
                        try vm.stack.append(.True);
                    } else {
                        try vm.stack.append(.Nil);
                    }
                },
                else => {
                    try vm.stack.append(.Nil);
                },
            }
        },
        .I64 => |a| {
            switch (b_) {
                .I64 => |b| {
                    if (a == b) {
                        try vm.stack.append(.True);
                    } else {
                        try vm.stack.append(.Nil);
                    }
                },
                else => {
                    try vm.stack.append(.Nil);
                },
            }
        },
        .F64 => |a| {
            switch (b_) {
                .F64 => |b| {
                    if (a == b) {
                        try vm.stack.append(.True);
                    } else {
                        try vm.stack.append(.Nil);
                    }
                },
                else => {
                    try vm.stack.append(.Nil);
                },
            }
        },
        .True => {
            switch (b_) {
                .True => {
                    try vm.stack.append(.True);
                },
                else => {
                    try vm.stack.append(.Nil);
                },
            }
        },
        .Nil => {
            switch (b_) {
                .Nil => {
                    try vm.stack.append(.True);
                },
                else => {
                    try vm.stack.append(.Nil);
                },
            }
        },
        .Object => |index| {
            switch (b_) {
                .Object => |otherIndex| {
                    if (index == otherIndex) {
                        try vm.stack.append(.True);
                    } else {
                        try vm.stack.append(.Nil);
                    }
                },
                else => {
                    try vm.stack.append(.Nil);
                },
            }
        },
    }
}

fn interpretNotEqual(vm: *VirtualMachine) !void {
    const b_ = vm.stack.pop();
    const a_ = vm.stack.pop();
    switch (a_) {
        .U64 => |a| {
            switch (b_) {
                .U64 => |b| {
                    if (a != b) {
                        try vm.stack.append(.True);
                    } else {
                        try vm.stack.append(.Nil);
                    }
                },
                else => {
                    try vm.stack.append(.True);
                },
            }
        },
        .I64 => |a| {
            switch (b_) {
                .I64 => |b| {
                    if (a != b) {
                        try vm.stack.append(.True);
                    } else {
                        try vm.stack.append(.Nil);
                    }
                },
                else => {
                    try vm.stack.append(.True);
                },
            }
        },
        .F64 => |a| {
            switch (b_) {
                .F64 => |b| {
                    if (a != b) {
                        try vm.stack.append(.True);
                    } else {
                        try vm.stack.append(.Nil);
                    }
                },
                else => {
                    try vm.stack.append(.True);
                },
            }
        },
        .True => {
            switch (b_) {
                .True => {
                    try vm.stack.append(.Nil);
                },
                else => {
                    try vm.stack.append(.True);
                },
            }
        },
        .Nil => {
            switch (b_) {
                .Nil => {
                    try vm.stack.append(.Nil);
                },
                else => {
                    try vm.stack.append(.True);
                },
            }
        },
        .Object => |index| {
            switch (b_) {
                .Object => |otherIndex| {
                    if (index != otherIndex) {
                        try vm.stack.append(.True);
                    } else {
                        try vm.stack.append(.Nil);
                    }
                },
                else => {
                    try vm.stack.append(.True);
                },
            }
        },
    }
}
