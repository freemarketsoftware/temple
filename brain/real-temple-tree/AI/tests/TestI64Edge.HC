// TestI64Edge.HC — I64 arithmetic edge cases
// I64_MAX/MIN, overflow, underflow, negation, AbsI64, division extremes
// Called by TestRunner with shared output buffer

U0 TestI64Edge(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 r;
  I64 vmax = 0x7FFFFFFFFFFFFFFF;   // I64_MAX
  I64 vmin = -0x8000000000000000;  // I64_MIN

  // --- 1. I64_MAX correct value ---
  if (vmax == I64_MAX) s = "PASS"; else s = "FAIL";
  StrPrint(line, "i64_max_value\t%s\t%d\n", s, vmax);
  CatPrint(out, "%s", line);

  // --- 2. I64_MIN correct value ---
  if (vmin == I64_MIN) s = "PASS"; else s = "FAIL";
  StrPrint(line, "i64_min_value\t%s\t%d\n", s, vmin);
  CatPrint(out, "%s", line);

  // --- 3. I64_MAX + 1 wraps to I64_MIN (2's complement) ---
  r = vmax + 1;
  StrPrint(line, "max_plus_one\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- 4. I64_MIN - 1 wraps to I64_MAX ---
  r = vmin - 1;
  StrPrint(line, "min_minus_one\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- 5. I64_MAX * 2 overflow ---
  r = vmax * 2;
  StrPrint(line, "max_times_two\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- 6. Negate I64_MIN — stays I64_MIN in 2's complement ---
  r = -vmin;
  StrPrint(line, "negate_min\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- 7. AbsI64(I64_MIN) — can't represent as positive ---
  r = AbsI64(vmin);
  StrPrint(line, "abs_i64_min\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- 8. AbsI64(I64_MAX) == I64_MAX ---
  r = AbsI64(vmax);
  if (r == vmax) s = "PASS"; else s = "FAIL";
  StrPrint(line, "abs_i64_max\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 9. AbsI64(-1) == 1 ---
  r = AbsI64(-1);
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "abs_neg1\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 10. -1 >> 63 — arithmetic right shift, expect -1 ---
  r = -1 >> 63;
  if (r == -1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sar_neg1_63\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 11. I64_MIN >> 1 — arithmetic right shift, halves toward -inf ---
  r = vmin >> 1;
  StrPrint(line, "sar_min_1\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- 12. 0 / 0 caught as DivZero ---
  s = "FAIL";
  try {
    I64 z = 0;
    r = z / z;
  } catch {
    if (Fs->except_ch == 'DivZero') s = "PASS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "zero_div_zero\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 13. I64_MIN / -1 — x86 division overflow, expect exception ---
  s = "FAIL";
  try {
    I64 neg1 = -1;
    r = vmin / neg1;
  } catch {
    s = "OBS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "min_div_neg1\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 14. I64_MAX / 1 == I64_MAX ---
  r = vmax / 1;
  if (r == vmax) s = "PASS"; else s = "FAIL";
  StrPrint(line, "max_div_one\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 15. Large multiply: I64_MAX * I64_MAX overflow ---
  r = vmax * vmax;
  StrPrint(line, "max_times_max\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);
}
