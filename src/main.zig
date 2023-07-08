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

    const mainFnIndex = try vm.addObject(try named_function(allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];

    const strIndex = try vm.addObject(try string_from_u8_slice(allocator, "I love Helga\n"));
    const nativePrintStringIndex = try vm.addObject(.{ .Native = .{ .arity = 1, .function = nativePrintString } });

    _ = try mainFn.Function.chunk.addInstruction(.{ .LoadObject = strIndex }, 0);
    _ = try mainFn.Function.chunk.addInstruction(.{ .LoadObject = nativePrintStringIndex }, 0);
    _ = try mainFn.Function.chunk.addInstruction(.Call, 0);
    _ = try mainFn.Function.chunk.addInstruction(.Return, 0);

    const mainFrame = CallFrame{ .ip = @ptrCast([*]OpCode, &mainFn.Function.chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(mainFrame);
    _ = try vm.interpret(allocator);
}

fn nativePrintString(vm: *VirtualMachine, arity: usize) Value {
    if (arity != 1) {
        unreachable;
    }
    const stringIndex = vm.stack.pop();
    const string = &vm.objects.items[stringIndex.Object].String;
    std.debug.print("{s}", .{string.items});
    return Value.Nil;
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

    const nil = try vm.addConstant(.Nil);

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    _ = try chunk.addInstruction(.{ .LoadConstant = nil }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.Nil, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret constant" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index = try vm.addConstant(.{ .I64 = 42 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value{ .I64 = 42 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret 1 + 2" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .I64 = 2 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value{ .I64 = 3 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret 1 - 2" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .I64 = 2 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Sub, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value{ .I64 = -1 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret 10u64 - 7u64" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index1 = try vm.addConstant(.{ .U64 = 10 });
    const index2 = try vm.addConstant(.{ .U64 = 7 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Sub, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value{ .U64 = 3 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret not(nil)" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index = try vm.addConstant(.Nil);
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret not(10.7)" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index = try vm.addConstant(.{ .F64 = 10.7 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.Nil, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret (1 + 2.5) results in type mismatch" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .F64 = 2.5 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    _ = vm.interpret(std.testing.allocator) catch |err| {
        try std.testing.expectEqual(err, error.TypeMismatch);
        return;
    };
    try std.testing.expect(false);
}

test "interpret set global" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const indexTrue = try vm.addConstant(.True);
    const globalNameIndex = try vm.addObject(try string_from_u8_slice(std.testing.allocator, "nice"));
    const globalConstantIndex = try vm.addConstant(.{ .Object = globalNameIndex });
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .StoreGlobal = globalConstantIndex }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
    try std.testing.expectEqual(@as(?Value, .True), vm.globals.get("nice"));
}

test "interpret read global" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const indexTrue = try vm.addConstant(.True);
    const globalNameIndex = try vm.addObject(try string_from_u8_slice(std.testing.allocator, "nice"));
    const globalConstantIndex = try vm.addConstant(.{ .Object = globalNameIndex });
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .StoreGlobal = globalConstantIndex }, 0);
    _ = try chunk.addInstruction(.Pop, 0);
    _ = try chunk.addInstruction(.{ .LoadGlobal = globalConstantIndex }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret jump over one instruction" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const indexTrue = try vm.addConstant(.True);
    _ = try chunk.addInstruction(.{ .Jump = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    _ = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret jump if false with nil on the stack" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const indexNil = try vm.addConstant(.Nil);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexNil }, 0);
    _ = try chunk.addInstruction(.{ .JumpIfFalse = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexNil }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    _ = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret jump if false with true on the stack" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const indexTrue = try vm.addConstant(.True);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .JumpIfFalse = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    _ = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
}

test "interpret jump back" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const nilIndex = try vm.addConstant(.Nil);
    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    _ = try chunk.addInstruction(.{ .Jump = 3 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = nilIndex }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    _ = try chunk.addInstruction(.{ .JumpBack = 2 }, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.Nil, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret fn call" {
    // For this we will have a simple function that just returns true.
    // We will call it from main and expect the result to be true.
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const indexTrue = try vm.addConstant(.True);

    const justTrueFnIndex = try vm.addObject(try named_function(std.testing.allocator, "justTrue", 0, 0));
    const justTrueFn = &vm.objects.items[justTrueFnIndex];
    const justTrueChunk = &justTrueFn.Function.chunk;
    _ = try justTrueChunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try justTrueChunk.addInstruction(.Return, 0);

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadObject = justTrueFnIndex }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret closure call" {
    // For this we will have a simple function that just returns true.
    // We will call it from main and expect the result to be true.
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const indexTrue = try vm.addConstant(.True);

    const justTrueFnIndex = try vm.addObject(try named_function(std.testing.allocator, "justTrue", 0, 0));
    const justTrueFn = &vm.objects.items[justTrueFnIndex];
    const justTrueChunk = &justTrueFn.Function.chunk;
    _ = try justTrueChunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try justTrueChunk.addInstruction(.Return, 0);

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadObject = justTrueFnIndex }, 0);
    _ = try mainChunk.addInstruction(.AsClosure, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret closure call with an open local upvalue" {
    // For this we will have a simple function that just returns true from the enclosing scope.
    // We will call it from main and expect the result to be true.
    //
    // fn main() {
    //     let a = true;
    //     fn justTrue() {
    //         return a;
    //     }
    //     return justTrue();
    // }
    //
    // justTrue:
    //   load upvalue 0
    //   return
    // main:
    //   load true
    //   load justTrue
    //   as closure
    //   capture local 0
    //   call
    //   return
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const indexTrue = try vm.addConstant(.True);

    const justTrueFnIndex = try vm.addObject(try named_function(std.testing.allocator, "justTrue", 0, 1));
    const justTrueFn = &vm.objects.items[justTrueFnIndex];
    const justTrueChunk = &justTrueFn.Function.chunk;
    _ = try justTrueChunk.addInstruction(.{ .LoadUpvalue = 0 }, 0);
    _ = try justTrueChunk.addInstruction(.Return, 0);

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try mainChunk.addInstruction(.{ .LoadObject = justTrueFnIndex }, 0);
    _ = try mainChunk.addInstruction(.AsClosure, 0);
    _ = try mainChunk.addInstruction(.{ .CaptureUpvalue = .{ .local = true, .index = 0 } }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.True, result);
    // the stack is not empty because we have one local variable in main.
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
}

test "interpret closure call with an open non-local upvalue" {
    // The same as the previous test but the upvalue is not local.
    //
    // fn main() {
    //     let a = true;
    //     fn justTrue() {
    //         fn justTrue2() {
    //             return a;
    //         }
    //         return justTrue2();
    //     }
    //     return justTrue();
    // }
    //
    // justTrue2:
    //   load upvalue 0
    //   return
    // justTrue:
    //   load justTrue2
    //   as closure
    //   capture non-local 0
    //   call
    //   return
    // main:
    //   load true
    //   load justTrue
    //   as closure
    //   capture local 0
    //   call
    //   return
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const indexTrue = try vm.addConstant(.True);

    const justTrue2FnIndex = try vm.addObject(try named_function(std.testing.allocator, "justTrue2", 0, 1));
    const justTrue2Fn = &vm.objects.items[justTrue2FnIndex];
    const justTrue2Chunk = &justTrue2Fn.Function.chunk;
    _ = try justTrue2Chunk.addInstruction(.{ .LoadUpvalue = 0 }, 0);
    _ = try justTrue2Chunk.addInstruction(.Return, 0);

    const justTrueFnIndex = try vm.addObject(try named_function(std.testing.allocator, "justTrue", 0, 1));
    const justTrueFn = &vm.objects.items[justTrueFnIndex];
    const justTrueChunk = &justTrueFn.Function.chunk;
    _ = try justTrueChunk.addInstruction(.{ .LoadObject = justTrue2FnIndex }, 0);
    _ = try justTrueChunk.addInstruction(.AsClosure, 0);
    _ = try justTrueChunk.addInstruction(.{ .CaptureUpvalue = .{ .local = false, .index = 0 } }, 0);
    _ = try justTrueChunk.addInstruction(.Call, 0);
    _ = try justTrueChunk.addInstruction(.Return, 0);

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try mainChunk.addInstruction(.{ .LoadObject = justTrueFnIndex }, 0);
    _ = try mainChunk.addInstruction(.AsClosure, 0);
    _ = try mainChunk.addInstruction(.{ .CaptureUpvalue = .{ .local = true, .index = 0 } }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.True, result);
    // the stack is not empty because we have one local variable in main.
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
}

test "interpret calling 1" {
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const oneIndex = try vm.addConstant(.{ .U64 = 1 });

    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadConstant = oneIndex }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    _ = vm.interpret(std.testing.allocator) catch |err| {
        try std.testing.expectEqual(err, error.TypeMismatch);
        return;
    };
    try std.testing.expect(false);
}

fn nativeFnTest(vm: *VirtualMachine, arity: usize) Value {
    var i: usize = 0;
    while (i < arity) : (i += 1) {
        _ = vm.stack.pop();
    }
    return .True;
}

test "interpret native fn call" {
    // A simple function that accepts one argument and returns Value.True.
    var vm = try VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();
    const oneIndex = try vm.addConstant(.{ .U64 = 1 });

    var nativeFn = .{ .Native = .{
        .arity = 1,
        .function = &nativeFnTest,
    } };

    const nativeFnIndex = try vm.addObject(nativeFn);
    const mainFnIndex = try vm.addObject(try named_function(std.testing.allocator, "main", 0, 0));
    const mainFn = &vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadConstant = oneIndex }, 0);
    _ = try mainChunk.addInstruction(.{ .LoadObject = nativeFnIndex }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = CallFrame{ .ip = @ptrCast([*]OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret(std.testing.allocator);
    try std.testing.expectEqual(Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

const VirtualMachine = struct {
    frames: std.ArrayList(CallFrame),
    stack: std.ArrayList(Value),
    constants: std.ArrayList(Value),
    objects: std.ArrayList(Object),
    globals: std.StringHashMap(Value),

    pub fn init(allocator: std.mem.Allocator) !VirtualMachine {
        return VirtualMachine{
            .frames = std.ArrayList(CallFrame).init(allocator),
            .stack = std.ArrayList(Value).init(allocator),
            .constants = std.ArrayList(Value).init(allocator),
            .objects = std.ArrayList(Object).init(allocator),
            .globals = std.StringHashMap(Value).init(allocator),
        };
    }

    pub fn deinit(self: *VirtualMachine) void {
        self.frames.deinit();
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
                .Function => |f| {
                    std.debug.print("{x:4}    function/{} \"{s}\"\n", .{ offset, f.arity, f.name.items });
                },
                .Native => |n| {
                    std.debug.print("{x:4}    native/{}\n", .{ offset, n.arity });
                },
                .Closure => |c| {
                    std.debug.print("{x:4}    closure/{} \"{s}\"\n", .{ offset, c.function.Function.arity, c.function.Function.name.items });
                },
            }
        }
    }

    pub fn printTrace(self: *VirtualMachine) void {
        std.debug.print("=== Trace ===\n", .{});
        for (self.frames.items) |frame, offset| {
            // The function can point to either a Function or a Closure.
            const function = switch (frame.function) {
                .Function => frame.function.Function,
                .Closure => frame.function.Closure.function.Function,
            };
            std.debug.print("{x:4}    {s}\n", .{ offset, function.name.items });
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

    pub fn interpret(self: *VirtualMachine, allocator: std.mem.Allocator) !Value {
        var frame = &self.frames.items[0];

        // That is unsafe because we assume there is a return instruction which will be executed.
        // But we can easily overshoot the end of the chunk and read garbage if the bytecode is malformed.
        while (true) : (frame.ip += 1) {
            const instruction = frame.ip[0];
            switch (instruction) {
                .Return => {
                    const result = self.stack.pop();
                    _ = self.frames.pop();
                    if (self.frames.items.len == 0) {
                        return result;
                    }
                    self.stack.shrinkRetainingCapacity(frame.stackBase);
                    frame = &self.frames.items[self.frames.items.len - 1];
                    _ = try self.stack.append(result);
                },
                .Pop => {
                    _ = self.stack.pop();
                },
                .AsClosure => {
                    const fIndex = self.stack.pop();
                    const fObject = switch (fIndex) {
                        .Object => |index| &self.objects.items[index],
                        else => {
                            std.debug.print("Expected object on the stack\n", .{});
                            return error.TypeMismatch;
                        },
                    };

                    switch (fObject.*) {
                        .Function => {
                            var lenUpvalues = fObject.Function.upvalues;
                            var upvalues = std.ArrayList(Object).init(allocator);
                            while (lenUpvalues > 0) {
                                frame.ip += 1;
                                lenUpvalues -= 1;
                                switch (frame.ip[0]) {
                                    .CaptureUpvalue => |u| {
                                        if (u.local) {
                                            const value = &self.stack.items[frame.stackBase + u.index];
                                            const upvalue = .{ .Upvalue = .{ .Open = .{ .location = value } } };
                                            _ = try upvalues.append(upvalue);
                                        } else {
                                            const upvalue = frame.function.Closure.upvalues.items[u.index];
                                            _ = try upvalues.append(upvalue);
                                        }
                                    },
                                    else => {
                                        std.debug.print("Expected CaptureUpvalue instruction\n", .{});
                                        return error.InternalError;
                                    },
                                }
                            }
                            const cIndex = try self.addObject(.{ .Closure = .{ .function = fObject, .upvalues = upvalues } });
                            _ = try self.stack.append(.{ .Object = cIndex });
                        },
                        else => {
                            std.debug.print("Expected function on the stack\n", .{});
                            return error.TypeMismatch;
                        },
                    }
                },
                .CaptureUpvalue => {
                    // this is disallowed, the upvalue capture is done in .AsClosure
                    std.debug.print("Single-standing CaptureUpvalue is disallowed, use AsClosure instead\n", .{});
                    return error.InternalError;
                },
                .Call => {
                    const fIndex = self.stack.pop();
                    const fObject = switch (fIndex) {
                        .Object => |index| &self.objects.items[index],
                        else => {
                            std.debug.print("Expected object on the stack\n", .{});
                            return error.TypeMismatch;
                        },
                    };
                    switch (fObject.*) {
                        .Function => |f| {
                            const newFrame = CallFrame{
                                .ip = @ptrCast([*]OpCode, &f.chunk.code.items[0]),
                                .function = fObject,
                                .stackBase = self.stack.items.len - f.arity,
                            };
                            try self.frames.append(newFrame);
                            frame = &self.frames.items[self.frames.items.len - 1];
                            // Subtract 1 because the loop will increment the instruction pointer.
                            frame.ip -= 1;
                        },
                        .Closure => |c| {
                            const newFrame = CallFrame{
                                .ip = @ptrCast([*]OpCode, &c.function.Function.chunk.code.items[0]),
                                .function = fObject,
                                .stackBase = self.stack.items.len - c.function.Function.arity,
                            };
                            try self.frames.append(newFrame);
                            frame = &self.frames.items[self.frames.items.len - 1];
                            // Subtract 1 because the loop will increment the instruction pointer.
                            frame.ip -= 1;
                        },
                        .Native => |f| {
                            const result = f.function(self, f.arity);
                            try self.stack.append(result);
                        },
                        else => {
                            std.debug.print("Expected function on the stack\n", .{});
                            return error.TypeMismatch;
                        },
                    }
                },
                .StoreUpvalue => |index| {
                    try interpretStoreUpvalue(self, frame, index);
                },
                .LoadUpvalue => |index| {
                    try interpretLoadUpvalue(self, frame, index);
                },
                .StoreGlobal => |index| {
                    try interpretStoreGlobal(self, index);
                },
                .LoadGlobal => |index| {
                    try interpretLoadGlobal(self, index);
                },
                .StoreLocal => |index| {
                    try interpretStoreLocal(self, frame, index);
                },
                .LoadLocal => |index| {
                    try interpretLoadLocal(self, frame, index);
                },
                .LoadConstant => |index| {
                    try interpretLoadConstant(self, index);
                },
                .LoadObject => |index| {
                    try interpretLoadObject(self, index);
                },
                .Jump => |offset| {
                    try interpretJump(frame, offset);
                },
                .JumpIfFalse => |offset| {
                    try interpretJumpIfFalse(self, frame, offset);
                },
                .JumpBack => |offset| {
                    try interpretJumpBack(frame, offset);
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
    Function: struct { arity: u8, upvalues: usize, chunk: Chunk, name: std.ArrayList(u8) },
    Native: struct { arity: u8, function: *const fn (*VirtualMachine, usize) Value },
    Closure: struct { function: *const Object, upvalues: std.ArrayList(Object) },
    // Upvalues can point to values on the stack or to other upvalues.
    // Open upvalues are upvalues that point to values on the stack.
    // Closed upvalues are upvalues that own the values.
    Upvalue: union(enum) {
        Open: struct { location: *Value },
        // Closed: struct { location: Value },
    },

    pub fn deinit(self: *Object) void {
        switch (self.*) {
            .String => {
                self.String.deinit();
            },
            .Function => {
                self.Function.chunk.deinit();
                self.Function.name.deinit();
            },
            .Native => {},
            .Closure => {
                self.Closure.upvalues.deinit();
            },
            .Upvalue => {},
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

pub fn named_function(allocator: std.mem.Allocator, name: []const u8, arity: u8, upvalues: usize) !Object {
    var nameF = std.ArrayList(u8).init(allocator);
    for (name) |byte| {
        try nameF.append(byte);
    }
    return .{ .Function = .{ .arity = arity, .upvalues = upvalues, .chunk = Chunk.init(allocator), .name = nameF } };
}

/// A call frame can refer to a function or a closure.
/// TODO: it would really be easier to work with if we restricted it to only closures.
const CallFrame = struct { function: *Object, ip: [*]OpCode, stackBase: usize };

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
    // Turns the function on the top of the stack into a closure.
    // This instruction is followed by a list of upvalue capture instructions.
    // The number of instructions is the same as the number of upvalues.
    AsClosure,
    // Captures an upvalue.
    // Local upvalues are captured by index into the stack.
    // Non-local upvalues are captured by index into the upvalues array in the parent closure.
    CaptureUpvalue: struct { local: bool, index: usize },
    // Calls a function on the stack. The arguments are on the stack just before the function.
    Call,
    // Index into the upvalues array in the closure.
    StoreUpvalue: usize,
    // Index into the upvalues array in the closure.
    LoadUpvalue: usize,
    // Closes an upvalue by moving the value from the stack to the heap by embedding it in the upvalue object.
    // All the upvalues that precede this one in the upvalues array are also closed.
    // CloseUpvalue,
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
                .Call => {
                    std.debug.print("{x:4}    {d} call\n", .{ offset, line });
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

fn interpretJumpIfFalse(vm: *VirtualMachine, frame: *CallFrame, offset: u32) !void {
    const value = vm.stack.items[vm.stack.items.len - 1];
    if (value.falsey()) {
        // Subtract 1 because the loop will increment the instruction pointer.
        frame.ip += offset - 1;
    }
}

fn interpretJump(frame: *CallFrame, offset: u32) !void {
    // Subtracts 1 because the loop will increment the instruction pointer.
    frame.ip += offset - 1;
}

fn interpretJumpBack(frame: *CallFrame, offset: u32) !void {
    // Adds 1 because the loop will increment the instruction pointer.
    frame.ip -= offset + 1;
}

fn interpretStoreUpvalue(vm: *VirtualMachine, frame: *CallFrame, index: usize) !void {
    switch (frame.function.*) {
        .Closure => {},
        else => {
            std.debug.print("Invalid closure\n", .{});
            return error.NotAClosure;
        },
    }
    const upvalue = &frame.function.Closure.upvalues.items[index];
    switch (upvalue.*) {
        .Upvalue => |u| {
            switch (u) {
                .Open => {
                    upvalue.Upvalue.Open.location.* = vm.stack.items[vm.stack.items.len - 1];
                },
            }
        },
        else => {
            std.debug.print("Invalid upvalue\n", .{});
            return error.InvalidUpvalue;
        },
    }
}

fn interpretLoadUpvalue(vm: *VirtualMachine, frame: *CallFrame, index: usize) !void {
    const closure = switch (frame.function.*) {
        .Closure => frame.function.Closure,
        else => {
            std.debug.print("Invalid closure\n", .{});
            return error.NotAClosure;
        },
    };
    const upvalue = &closure.upvalues.items[index];
    switch (upvalue.*) {
        .Upvalue => |u| {
            switch (u) {
                .Open => {
                    try vm.stack.append(upvalue.Upvalue.Open.location.*);
                },
            }
        },
        else => {
            std.debug.print("Invalid upvalue\n", .{});
            return error.InvalidUpvalue;
        },
    }
}

/// Stores the value on top of the stack in the global variable at the given index.
/// Does not pop the value from the stack.
fn interpretStoreGlobal(vm: *VirtualMachine, index: usize) !void {
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
        else => {
            std.debug.print("Invalid global name\n", .{});
            return error.InvalidGlobalName;
        },
    };
    try vm.globals.put(name.items, vm.stack.items[vm.stack.items.len - 1]);
}

fn interpretLoadGlobal(vm: *VirtualMachine, index: usize) !void {
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
        else => {
            std.debug.print("Invalid global name\n", .{});
            return error.InvalidGlobalName;
        },
    };
    const value = vm.globals.get(name.items) orelse {
        std.debug.print("Undefined global variable\n", .{});
        return error.UndefinedGlobalVariable;
    };
    try vm.stack.append(value);
}

/// Stores the value on top of the stack in the local variable at the given index.
/// Does not pop the value from the stack.
fn interpretStoreLocal(vm: *VirtualMachine, frame: *CallFrame, index: usize) !void {
    vm.stack.items[index] = vm.stack.items[vm.stack.items.len - 1 + frame.stackBase];
}

fn interpretLoadLocal(vm: *VirtualMachine, frame: *CallFrame, index: usize) !void {
    try vm.stack.append(vm.stack.items[index + frame.stackBase]);
}

fn interpretLoadConstant(vm: *VirtualMachine, index: usize) !void {
    const v = vm.constants.items[index];
    try vm.stack.append(v);
}

fn interpretLoadObject(vm: *VirtualMachine, index: usize) !void {
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
