// TestIntMath.HC — Unit tests for integer math functions
// Tests: AbsI64, MinI64, MaxI64, SignI64, ClampI64, I64_MAX/MIN, overflow
// Results written to C:/AI/results/TestIntMath.txt as TSV
// Run via: #include "C:/AI/tests/TestIntMath.HC";

U0 TestIntMath() {
  U8 out[4096];
  U8 line[128];
  U8 *s;
  I64 r;

  Del("C:/AI/results/TestIntMath.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  // --- AbsI64 ---
  r = AbsI64(42);
  if (r == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "abs_positive\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = AbsI64(-42);
  if (r == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "abs_negative\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = AbsI64(0);
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "abs_zero\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- MinI64 ---
  r = MinI64(3, 7);
  if (r == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "min_3_7\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = MinI64(-5, -10);
  if (r == -10) s = "PASS"; else s = "FAIL";
  StrPrint(line, "min_neg5_neg10\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = MinI64(7, 7);
  if (r == 7) s = "PASS"; else s = "FAIL";
  StrPrint(line, "min_equal\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- MaxI64 ---
  r = MaxI64(3, 7);
  if (r == 7) s = "PASS"; else s = "FAIL";
  StrPrint(line, "max_3_7\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = MaxI64(-5, -10);
  if (r == -5) s = "PASS"; else s = "FAIL";
  StrPrint(line, "max_neg5_neg10\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- SignI64 ---
  r = SignI64(100);
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sign_positive\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = SignI64(-100);
  if (r == -1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sign_negative\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = SignI64(0);
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sign_zero\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- ClampI64 ---
  r = ClampI64(5, 1, 10);
  if (r == 5) s = "PASS"; else s = "FAIL";
  StrPrint(line, "clamp_in_range\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = ClampI64(-5, 1, 10);
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "clamp_below_lo\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = ClampI64(99, 1, 10);
  if (r == 10) s = "PASS"; else s = "FAIL";
  StrPrint(line, "clamp_above_hi\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- I64 boundary values ---
  r = I64_MAX;
  if (r == 0x7FFFFFFFFFFFFFFF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "i64_max\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = I64_MIN;
  if (r == -0x8000000000000000) s = "PASS"; else s = "FAIL";
  StrPrint(line, "i64_min\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- I64 overflow wraps ---
  r = I64_MAX;
  r++;
  if (r == I64_MIN) s = "PASS"; else s = "FAIL";
  StrPrint(line, "i64_overflow_wraps\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- SqrI64 ---
  r = SqrI64(7);
  if (r == 49) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sqr_7\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = SqrI64(0);
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sqr_0\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  FileWrite("C:/AI/results/TestIntMath.txt", out, StrLen(out));
}

TestIntMath;
