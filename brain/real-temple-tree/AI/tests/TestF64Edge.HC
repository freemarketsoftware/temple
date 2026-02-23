// TestF64Edge.HC — F64 special values: infinity, NaN, overflow, underflow, casting
//
// KEY CONSTRAINT: F64 local variables inside compiled HolyC functions crash TempleOS
// (same JIT bug as typed fp local variables). All F64 state uses globals.
//
// Confirmed findings (via standalone probes):
//   FP exceptions are MASKED — 1.0/0.0 = +Inf, 0.0/0.0 = quiet NaN, no throw
//   Sqrt(-1.0) = quiet NaN (0xFFF8000000000000)
//   ToI64(Inf) = I64_MIN (x87 out-of-range result)
//   NaN == NaN → 1 (TRUE, non-IEEE — x87 unordered comparison)
//   NaN < 1.0  → 1 (TRUE, non-IEEE)
//   0.1+0.2 == 0.3 → TRUE (x87 80-bit extended precision)
//
// Called by TestRunner with shared output buffer.

F64 g_f64_inf   = 0.0;
F64 g_f64_ninf  = 0.0;
F64 g_f64_nan   = 0.0;
F64 g_f64_r     = 0.0;
I64 g_f64_bits  = 0;

U0 TestF64Edge(U8 *out) {
  U8 line[256];
  U8 *s;

  g_f64_inf  = Pow10I64(309);
  g_f64_ninf = -g_f64_inf;
  g_f64_nan  = 0.0 / 0.0;

  // --- Pow10I64(309) is IEEE 754 +Inf ---
  g_f64_bits = g_f64_inf(I64);
  if (g_f64_bits == 0x7FF0000000000000) s = "PASS"; else s = "OBS";
  StrPrint(line, "inf_bits\t%s\t%X\n", s, g_f64_bits);
  CatPrint(out, "%s", line);

  // --- Pow10I64(-309) underflows to 0.0 ---
  g_f64_r = Pow10I64(-309);
  if (g_f64_r == 0.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "underflow_zero\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Negative Inf bits ---
  g_f64_bits = g_f64_ninf(I64);
  if (g_f64_bits == 0xFFF0000000000000) s = "PASS"; else s = "OBS";
  StrPrint(line, "neg_inf_bits\t%s\t%X\n", s, g_f64_bits);
  CatPrint(out, "%s", line);

  // --- Inf > very large finite ---
  if (g_f64_inf > 1e300) s = "PASS"; else s = "FAIL";
  StrPrint(line, "inf_gt_large\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Inf == Inf ---
  if (g_f64_inf == Pow10I64(309)) s = "PASS"; else s = "FAIL";
  StrPrint(line, "inf_eq_inf\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Inf + 1.0 == Inf ---
  g_f64_r = g_f64_inf + 1.0;
  if (g_f64_r == g_f64_inf) s = "PASS"; else s = "FAIL";
  StrPrint(line, "inf_plus_one\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Inf * 2.0 == Inf ---
  g_f64_r = g_f64_inf * 2.0;
  if (g_f64_r == g_f64_inf) s = "PASS"; else s = "FAIL";
  StrPrint(line, "inf_times_two\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Overflow: 1e308 * 10.0 = Inf ---
  g_f64_r = 1e308 * 10.0;
  if (g_f64_r == g_f64_inf) s = "PASS"; else s = "OBS";
  StrPrint(line, "overflow_inf\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- FP div-by-zero: 1.0/0.0 = +Inf (exceptions masked, no throw) ---
  g_f64_r = 1.0 / 0.0;
  g_f64_bits = g_f64_r(I64);
  if (g_f64_bits == 0x7FF0000000000000) s = "PASS"; else s = "OBS";
  StrPrint(line, "fdiv_zero\t%s\t%X\n", s, g_f64_bits);
  CatPrint(out, "%s", line);

  // --- 0.0/0.0 = quiet NaN (0xFFF8000000000000) ---
  g_f64_bits = g_f64_nan(I64);
  if (g_f64_bits == 0xFFF8000000000000) s = "PASS"; else s = "OBS";
  StrPrint(line, "zero_div_zero_nan\t%s\t%X\n", s, g_f64_bits);
  CatPrint(out, "%s", line);

  // --- Sqrt(-1.0) = quiet NaN ---
  g_f64_r = Sqrt(-1.0);
  g_f64_bits = g_f64_r(I64);
  if (g_f64_bits == 0xFFF8000000000000) s = "PASS"; else s = "OBS";
  StrPrint(line, "sqrt_neg_nan\t%s\t%X\n", s, g_f64_bits);
  CatPrint(out, "%s", line);

  // --- ToI64(Inf) = I64_MIN (x87 out-of-range result) ---
  g_f64_bits = ToI64(g_f64_inf);
  StrPrint(line, "toi64_inf\tOBS\t%d\n", g_f64_bits);
  CatPrint(out, "%s", line);

  // --- NaN == NaN → 1 (non-IEEE, x87 treats as equal) ---
  StrPrint(line, "nan_eq_nan\tOBS\t%d\n", (g_f64_nan == g_f64_nan)(I64));
  CatPrint(out, "%s", line);

  // --- NaN < 1.0 → 1 (non-IEEE) ---
  StrPrint(line, "nan_lt_one\tOBS\t%d\n", (g_f64_nan < 1.0)(I64));
  CatPrint(out, "%s", line);

  // --- 0.1+0.2 == 0.3 → TRUE (x87 80-bit extended precision) ---
  g_f64_r = 0.1 + 0.2;
  StrPrint(line, "fp_precision_80bit\tOBS\t%d\n", (g_f64_r == 0.3)(I64));
  CatPrint(out, "%s", line);
}
