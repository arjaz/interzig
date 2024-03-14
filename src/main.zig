const std = @import("std");
const gc = @import("gc.zig");
const vm = @import("vm.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        _ = deinit_status;
    }
    const allocator = gpa.allocator();

    var gca = gc.GarbageCollector(.{ .stress = true, .debug = true }).init(allocator);
    defer {
        _ = gca.deinit();
    }
    const runtime_allocator = gca.allocator();

    var machine = try vm.VirtualMachine.init(allocator, runtime_allocator);
    defer machine.deinit();
    gca.link(&machine);

    const main_fn = try machine.namedFunction("main", 0, 0);
    _ = try machine.takeObjectOwnership(main_fn);
    _ = try machine.addConstant(.{ .Object = main_fn });

    // This one is garbage collected
    const test_fn = try machine.namedFunction("test", 0, 0);
    _ = try machine.takeObjectOwnership(test_fn);

    const out_string = try machine.stringFromU8Slice("I love Helga\n");
    _ = try machine.takeObjectOwnership(out_string);
    const str_index = try machine.addConstant(.{ .Object = out_string });
    const native_print = try machine.nativeFunction(1, nativePrintString);
    _ = try machine.takeObjectOwnership(native_print);
    const native_print_string_index = try machine.addConstant(.{ .Object = native_print });

    _ = try main_fn.data.Function.chunk.addInstruction(.{ .LoadConstant = str_index }, 0);
    _ = try main_fn.data.Function.chunk.addInstruction(.{ .LoadConstant = native_print_string_index }, 0);
    _ = try main_fn.data.Function.chunk.addInstruction(.Call, 0);
    _ = try main_fn.data.Function.chunk.addInstruction(.Return, 0);

    const main_frame = vm.CallFrame{ .ip = @as([*]vm.OpCode, @ptrCast(&main_fn.data.Function.chunk.code.items[0])), .function = main_fn, .stack_base = 0 };
    try machine.frames.append(main_frame);
    _ = try machine.interpret();

    machine.printStack();
    machine.printObjects();
    machine.printConstants();
    machine.printTrace();
}

fn nativePrintString(machine: *vm.VirtualMachine, arity: usize) vm.Value {
    _ = arity;
    const string_index = machine.stack.pop();
    const string = string_index.Object.data.String;
    std.debug.print("{s}", .{string.items});
    return vm.Value.Nil;
}
