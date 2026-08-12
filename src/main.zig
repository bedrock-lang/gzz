const std = @import("std");
const gcc = @import("libgcc.zig");

pub fn main() !void {
    const ctxt = gcc.gcc_jit_context_acquire();
    if (ctxt == null) {
        return error.ContextAcquireFailed;
    }

    defer gcc.gcc_jit_context_release(ctxt);

    // Dump generated code.
    gcc.gcc_jit_context_set_bool_option(ctxt, gcc.GCC_JIT_BOOL_OPTION_DUMP_GENERATED_CODE, 0);

    const void_type = gcc.gcc_jit_context_get_type(ctxt, gcc.GCC_JIT_TYPE_VOID);

    const const_char_ptr_type = gcc.gcc_jit_context_get_type(ctxt, gcc.GCC_JIT_TYPE_CONST_CHAR_PTR);

    var param_name = gcc.gcc_jit_context_new_param(ctxt, null, const_char_ptr_type, "name");

    const func = gcc.gcc_jit_context_new_function(
        ctxt,
        null,
        gcc.GCC_JIT_FUNCTION_EXPORTED,
        void_type,
        "greet",
        1,
        &param_name,
        0,
    );

    var param_format = gcc.gcc_jit_context_new_param(ctxt, null, const_char_ptr_type, "format");

    const int_type = gcc.gcc_jit_context_get_type(ctxt, gcc.GCC_JIT_TYPE_INT);

    const printf_func = gcc.gcc_jit_context_new_function(
        ctxt,
        null,
        gcc.GCC_JIT_FUNCTION_IMPORTED,
        int_type,
        "printf",
        1,
        &param_format,
        1,
    );

    var args: [2]?*gcc.gcc_jit_rvalue = undefined;

    args[0] = gcc.gcc_jit_context_new_string_literal(ctxt, "hello %s\n").?;

    args[1] = gcc.gcc_jit_param_as_rvalue(param_name).?;

    const block = gcc.gcc_jit_function_new_block(func, null);

    gcc.gcc_jit_block_add_eval(
        block,
        null,
        gcc.gcc_jit_context_new_call(ctxt, null, printf_func, 2, &args),
    );

    gcc.gcc_jit_block_end_with_void_return(block, null);

    const result = gcc.gcc_jit_context_compile(ctxt);

    if (result == null) {
        return error.CompilationFailed;
    }

    defer gcc.gcc_jit_result_release(result);

    const code = gcc.gcc_jit_result_get_code(result, "greet");

    if (code == null) {
        return error.GreetNotFound;
    }

    const GreetFn = *const fn ([*c]const u8) callconv(.c) void;

    const greet: GreetFn = @ptrCast(@alignCast(code.?));

    greet("world");
}
