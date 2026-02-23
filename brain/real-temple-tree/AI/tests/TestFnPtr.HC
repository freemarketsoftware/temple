// TestFnPtr.HC — HolyC function pointer behavior
// Declaration, address-of, call, args, return value, struct field,
// global storage, reassignment, passing as arg, null call
// Called by TestRunner with shared output buffer
//
// NOTE: HolyC does NOT support typed function pointer local variables
// inside function bodies (e.g. I64 (*fp)(I64 x) = &Fn;).
// Workaround: declare all function pointer variables at global scope,
// then assign and call them from inside functions.

// --- Helper functions ---

U0 FpVoid() {
  // does nothing
}

I64 FpDouble(I64 x) {
  return x * 2;
}

I64 FpAdd(I64 a, I64 b) {
  return a + b;
}

I64 FpSquare(I64 x) {
  return x * x;
}

// --- Helper that calls a function pointer passed as argument ---
I64 FpApply(I64 (*fp)(I64 x), I64 val) {
  return (*fp)(val);
}

// --- Global function pointers ---
// fp locals in functions are unsupported; all fp vars must be global
I64 (*g_fp_void)()         = 0;
I64 (*g_fp1)(I64 x)        = 0;
I64 (*g_fp2)(I64 a, I64 b) = 0;
I64 (*g_fp3)(I64 x)        = 0;
I64 (*g_fp4)(I64 x)        = 0;
I64 (*g_fn)(I64 x)         = 0;
I64 (*g_fp5)(I64 x)        = 0;

// --- Struct with function pointer field ---
class TFnStruct {
  I64 (*op)(I64 a, I64 b);
  I64 data;
};

// --- Test function ---

U0 TestFnPtr(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 r;

  // --- 1. Declare and call void function pointer ---
  g_fp_void = &FpVoid;
  (*g_fp_void)();
  s = "PASS";  // survived the call
  StrPrint(line, "fp_void_call\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 2. Function pointer with one arg, check return ---
  g_fp1 = &FpDouble;
  r = (*g_fp1)(21);
  if (r == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_one_arg\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 3. Function pointer with two args ---
  g_fp2 = &FpAdd;
  r = (*g_fp2)(10, 32);
  if (r == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_two_args\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 4. Reassign pointer to different function ---
  g_fp3 = &FpDouble;
  r = (*g_fp3)(5);
  if (r == 10) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_reassign_before\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  g_fp3 = &FpSquare;
  r = (*g_fp3)(5);
  if (r == 25) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_reassign_after\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 5. Compare pointer to function address ---
  g_fp4 = &FpDouble;
  if (g_fp4 == &FpDouble) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_compare_eq\t%s\t\n", s);
  CatPrint(out, "%s", line);

  if (g_fp4 != &FpSquare) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_compare_neq\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 6. Store in global, call via global ---
  g_fn = &FpSquare;
  r = (*g_fn)(7);
  if (r == 49) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_global\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 7. Function pointer in struct field ---
  TFnStruct fs;
  fs.op = &FpAdd;
  fs.data = 99;
  r = (*fs.op)(8, 34);
  if (r == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_struct_field\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 8. Pass function pointer as argument ---
  r = FpApply(&FpDouble, 6);
  if (r == 12) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_as_arg_double\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = FpApply(&FpSquare, 6);
  if (r == 36) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_as_arg_square\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 9. Call without dereference syntax: fp(args) ---
  g_fp5 = &FpDouble;
  r = g_fp5(10);
  if (r == 20) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fp_call_no_deref\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // NOTE: Null function pointer call NOT tested here —
  // calling (*fp)(x) where fp=0 causes a #PF kernel panic.
  // TempleOS does not route page faults through try/catch. OS dies immediately.
}
