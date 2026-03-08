// TestMath3.HC — Arg (ATan2), Exp, Ln, Log2, Log10, Pow
// KEY CONSTRAINT: F64 locals in HolyC functions crash the JIT. All F64 state is global.
//
// Arg(x, y) = atan2(y, x)  — angle of vector (x,y) using FPATAN
// Exp, Ln, Log2, Log10, Pow — transcendental math
//
// Called by TestRunner with shared output buffer.

F64 g_m3_a = 0.0;
F64 g_m3_r = 0.0;

U0 TestMath3(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 ri;

  // --- Exp ---

  // Exp(0.0) = 1.0 (exact)
  g_m3_r = Exp(0.0);
  if (g_m3_r == 1.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "exp_0\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Exp(1.0) = e ≈ 2.71828; scale *100000, truncate via ToI64
  g_m3_r = Exp(1.0);
  ri = ToI64(g_m3_r * 100000.0);
  if (ri == 271828) s = "PASS"; else s = "FAIL";
  StrPrint(line, "exp_1\t%s\t%d\n", s, ri);
  CatPrint(out, "%s", line);

  // --- Ln ---

  // Ln(1.0) = 0.0 (exact)
  g_m3_r = Ln(1.0);
  if (g_m3_r == 0.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ln_1\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Ln(Exp(1.0)) round-trip: should be 1.0 within 5 sig figs
  g_m3_a = Exp(1.0);
  g_m3_r = Ln(g_m3_a);
  ri = ToI64(g_m3_r * 100000.0);
  if (ri == 100000) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ln_e\t%s\t%d\n", s, ri);
  CatPrint(out, "%s", line);

  // --- Log2 ---

  // Log2(1.0) = 0.0 (exact)
  g_m3_r = Log2(1.0);
  if (g_m3_r == 0.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "log2_1\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Log2(2.0) = 1.0 (exact: 2 is a power of 2)
  g_m3_r = Log2(2.0);
  if (g_m3_r == 1.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "log2_2\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Log2(8.0) should be 3.0
  g_m3_r = Log2(8.0);
  if (g_m3_r == 3.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "log2_8\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // --- Log10 ---

  // Log10(1.0) = 0.0 (exact)
  g_m3_r = Log10(1.0);
  if (g_m3_r == 0.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "log10_1\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Log10(10.0) ≈ 1.0; range check to guard FP imprecision
  g_m3_r = Log10(10.0);
  if (g_m3_r > 0.9999 && g_m3_r < 1.0001) s = "PASS"; else s = "FAIL";
  StrPrint(line, "log10_10\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Log10(100.0) ≈ 2.0
  g_m3_r = Log10(100.0);
  if (g_m3_r > 1.9999 && g_m3_r < 2.0001) s = "PASS"; else s = "FAIL";
  StrPrint(line, "log10_100\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // --- Pow ---

  // Pow(any, 0.0) = 1.0 (exact)
  g_m3_r = Pow(5.0, 0.0);
  if (g_m3_r == 1.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "pow_5_0\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Pow(2.0, 3.0) ≈ 8.0; range check (uses exp/log internally)
  g_m3_r = Pow(2.0, 3.0);
  if (g_m3_r > 7.999 && g_m3_r < 8.001) s = "PASS"; else s = "FAIL";
  StrPrint(line, "pow_2_3\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Pow(4.0, 0.5) ≈ 2.0 (sqrt via Pow)
  g_m3_r = Pow(4.0, 0.5);
  if (g_m3_r > 1.999 && g_m3_r < 2.001) s = "PASS"; else s = "FAIL";
  StrPrint(line, "pow_4_half\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // --- Arg (atan2(y, x) — angle of vector (x,y)) ---

  // Arg(1.0, 0.0) = atan2(0, 1) = 0.0 (pointing right)
  g_m3_r = Arg(1.0, 0.0);
  if (g_m3_r == 0.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "arg_1_0\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Arg(0.0, 1.0) = atan2(1, 0) = pi/2 ≈ 1.5708 (pointing up)
  g_m3_r = Arg(0.0, 1.0);
  if (g_m3_r > 1.570 && g_m3_r < 1.572) s = "PASS"; else s = "FAIL";
  StrPrint(line, "arg_0_1\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Arg(-1.0, 0.0) = atan2(0, -1) = pi ≈ 3.1416 (pointing left)
  g_m3_r = Arg(-1.0, 0.0);
  if (g_m3_r > 3.141 && g_m3_r < 3.143) s = "PASS"; else s = "FAIL";
  StrPrint(line, "arg_neg1_0\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);

  // Arg(1.0, 1.0) = atan2(1, 1) = pi/4 ≈ 0.7854
  g_m3_r = Arg(1.0, 1.0);
  if (g_m3_r > 0.785 && g_m3_r < 0.786) s = "PASS"; else s = "FAIL";
  StrPrint(line, "arg_1_1\t%s\t%f\n", s, g_m3_r);
  CatPrint(out, "%s", line);
}
