// TestShiftEdge.HC — Shift edge cases: SAR, large counts, boundary values
// Tests x86 behavior: shift count is masked to low 6 bits (mod 64)
// SAR on signed I64 fills with sign bit (arithmetic shift)

U0 TestShiftEdge(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 x;
  I64 got;

  // SAR: -8 >> 2 = -2 (arithmetic right shift, sign-extended)
  x = -8;
  got = x >> 2;
  if (got == -2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sar_neg8_by2\t%s\tgot=%d\n", s, got);
  CatPrint(out, line);

  // SAR: -1 >> 63 = -1 (all sign bits)
  x = -1;
  got = x >> 63;
  if (got == -1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sar_neg1_by63\t%s\tgot=%d\n", s, got);
  CatPrint(out, line);

  // SAR: -1 >> 1 = -1 (sign fills from left)
  x = -1;
  got = x >> 1;
  if (got == -1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sar_neg1_by1\t%s\tgot=%d\n", s, got);
  CatPrint(out, line);

  // SAR: -16 >> 0 = -16 (shift by zero is identity)
  x = -16;
  got = x >> 0;
  if (got == -16) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sar_by_zero\t%s\tgot=%d\n", s, got);
  CatPrint(out, line);

  // SHL: 1 << 63 = I64_MIN (0x8000000000000000)
  x = 1;
  got = x << 63;
  if (got == -9223372036854775808) s = "PASS"; else s = "FAIL";
  StrPrint(line, "shl_1_by63\t%s\tgot=%d\n", s, got);
  CatPrint(out, line);

  // SHR: I64_MIN >> 1 (unsigned-style: sign bit shifts in for SAR)
  // I64_MIN = -9223372036854775808; SAR by 1 = -4611686018427387904
  x = -9223372036854775808;
  got = x >> 1;
  if (got == -4611686018427387904) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sar_imin_by1\t%s\tgot=%d\n", s, got);
  CatPrint(out, line);

  // SHL: I64_MAX << 1 = -2 (overflow wraps: 0x7FFF...FFFE)
  x = 9223372036854775807;
  got = x << 1;
  if (got == -2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "shl_imax_by1\t%s\tgot=%d\n", s, got);
  CatPrint(out, line);

  // SHL: 1 << 0 = 1 (identity)
  x = 1;
  got = x << 0;
  if (got == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "shl_by_zero\t%s\tgot=%d\n", s, got);
  CatPrint(out, line);

  // x86 shift count mod 64: 1 << 64 = 1 (64 mod 64 = 0, shift by 0)
  // This is x86 undefined behavior but predictable on hardware
  x = 1;
  got = x << 64;
  s = "OBS";
  StrPrint(line, "shl_1_by64_mod\t%s\tgot=%d (x86: 64 mod 64=0, shift by 0 -> 1)\n", s, got);
  CatPrint(out, line);

  // x86: 1 << 127 = 1 << (127 mod 64) = 1 << 63 = I64_MIN
  x = 1;
  got = x << 127;
  s = "OBS";
  StrPrint(line, "shl_1_by127_mod\t%s\tgot=%d (x86: 127 mod 64=63, -> I64_MIN)\n", s, got);
  CatPrint(out, line);

  // SHR: 256 >> 4 = 16
  x = 256;
  got = x >> 4;
  if (got == 16) s = "PASS"; else s = "FAIL";
  StrPrint(line, "shr_256_by4\t%s\tgot=%d\n", s, got);
  CatPrint(out, line);

  // SHL: 1 << 8 = 256
  x = 1;
  got = x << 8;
  if (got == 256) s = "PASS"; else s = "FAIL";
  StrPrint(line, "shl_1_by8\t%s\tgot=%d\n", s, got);
  CatPrint(out, line);
}
