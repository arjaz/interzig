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

    const index0 = try vm.addConstant(Value{ .I64 = 42 });
    const index1 = try vm.addConstant(Value{ .I64 = 10 });
    _ = try chunk.addInstruction(.{ .Constant = index0 }, 0);
    _ = try chunk.addInstruction(.{ .Constant = index1 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.{ .Constant = index1 }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    chunk.disassemble("main");
    try interpret(&vm);

    vm.printStack();
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

    try interpret(&vm);
}

test "interpret constant" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index = try vm.addConstant(.{ .I64 = 42 });
    _ = try chunk.addInstruction(.{ .Constant = index }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try interpret(&vm);
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(@as(i64, 42), vm.stack.items[0].I64);
}

test "interpret 1 + 2" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .I64 = 2 });
    _ = try chunk.addInstruction(.{ .Constant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .Constant = index2 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try interpret(&vm);
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(@as(i64, 3), vm.stack.items[0].I64);
}

test "interpret 1 - 2" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .I64 = 2 });
    _ = try chunk.addInstruction(.{ .Constant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .Constant = index2 }, 0);
    _ = try chunk.addInstruction(.Sub, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try interpret(&vm);
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(@as(i64, -1), vm.stack.items[0].I64);
}

test "interpret 10u64 - 7u64" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index1 = try vm.addConstant(.{ .U64 = 10 });
    const index2 = try vm.addConstant(.{ .U64 = 7 });
    _ = try chunk.addInstruction(.{ .Constant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .Constant = index2 }, 0);
    _ = try chunk.addInstruction(.Sub, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try interpret(&vm);
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(@as(u64, 3), vm.stack.items[0].U64);
}

test "interpret not(nil)" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index = try vm.addConstant(.Nil);
    _ = try chunk.addInstruction(.{ .Constant = index }, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try interpret(&vm);
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(Value.True, vm.stack.items[0]);
}

test "interpret not(10.7)" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index = try vm.addConstant(.{ .F64 = 10.7 });
    _ = try chunk.addInstruction(.{ .Constant = index }, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    try interpret(&vm);
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
    try std.testing.expectEqual(Value.Nil, vm.stack.items[0]);
}

test "interpret (1 + 2.5) results in type mismatch" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    var chunk = Chunk.init(std.testing.allocator);
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .F64 = 2.5 });
    _ = try chunk.addInstruction(.{ .Constant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .Constant = index2 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Return, 0);
    try vm.chunks.append(chunk);

    interpret(&vm) catch |err| {
        try std.testing.expectEqual(err, error.TypeMismatch);
        return;
    };
    try std.testing.expect(false);
}

const VirtualMachine = struct {
    chunks: std.ArrayList(Chunk),
    stack: std.ArrayList(Value),
    constants: std.ArrayList(Value),

    pub fn init(allocator: std.mem.Allocator) !VirtualMachine {
        return VirtualMachine{
            .chunks = std.ArrayList(Chunk).init(allocator),
            .stack = std.ArrayList(Value).init(allocator),
            .constants = std.ArrayList(Value).init(allocator),
        };
    }

    pub fn deinit(self: *VirtualMachine) void {
        for (self.chunks.items) |*chunk| {
            chunk.deinit();
        }
        self.chunks.deinit();
        self.stack.deinit();
        self.constants.deinit();
    }

    pub fn printStack(self: *VirtualMachine) void {
        std.debug.print("=== Stack ===\n", .{});
        for (self.stack.items) |value, offset| {
            switch (value) {
                .I64 => |v| std.debug.print("{x:4}    {}\n", .{ offset, v }),
                .U64 => |v| std.debug.print("{x:4}    {}\n", .{ offset, v }),
                .F64 => |v| std.debug.print("{x:4}    {}\n", .{ offset, v }),
                .True => std.debug.print("{x:4}    true\n", .{offset}),
                .Nil => std.debug.print("{x:4}    nil\n", .{offset}),
            }
        }
    }

    pub fn addConstant(self: *VirtualMachine, value: Value) !usize {
        try self.constants.append(value);
        return self.constants.items.len - 1;
    }
};

const Value = union(enum) {
    I64: i64,
    U64: u64,
    F64: f64,
    True,
    Nil,

    pub fn print(self: Value) void {
        switch (self) {
            .I64 => |im| {
                std.debug.print("{d} i64\n", .{im});
            },
            .U64 => |im| {
                std.debug.print("{d} u64\n", .{im});
            },
            .F64 => |im| {
                std.debug.print("{f} f64\n", .{im});
            },
            .Nil => {
                std.debug.print("nil\n", .{});
            },
            .True => {
                std.debug.print("true\n", .{});
            },
        }
    }

    pub fn truthy(self: Value) bool {
        switch (self) {
            .True => {
                return true;
            },
            else => {
                return false;
            },
        }
    }

    pub fn falsey(self: Value) bool {
        return !self.truthy();
    }
};

const OpCode = union(enum) {
    // Returns from the current function.
    Return,
    // Loads a constant from the constant pool and pushes it onto the stack.
    Constant: usize,
    Equal,
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
                .Constant => {
                    std.debug.print("{x:4}    {d} constant {d}\n", .{ offset, line, instruction.Constant });
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

pub fn interpret(vm: *VirtualMachine) !void {
    var ip = @ptrCast([*]OpCode, &vm.chunks.items[0].code.items[0]);

    // That is unsafe because we assume there is a return instruction at the end of the chunk.
    // But we can easily overshoot the end of the chunk and read garbage.
    while (true) : (ip += 1) {
        const instruction = ip[0];
        switch (instruction) {
            .Return => {
                return;
            },
            .Constant => |index| {
                try interpretConstant(vm, index);
            },
            .Add => {
                try interpretAdd(vm);
            },
            .Sub => {
                try interpretSub(vm);
            },
            .AddF => {
                try interpretAddF(vm);
            },
            .SubF => {
                try interpretSubF(vm);
            },
            .Not => {
                try interpretNot(vm);
            },
            .Equal => {
                try interpretEqual(vm);
            },
            .NotEqual => {
                try interpretNotEqual(vm);
            },
        }
    }
}

fn interpretConstant(vm: *VirtualMachine, index: usize) !void {
    const v = vm.constants.items[index];
    try vm.stack.append(v);
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
    }
}
