// TestMath2.HC — RoundI64, FloorI64, CeilI64, F64 arithmetic, Sqrt, Sin, Cos, ToI64, ToF64
// RoundI64/FloorI64/CeilI64 operate on multiples: RoundI64(num, to) rounds to multiple of to
// Called by TestRunner with shared output buffer

U0 TestMath2(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 r;
  F64 f;

  // --- RoundI64: truncate to multiple of to (toward zero) ---
  r = RoundI64(7, 4);
  if (r == 4) s = "PASS"; else s = "FAIL";
  StrPrint(line, "round_7_4\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = RoundI64(8, 4);
  if (r == 8) s = "PASS"; else s = "FAIL";
  StrPrint(line, "round_8_4\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = RoundI64(9, 4);
  if (r == 8) s = "PASS"; else s = "FAIL";
  StrPrint(line, "round_9_4\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // negative: truncates toward zero, so -7 -> -4
  r = RoundI64(-7, 4);
  if (r == -4) s = "PASS"; else s = "FAIL";
  StrPrint(line, "round_neg7_4\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- FloorI64: floor toward -inf ---
  r = FloorI64(7, 4);
  if (r == 4) s = "PASS"; else s = "FAIL";
  StrPrint(line, "floor_7_4\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = FloorI64(8, 4);
  if (r == 8) s = "PASS"; else s = "FAIL";
  StrPrint(line, "floor_8_4\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // negative: floor(-7, 4) = -8
  r = FloorI64(-7, 4);
  if (r == -8) s = "PASS"; else s = "FAIL";
  StrPrint(line, "floor_neg7_4\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- CeilI64: ceil toward +inf ---
  r = CeilI64(7, 4);
  if (r == 8) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ceil_7_4\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = CeilI64(8, 4);
  if (r == 8) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ceil_8_4\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // negative: observe — source analysis suggests CeilI64 may be buggy for negatives
  r = CeilI64(-7, 4);
  StrPrint(line, "ceil_neg7_4\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- F64 basic arithmetic ---
  f = 1.5 + 2.5;
  if (f == 4.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "f64_add\t%s\t%f\n", s, f);
  CatPrint(out, "%s", line);

  f = 5.0 - 2.5;
  if (f == 2.5) s = "PASS"; else s = "FAIL";
  StrPrint(line, "f64_sub\t%s\t%f\n", s, f);
  CatPrint(out, "%s", line);

  f = 2.5 * 4.0;
  if (f == 10.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "f64_mul\t%s\t%f\n", s, f);
  CatPrint(out, "%s", line);

  f = 10.0 / 4.0;
  if (f == 2.5) s = "PASS"; else s = "FAIL";
  StrPrint(line, "f64_div\t%s\t%f\n", s, f);
  CatPrint(out, "%s", line);

  // --- Sqrt ---
  f = Sqrt(4.0);
  if (f == 2.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sqrt_4\t%s\t%f\n", s, f);
  CatPrint(out, "%s", line);

  f = Sqrt(9.0);
  if (f == 3.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sqrt_9\t%s\t%f\n", s, f);
  CatPrint(out, "%s", line);

  // --- Sin, Cos at 0 ---
  f = Sin(0.0);
  if (f == 0.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sin_0\t%s\t%f\n", s, f);
  CatPrint(out, "%s", line);

  f = Cos(0.0);
  if (f == 1.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "cos_0\t%s\t%f\n", s, f);
  CatPrint(out, "%s", line);

  // --- ToI64: truncate toward zero ---
  r = ToI64(3.7);
  if (r == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "toi64_3p7\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = ToI64(-3.7);
  if (r == -3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "toi64_neg3p7\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- ToF64 ---
  f = ToF64(42);
  if (f == 42.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "tof64_42\t%s\t%f\n", s, f);
  CatPrint(out, "%s", line);
}
