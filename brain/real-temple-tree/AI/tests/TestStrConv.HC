// TestStrConv.HC — Str2I64, Str2F64, StrScan, MStrPrint
// All F64 state in globals (local F64 vars crash OS).
// Called by TestRunner with shared output buffer.

// --- Globals for F64 (JIT bug workaround) ---
F64 g_sc_f  = 0.0;
F64 g_sc_f2 = 0.0;

U0 TestStrConv(U8 *out) {
  U8 line[256];
  U8 *s;
  I64 v;
  U8 *end;

  // --- Str2I64: decimal ---
  if (Str2I64("42") == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_dec\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Str2I64: negative ---
  if (Str2I64("-7") == -7) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_neg\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Str2I64: 0x hex prefix ---
  if (Str2I64("0xFF") == 255) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_hex_prefix\t%s\t%X\n", s, Str2I64("0xFF"));
  CatPrint(out, "%s", line);

  // --- Str2I64: 0b binary prefix ---
  if (Str2I64("0b1010") == 10) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_bin_prefix\t%s\t%d\n", s, Str2I64("0b1010"));
  CatPrint(out, "%s", line);

  // --- Str2I64: 0o octal prefix NOT supported (returns 0) ---
  v = Str2I64("0o17");
  s = "obs";
  StrPrint(line, "str2i64_oct_prefix\t%s\t%d (0o unsupported, not 15)\n", s, v);
  CatPrint(out, "%s", line);

  // --- Str2I64: explicit radix 16 ---
  if (Str2I64("FF", 16) == 255) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_radix16\t%s\t%X\n", s, Str2I64("FF", 16));
  CatPrint(out, "%s", line);

  // --- Str2I64: explicit radix 2 ---
  if (Str2I64("1010", 2) == 10) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_radix2\t%s\t%d\n", s, Str2I64("1010", 2));
  CatPrint(out, "%s", line);

  // --- Str2I64: explicit radix 8 ---
  if (Str2I64("17", 8) == 15) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_radix8\t%s\t%d\n", s, Str2I64("17", 8));
  CatPrint(out, "%s", line);

  // --- Str2I64: leading whitespace skipped ---
  if (Str2I64("  99") == 99) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_ws\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Str2I64: end_ptr stops at non-digit ---
  v = Str2I64("123abc", 10, &end);
  if (v == 123 && *end == 'a') s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_endptr\t%s\tv=%d ch=%c\n", s, v, *end);
  CatPrint(out, "%s", line);

  // --- Str2I64: large hex value ---
  if (Str2I64("0xDEADBEEF") == 0xDEADBEEF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_large\t%s\t%X\n", s, Str2I64("0xDEADBEEF"));
  CatPrint(out, "%s", line);

  // --- Str2I64: zero ---
  if (Str2I64("0") == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2i64_zero\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Str2F64: basic float ---
  g_sc_f = Str2F64("3.14");
  if (g_sc_f > 3.13 && g_sc_f < 3.15) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2f64_pi\t%s\t%.2f\n", s, g_sc_f);
  CatPrint(out, "%s", line);

  // --- Str2F64: negative ---
  g_sc_f = Str2F64("-2.5");
  if (g_sc_f == -2.5) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2f64_neg\t%s\t%.1f\n", s, g_sc_f);
  CatPrint(out, "%s", line);

  // --- Str2F64: exponential notation (range check: == 1500.0 fails due to x87 rounding) ---
  g_sc_f = Str2F64("1.5e3");
  if (g_sc_f > 1499.0 && g_sc_f < 1501.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2f64_exp\t%s\t%.0f\n", s, g_sc_f);
  CatPrint(out, "%s", line);

  // --- Str2F64: round-trip via StrPrint ---
  U8 tmp[64];
  g_sc_f = 3.14159;
  StrPrint(tmp, "%.5f", g_sc_f);
  g_sc_f2 = Str2F64(tmp);
  if (g_sc_f == g_sc_f2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "str2f64_roundtrip\t%s\t%.5f\n", s, g_sc_f2);
  CatPrint(out, "%s", line);

  // --- StrScan: decimal ---
  v = 0;
  StrScan("42", "%d", &v);
  if (v == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strscan_dec\t%s\t%d\n", s, v);
  CatPrint(out, "%s", line);

  // --- StrScan: hex ---
  v = 0;
  StrScan("FF", "%X", &v);
  if (v == 255) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strscan_hex\t%s\t%X\n", s, v);
  CatPrint(out, "%s", line);

  // --- StrScan: float ---
  g_sc_f = 0.0;
  StrScan("3.14", "%f", &g_sc_f);
  if (g_sc_f > 3.13 && g_sc_f < 3.15) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strscan_flt\t%s\t%.2f\n", s, g_sc_f);
  CatPrint(out, "%s", line);

  // --- StrScan: multiple fields ---
  I64 a = 0, b = 0;
  StrScan("10 20", "%d %d", &a, &b);
  if (a == 10 && b == 20) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strscan_multi\t%s\t%d_%d\n", s, a, b);
  CatPrint(out, "%s", line);

  // --- MStrPrint: allocates string ---
  U8 *ms = MStrPrint("v=%d", 99);
  if (!StrCmp(ms, "v=99")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mstrprint\t%s\t%s\n", s, ms);
  Free(ms);
  CatPrint(out, "%s", line);

  // --- StrPrint zero-pad ---
  StrPrint(tmp, "%08X", 0xABC);
  if (!StrCmp(tmp, "00000ABC")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strprint_zpad\t%s\t%s\n", s, tmp);
  CatPrint(out, "%s", line);
}
