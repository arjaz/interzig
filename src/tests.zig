const std = @import("std");
const main = @import("main.zig");

test "add i64 constant" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();
    const index = try vm.addConstant(.{ .I64 = 42 });
    try std.testing.expectEqual(@as(usize, 1), vm.constants.items.len);
    try std.testing.expectEqual(@as(i64, 42), vm.constants.items[index].I64);
}

test "add return instruction" {
    var chunk = main.Chunk.init(std.testing.allocator);
    defer chunk.deinit();
    _ = try chunk.addInstruction(.Return, 0);
    try std.testing.expectEqual(@as(usize, 1), chunk.code.items.len);
    try std.testing.expectEqual(main.OpCode.Return, chunk.code.items[0]);
}

test "interpret return" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const nil = try vm.addConstant(.Nil);

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    _ = try chunk.addInstruction(.{ .LoadConstant = nil }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.Nil, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret constant" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index = try vm.addConstant(.{ .I64 = 42 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value{ .I64 = 42 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret 1 + 2" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .I64 = 2 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value{ .I64 = 3 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret 1 - 2" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .I64 = 2 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Sub, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value{ .I64 = -1 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret 10u64 - 7u64" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index1 = try vm.addConstant(.{ .U64 = 10 });
    const index2 = try vm.addConstant(.{ .U64 = 7 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Sub, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value{ .U64 = 3 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret not(nil)" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index = try vm.addConstant(.Nil);
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret not(10.7)" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index = try vm.addConstant(.{ .F64 = 10.7 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.Nil, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret (1 + 2.5) results in type mismatch" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .F64 = 2.5 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    _ = vm.interpret() catch |err| {
        try std.testing.expectEqual(err, error.TypeMismatch);
        return;
    };
    try std.testing.expect(false);
}

test "interpret set global" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const indexTrue = try vm.addConstant(.True);
    const fnName = try vm.string_from_u8_slice("nice");
    const globalConstantIndex = try vm.addConstant(.{ .Object = fnName });
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .StoreGlobal = globalConstantIndex }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
    try std.testing.expectEqual(@as(?main.Value, .True), vm.globals.get("nice"));
}

test "interpret read global" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const indexTrue = try vm.addConstant(.True);
    const fnName = try vm.string_from_u8_slice("nice");
    const globalConstantIndex = try vm.addConstant(.{ .Object = fnName });
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .StoreGlobal = globalConstantIndex }, 0);
    _ = try chunk.addInstruction(.Pop, 0);
    _ = try chunk.addInstruction(.{ .LoadGlobal = globalConstantIndex }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret jump over one instruction" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const indexTrue = try vm.addConstant(.True);
    _ = try chunk.addInstruction(.{ .Jump = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    _ = try vm.interpret();
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret jump if false with nil on the stack" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const indexNil = try vm.addConstant(.Nil);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexNil }, 0);
    _ = try chunk.addInstruction(.{ .JumpIfFalse = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexNil }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    _ = try vm.interpret();
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret jump if false with true on the stack" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    const indexTrue = try vm.addConstant(.True);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.{ .JumpIfFalse = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    _ = try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
}

test "interpret jump back" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const nilIndex = try vm.addConstant(.Nil);
    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const chunk = &mainFn.Function.chunk;
    _ = try chunk.addInstruction(.{ .Jump = 3 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = nilIndex }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    _ = try chunk.addInstruction(.{ .JumpBack = 2 }, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &chunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.Nil, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret fn call" {
    // For this we will have a simple function that just returns true.
    // We will call it from main and expect the result to be true.
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const indexTrue = try vm.addConstant(.True);

    const justTrueFnIndex = try vm.addObject(try vm.named_function("justTrue", 0, 0));
    const justTrueFn = vm.objects.items[justTrueFnIndex];
    const justTrueChunk = &justTrueFn.Function.chunk;
    _ = try justTrueChunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try justTrueChunk.addInstruction(.Return, 0);

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadObject = justTrueFnIndex }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret closure call" {
    // For this we will have a simple function that just returns true.
    // We will call it from main and expect the result to be true.
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const indexTrue = try vm.addConstant(.True);

    const justTrueFnIndex = try vm.addObject(try vm.named_function("justTrue", 0, 0));
    const justTrueFn = vm.objects.items[justTrueFnIndex];
    const justTrueChunk = &justTrueFn.Function.chunk;
    _ = try justTrueChunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try justTrueChunk.addInstruction(.Return, 0);

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadObject = justTrueFnIndex }, 0);
    _ = try mainChunk.addInstruction(.AsClosure, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret closure call with an open local upmain.Value" {
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
    //   load upmain.Value 0
    //   return
    // main:
    //   load true
    //   load justTrue
    //   as closure
    //   capture local 0
    //   call
    //   return
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const indexTrue = try vm.addConstant(.True);

    const justTrueFnIndex = try vm.addObject(try vm.named_function("justTrue", 0, 1));
    const justTrueFn = vm.objects.items[justTrueFnIndex];
    const justTrueChunk = &justTrueFn.Function.chunk;
    _ = try justTrueChunk.addInstruction(.{ .LoadUpvalue = 0 }, 0);
    _ = try justTrueChunk.addInstruction(.Return, 0);

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try mainChunk.addInstruction(.{ .LoadObject = justTrueFnIndex }, 0);
    _ = try mainChunk.addInstruction(.AsClosure, 0);
    _ = try mainChunk.addInstruction(.{ .CaptureUpvalue = .{ .local = true, .index = 0 } }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.True, result);
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
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const indexTrue = try vm.addConstant(.True);

    const justTrue2FnIndex = try vm.addObject(try vm.named_function("justTrue2", 0, 1));
    const justTrue2Fn = vm.objects.items[justTrue2FnIndex];
    const justTrue2Chunk = &justTrue2Fn.Function.chunk;
    _ = try justTrue2Chunk.addInstruction(.{ .LoadUpvalue = 0 }, 0);
    _ = try justTrue2Chunk.addInstruction(.Return, 0);

    const justTrueFnIndex = try vm.addObject(try vm.named_function("justTrue", 0, 1));
    const justTrueFn = vm.objects.items[justTrueFnIndex];
    const justTrueChunk = &justTrueFn.Function.chunk;
    _ = try justTrueChunk.addInstruction(.{ .LoadObject = justTrue2FnIndex }, 0);
    _ = try justTrueChunk.addInstruction(.AsClosure, 0);
    _ = try justTrueChunk.addInstruction(.{ .CaptureUpvalue = .{ .local = false, .index = 0 } }, 0);
    _ = try justTrueChunk.addInstruction(.Call, 0);
    _ = try justTrueChunk.addInstruction(.Return, 0);

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try mainChunk.addInstruction(.{ .LoadObject = justTrueFnIndex }, 0);
    _ = try mainChunk.addInstruction(.AsClosure, 0);
    _ = try mainChunk.addInstruction(.{ .CaptureUpvalue = .{ .local = true, .index = 0 } }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.True, result);
    // the stack is not empty because we have one local variable in main.
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
}

test "interpret closure call with a closed upvalue" {
    // fn justTrueFn() {
    //     let a = true;
    //     fn justTrue() {
    //         return a;
    //     }
    //     return justTrue2Fn;
    // }
    //
    // fn main() {
    //     let justTrueFn = justTrueFn();
    //     return justTrueFn();
    // }
    //
    // justTrue:
    //   load upvalue 0
    //   return
    // justTrueFn:
    //   load true
    //   load justTrue
    //   as closure
    //   capture local 0
    //   return
    // main:
    //   load justTrueFn
    //   call
    //   call
    //   return
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const indexTrue = try vm.addConstant(.True);

    const justTrueFnIndex = try vm.addObject(try vm.named_function("justTrue", 0, 1));
    const justTrueFn = vm.objects.items[justTrueFnIndex];
    const justTrueChunk = &justTrueFn.Function.chunk;
    _ = try justTrueChunk.addInstruction(.{ .LoadUpvalue = 0 }, 0);
    _ = try justTrueChunk.addInstruction(.Return, 0);

    const justTrue2FnIndex = try vm.addObject(try vm.named_function("justTrueFn", 0, 0));
    const justTrue2Fn = vm.objects.items[justTrue2FnIndex];
    const justTrue2Chunk = &justTrue2Fn.Function.chunk;
    _ = try justTrue2Chunk.addInstruction(.{ .LoadConstant = indexTrue }, 0);
    _ = try justTrue2Chunk.addInstruction(.{ .LoadObject = justTrueFnIndex }, 0);
    _ = try justTrue2Chunk.addInstruction(.AsClosure, 0);
    _ = try justTrue2Chunk.addInstruction(.{ .CaptureUpvalue = .{ .local = true, .index = 0 } }, 0);
    _ = try justTrue2Chunk.addInstruction(.Return, 0);

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadObject = justTrue2FnIndex }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret calling 1" {
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();

    const oneIndex = try vm.addConstant(.{ .U64 = 1 });

    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadConstant = oneIndex }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    _ = vm.interpret() catch |err| {
        try std.testing.expectEqual(err, error.TypeMismatch);
        return;
    };
    try std.testing.expect(false);
}

fn nativeFnTest(vm: *main.VirtualMachine, arity: usize) main.Value {
    var i: usize = 0;
    while (i < arity) : (i += 1) {
        _ = vm.stack.pop();
    }
    return .True;
}

test "interpret native fn call" {
    // A simple function that accepts one argument and returns main.Value.True.
    var vm = try main.VirtualMachine.init(std.testing.allocator);
    defer vm.deinit();
    const oneIndex = try vm.addConstant(.{ .U64 = 1 });

    var nativeFn = try std.testing.allocator.create(main.Object);
    nativeFn.* = .{ .Native = .{
        .arity = 1,
        .function = &nativeFnTest,
    } };

    const nativeFnIndex = try vm.addObject(nativeFn);
    const mainFnIndex = try vm.addObject(try vm.named_function("main", 0, 0));
    const mainFn = vm.objects.items[mainFnIndex];
    const mainChunk = &mainFn.Function.chunk;
    _ = try mainChunk.addInstruction(.{ .LoadConstant = oneIndex }, 0);
    _ = try mainChunk.addInstruction(.{ .LoadObject = nativeFnIndex }, 0);
    _ = try mainChunk.addInstruction(.Call, 0);
    _ = try mainChunk.addInstruction(.Return, 0);

    const frame = main.CallFrame{ .ip = @ptrCast([*]main.OpCode, &mainChunk.code.items[0]), .function = mainFn, .stackBase = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(main.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}
