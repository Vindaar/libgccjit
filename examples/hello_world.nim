## This is the first example from the `libgccjit` documentation here:
## https://gcc.gnu.org/onlinedocs/jit/intro/tutorial01.html

import ../libgccjit

proc createCode(ctx: ptr gcc_jit_context) =
  #[ Let's try to inject the equivalent of:
     void
     greet (const char *name)
     {
        printf ("hello %s\n", name);
     }
  ]#
  let voidType = gcc_jit_context_get_type(ctx, GCC_JIT_TYPE_VOID)
  let const_char_ptr_type = gcc_jit_context_get_type(ctx, GCC_JIT_TYPE_CONST_CHAR_PTR)
  let param_name = gcc_jit_context_new_param(ctx, nil, const_char_ptr_type, "name")
  let fn = gcc_jit_context_new_function(ctx, nil,
                                        GCC_JIT_FUNCTION_EXPORTED,
                                        void_type,
                                        "greet",
                                        1, param_name.addr,
                                        0)

  let param_format = gcc_jit_context_new_param(ctx, nil, const_char_ptr_type, "format")
  let printf_func = gcc_jit_context_new_function(ctx, nil,
                                                 GCC_JIT_FUNCTION_IMPORTED,
                                                 gcc_jit_context_get_type(ctx, GCC_JIT_TYPE_INT),
                                                 "printf",
                                                 1, param_format.addr,
                                                 1)
  var args: array[2, ptr gcc_jit_rvalue]
  args[0] = (gcc_jit_context_new_string_literal(ctx, "hello %s\n"))
  args[1] = (gcc_jit_param_as_rvalue(param_name))

  let blck = gcc_jit_function_new_block(fn, nil)

  gcc_jit_block_add_eval(
    blck, nil,
    gcc_jit_context_new_call(ctx,
                             nil,
                             printf_func,
                             2, args[0].addr))
  gcc_jit_block_end_with_void_return(blck, nil)

import std/syncio
proc main(): int =
  var ctx: ptr gcc_jit_context
  var res: ptr gcc_jit_result

  # Get a "context" object for working with the library.  */
  ctx = gcc_jit_context_acquire()
  if ctx.isNil:
    echo "nil ctx"
    return 1

  # Set some options on the context.
  #  Let's see the code being generated, in assembler form.  */
  gcc_jit_context_set_bool_option(
    ctx,
    GCC_JIT_BOOL_OPTION_DUMP_GENERATED_CODE,
    0)

  # Populate the context.  */
  create_code(ctx)

  # Compile the code.  */
  res = gcc_jit_context_compile(ctx)
  if res.isNil:
    echo "nil result"
    return 1
  # Extract the generated code from "result".
  type
    fnType = proc(c: cstring) {.nimcall.}
  var greet = cast[fnType](gcc_jit_result_get_code(res, "greet"))
  if greet.isNil:
    echo "nil greet"
    return 1
  # Now call the generated function: */
  greet("world")
  stdout.flushFile()

  gcc_jit_context_release(ctx)
  gcc_jit_result_release(res)

when isMainModule:
  echo main()
