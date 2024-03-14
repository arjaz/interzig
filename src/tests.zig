const std = @import("std");
const main = @import("main.zig");
const machine = @import("vm.zig");
const gc = @import("gc.zig");

test "add i64 constant" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());
    defer vm.deinit();
    gca.link(&vm);
    const index = try vm.addConstant(.{ .I64 = 42 });
    try std.testing.expectEqual(@as(usize, 1), vm.constants.items.len);
    try std.testing.expectEqual(@as(i64, 42), vm.constants.items[index].I64);
}

test "add return instruction" {
    var chunk = machine.Chunk.init(std.testing.allocator);
    defer chunk.deinit();
    _ = try chunk.addInstruction(.Return, 0);
    try std.testing.expectEqual(@as(usize, 1), chunk.code.items.len);
    try std.testing.expectEqual(machine.OpCode.Return, chunk.code.items[0]);
}

test "interpret return" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const nil = try vm.addConstant(.Nil);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    _ = try chunk.addInstruction(.{ .LoadConstant = nil }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.Nil, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret constant" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const index = try vm.addConstant(.{ .I64 = 42 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value{ .I64 = 42 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret 1 + 2" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .I64 = 2 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value{ .I64 = 3 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret 1 - 2" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .I64 = 2 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Sub, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value{ .I64 = -1 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret 10u64 - 7u64" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const index1 = try vm.addConstant(.{ .U64 = 10 });
    const index2 = try vm.addConstant(.{ .U64 = 7 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Sub, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value{ .U64 = 3 }, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret not(nil)" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const index = try vm.addConstant(.Nil);
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret not(10.7)" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const index = try vm.addConstant(.{ .F64 = 10.7 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index }, 0);
    _ = try chunk.addInstruction(.Not, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.Nil, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret (1 + 2.5) results in type mismatch" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const index1 = try vm.addConstant(.{ .I64 = 1 });
    const index2 = try vm.addConstant(.{ .F64 = 2.5 });
    _ = try chunk.addInstruction(.{ .LoadConstant = index1 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = index2 }, 0);
    _ = try chunk.addInstruction(.Add, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    _ = vm.interpret() catch |err| {
        try std.testing.expectEqual(err, machine.TypeMismatchError);
        return;
    };
    try std.testing.expect(false);
}

test "interpret set global" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const true_index = try vm.addConstant(.True);
    const fn_name = try vm.stringFromU8Slice("nice");
    try vm.takeObjectOwnership(fn_name);
    const global_constant_index = try vm.addConstant(.{ .Object = fn_name });
    _ = try chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try chunk.addInstruction(.{ .StoreGlobal = global_constant_index }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
    try std.testing.expectEqual(@as(?machine.Value, .True), vm.globals.get(fn_name));
}

test "interpret read global" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const true_index = try vm.addConstant(.True);
    const fn_name = try vm.stringFromU8Slice("nice");
    try vm.takeObjectOwnership(fn_name);
    const global_constant_index = try vm.addConstant(.{ .Object = fn_name });
    _ = try chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try chunk.addInstruction(.{ .StoreGlobal = global_constant_index }, 0);
    _ = try chunk.addInstruction(.Pop, 0);
    _ = try chunk.addInstruction(.{ .LoadGlobal = global_constant_index }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret jump over one instruction" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const true_index = try vm.addConstant(.True);
    _ = try chunk.addInstruction(.{ .Jump = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    _ = try vm.interpret();
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret jump if false with nil on the stack" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const nil_index = try vm.addConstant(.Nil);
    _ = try chunk.addInstruction(.{ .LoadConstant = nil_index }, 0);
    _ = try chunk.addInstruction(.{ .JumpIfFalse = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = nil_index }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    _ = try vm.interpret();
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret jump if false with true on the stack" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    const true_index = try vm.addConstant(.True);
    _ = try chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try chunk.addInstruction(.{ .JumpIfFalse = 2 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    _ = try vm.interpret();
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
}

test "interpret jump back" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const nil_index = try vm.addConstant(.Nil);
    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const chunk = &main_fn.data.Function.chunk;
    _ = try chunk.addInstruction(.{ .Jump = 3 }, 0);
    _ = try chunk.addInstruction(.{ .LoadConstant = nil_index }, 0);
    _ = try chunk.addInstruction(.Return, 0);
    _ = try chunk.addInstruction(.{ .JumpBack = 2 }, 0);

    const frame = machine.CallFrame{
        .ip = @as([*]machine.OpCode, @ptrCast(&chunk.code.items[0])),
        .function = main_fn,
        .stack_base = 0,
    };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.Nil, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret fn call" {
    // For this we will have a simple function that just returns true.
    // We will call it from main and expect the result to be true.
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const true_index = try vm.addConstant(.True);

    const just_true_fn_object = try vm.namedFunction("justTrue", 0, 0);
    try vm.takeObjectOwnership(just_true_fn_object);
    const just_true_fn_index = try vm.addConstant(.{ .Object = just_true_fn_object });
    const just_true_fn = vm.constants.items[just_true_fn_index].Object;
    const just_true_chunk = &just_true_fn.data.Function.chunk;
    _ = try just_true_chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try just_true_chunk.addInstruction(.Return, 0);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const main_chunk = &main_fn.data.Function.chunk;
    _ = try main_chunk.addInstruction(.{ .LoadConstant = just_true_fn_index }, 0);
    _ = try main_chunk.addInstruction(.Call, 0);
    _ = try main_chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&main_chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret closure call" {
    // For this we will have a simple function that just returns true.
    // We will call it from main and expect the result to be true.
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const true_index = try vm.addConstant(.True);

    const just_true_fn_object = try vm.namedFunction("justTrue", 0, 0);
    try vm.takeObjectOwnership(just_true_fn_object);
    const just_true_fn_index = try vm.addConstant(.{ .Object = just_true_fn_object });
    const just_true_fn = vm.constants.items[just_true_fn_index].Object;
    const just_true_chunk = &just_true_fn.data.Function.chunk;
    _ = try just_true_chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try just_true_chunk.addInstruction(.Return, 0);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const main_chunk = &main_fn.data.Function.chunk;
    _ = try main_chunk.addInstruction(.{ .LoadConstant = just_true_fn_index }, 0);
    _ = try main_chunk.addInstruction(.AsClosure, 0);
    _ = try main_chunk.addInstruction(.Call, 0);
    _ = try main_chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&main_chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.True, result);
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
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const true_index = try vm.addConstant(.True);

    const just_true_fn_object = try vm.namedFunction("justTrue", 0, 1);
    try vm.takeObjectOwnership(just_true_fn_object);
    const just_true_fn_index = try vm.addConstant(.{ .Object = just_true_fn_object });
    const just_true_fn = vm.constants.items[just_true_fn_index].Object;
    const just_true_chunk = &just_true_fn.data.Function.chunk;
    _ = try just_true_chunk.addInstruction(.{ .LoadUpvalue = 0 }, 0);
    _ = try just_true_chunk.addInstruction(.Return, 0);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const main_chunk = &main_fn.data.Function.chunk;
    _ = try main_chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try main_chunk.addInstruction(.{ .LoadConstant = just_true_fn_index }, 0);
    _ = try main_chunk.addInstruction(.AsClosure, 0);
    _ = try main_chunk.addInstruction(.{ .CaptureUpvalue = .{ .local = true, .index = 0 } }, 0);
    _ = try main_chunk.addInstruction(.Call, 0);
    _ = try main_chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&main_chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.True, result);
    // the stack is not empty because we have one local variable in machine.
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
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const true_index = try vm.addConstant(.True);

    const just_true2_fn_object = try vm.namedFunction("justTrue2", 0, 1);
    try vm.takeObjectOwnership(just_true2_fn_object);
    const just_true2_fn_index = try vm.addConstant(.{ .Object = just_true2_fn_object });
    const just_true2_fn = vm.constants.items[just_true2_fn_index].Object;
    const just_true2_chunk = &just_true2_fn.data.Function.chunk;
    _ = try just_true2_chunk.addInstruction(.{ .LoadUpvalue = 0 }, 0);
    _ = try just_true2_chunk.addInstruction(.Return, 0);

    const just_true_fn_object = try vm.namedFunction("justTrue", 0, 1);
    try vm.takeObjectOwnership(just_true_fn_object);
    const just_true_fn_index = try vm.addConstant(.{ .Object = just_true_fn_object });
    const just_true_fn = vm.constants.items[just_true_fn_index].Object;
    const just_true_chunk = &just_true_fn.data.Function.chunk;
    _ = try just_true_chunk.addInstruction(.{ .LoadConstant = just_true2_fn_index }, 0);
    _ = try just_true_chunk.addInstruction(.AsClosure, 0);
    _ = try just_true_chunk.addInstruction(.{ .CaptureUpvalue = .{ .local = false, .index = 0 } }, 0);
    _ = try just_true_chunk.addInstruction(.Call, 0);
    _ = try just_true_chunk.addInstruction(.Return, 0);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const main_chunk = &main_fn.data.Function.chunk;
    _ = try main_chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try main_chunk.addInstruction(.{ .LoadConstant = just_true_fn_index }, 0);
    _ = try main_chunk.addInstruction(.AsClosure, 0);
    _ = try main_chunk.addInstruction(.{ .CaptureUpvalue = .{ .local = true, .index = 0 } }, 0);
    _ = try main_chunk.addInstruction(.Call, 0);
    _ = try main_chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&main_chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.True, result);
    // the stack is not empty because we have one local variable in machine.
    try std.testing.expectEqual(@as(usize, 1), vm.stack.items.len);
}

test "interpret closure call with a closed upvalue" {
    // fn justTrueFn() {
    //     let a = true;
    //     fn justTrue() {
    //         return a;
    //     }
    //     return justTrue;
    // }
    //
    // fn main() {
    //     let just_true_fn = justTrueFn();
    //     return just_true_fn();
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
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const true_index = try vm.addConstant(.True);

    const just_true_fn_object = try vm.namedFunction("just_true_fn", 0, 1);
    try vm.takeObjectOwnership(just_true_fn_object);
    const just_true_fn_index = try vm.addConstant(.{ .Object = just_true_fn_object });
    const just_true_fn = vm.constants.items[just_true_fn_index].Object;
    const just_true_chunk = &just_true_fn.data.Function.chunk;
    _ = try just_true_chunk.addInstruction(.{ .LoadUpvalue = 0 }, 0);
    _ = try just_true_chunk.addInstruction(.Return, 0);

    const just_true2_fn_object = try vm.namedFunction("just_true2_fn", 0, 0);
    try vm.takeObjectOwnership(just_true2_fn_object);
    const just_true2_fn_index = try vm.addConstant(.{ .Object = just_true2_fn_object });
    const just_true2_fn = vm.constants.items[just_true2_fn_index].Object;
    const just_true2_chunk = &just_true2_fn.data.Function.chunk;
    _ = try just_true2_chunk.addInstruction(.{ .LoadConstant = true_index }, 0);
    _ = try just_true2_chunk.addInstruction(.{ .LoadConstant = just_true_fn_index }, 0);
    _ = try just_true2_chunk.addInstruction(.AsClosure, 0);
    _ = try just_true2_chunk.addInstruction(.{ .CaptureUpvalue = .{ .local = true, .index = 0 } }, 0);
    _ = try just_true2_chunk.addInstruction(.Return, 0);

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const main_chunk = &main_fn.data.Function.chunk;
    _ = try main_chunk.addInstruction(.{ .LoadConstant = just_true2_fn_index }, 0);
    _ = try main_chunk.addInstruction(.Call, 0);
    _ = try main_chunk.addInstruction(.Call, 0);
    _ = try main_chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&main_chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret calling 1" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const one_index = try vm.addConstant(.{ .U64 = 1 });

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const main_chunk = &main_fn.data.Function.chunk;
    _ = try main_chunk.addInstruction(.{ .LoadConstant = one_index }, 0);
    _ = try main_chunk.addInstruction(.Call, 0);
    _ = try main_chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&main_chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    _ = vm.interpret() catch |err| {
        try std.testing.expectEqual(err, error.TypeMismatch);
        return;
    };
    try std.testing.expect(false);
}

fn nativeFnTest(vm: *machine.VirtualMachine, arity: usize) machine.Value {
    var i: usize = 0;
    while (i < arity) : (i += 1) {
        _ = vm.stack.pop();
    }
    return .True;
}

test "interpret native fn call" {
    // A simple function that accepts one argument and returns machine.Value.True.
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);
    const one_index = try vm.addConstant(.{ .U64 = 1 });

    const native = try vm.runtime_allocator.create(machine.Object);
    native.* = machine.Object.native(1, &nativeFnTest);
    try vm.takeObjectOwnership(native);

    const native_index = try vm.addConstant(.{ .Object = native });
    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const main_chunk = &main_fn.data.Function.chunk;
    _ = try main_chunk.addInstruction(.{ .LoadConstant = one_index }, 0);
    _ = try main_chunk.addInstruction(.{ .LoadConstant = native_index }, 0);
    _ = try main_chunk.addInstruction(.Call, 0);
    _ = try main_chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&main_chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    const result = try vm.interpret();
    try std.testing.expectEqual(machine.Value.True, result);
    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
}

test "interpret collecting an unused function" {
    var gca = gc.GarbageCollector(.{ .stress = true, .debug = false }).init(std.testing.allocator);
    defer {
        _ = gca.deinit();
    }
    var vm = try machine.VirtualMachine.init(std.testing.allocator, gca.allocator());

    defer vm.deinit();
    gca.link(&vm);

    const collected_fn_object = try vm.namedFunction("unused", 0, 0);
    try vm.takeObjectOwnership(collected_fn_object);

    const one_index = try vm.addConstant(.{ .U64 = 1 });

    const main_fn_object = try vm.namedFunction("main", 0, 0);
    try vm.takeObjectOwnership(main_fn_object);
    const main_fn_index = try vm.addConstant(.{ .Object = main_fn_object });
    const main_fn = vm.constants.items[main_fn_index].Object;
    const main_chunk = &main_fn.data.Function.chunk;
    _ = try main_chunk.addInstruction(.{ .LoadConstant = one_index }, 0);
    _ = try main_chunk.addInstruction(.Return, 0);

    const frame = machine.CallFrame{ .ip = @as([*]machine.OpCode, @ptrCast(&main_chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try vm.frames.append(frame);
    _ = try vm.interpret();

    try std.testing.expectEqual(@as(usize, 0), vm.stack.items.len);
    // The only object is the main function => the unused one was collected
    try std.testing.expectEqual(@as(usize, 1), vm.objects.len());
}
