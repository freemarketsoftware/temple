// TestGrPalette.HC — GrPaletteColorSet/Get round-trip, PaletteSetStd restore
// Uses palette index 1 for all modifications (avoids touching BLACK at index 0).
// Safe for TestRunner — just VGA DAC I/O port writes/reads; no screen damage.
//
// CBGR48 layout: b(U16), g(U16), r(U16), pad(U16) in little-endian order
// SET: writes channel >> 10 to VGA DAC (6-bit, 0-63)
// GET: reads 6-bit DAC, scales back: (0xFFFF << 10) * dac / 0xFC00
//
// Exact round-trip channels: 0x0000, 0x5555 (d=21), 0xAAAA (d=42), 0xFFFF (d=63)
// Standard palette uses only these values, so all std colors round-trip perfectly.

U0 TestGrPalette(U8 *out) {
  U8 line[128];
  U8 *s;
  CBGR48 test_col;
  CBGR48 orig_col;
  CBGR48 got;
  I64 ok;

  // 1. Standard palette color 1 (DKBLUE = b=0xAAAA, g=0, r=0) is nonzero
  orig_col = GrPaletteColorGet(1);
  ok = (orig_col(U64) != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "get_nonblack\t%s\t%X\n", s, orig_col(U64));
  CatPrint(out, "%s", line);

  // 2. Set color 1 to pure blue (b=0xFFFF, g=0, r=0); read back exact
  test_col = 0;
  test_col.b = 0xFFFF;
  GrPaletteColorSet(1, test_col);
  got = GrPaletteColorGet(1);
  ok = (got.b == 0xFFFF && got.g == 0 && got.r == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "set_blue_roundtrip\t%s\tb=%X g=%X r=%X\n", s, got.b, got.g, got.r);
  CatPrint(out, "%s", line);

  // 3. Set color 1 to pure red (r=0xFFFF, g=0, b=0); read back exact
  test_col = 0;
  test_col.r = 0xFFFF;
  GrPaletteColorSet(1, test_col);
  got = GrPaletteColorGet(1);
  ok = (got.r == 0xFFFF && got.g == 0 && got.b == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "set_red_roundtrip\t%s\tb=%X g=%X r=%X\n", s, got.b, got.g, got.r);
  CatPrint(out, "%s", line);

  // 4. Set color 1 to pure green (g=0xFFFF, b=0, r=0); read back exact
  test_col = 0;
  test_col.g = 0xFFFF;
  GrPaletteColorSet(1, test_col);
  got = GrPaletteColorGet(1);
  ok = (got.g == 0xFFFF && got.b == 0 && got.r == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "set_green_roundtrip\t%s\tb=%X g=%X r=%X\n", s, got.b, got.g, got.r);
  CatPrint(out, "%s", line);

  // 5. Set color 1 to black (all 0); read back 0
  test_col = 0;
  GrPaletteColorSet(1, test_col);
  got = GrPaletteColorGet(1);
  ok = (got(U64) == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "set_black_roundtrip\t%s\t%X\n", s, got(U64));
  CatPrint(out, "%s", line);

  // 6. PaletteSetStd restores: color 1 should match original (0x00000000AAAA)
  PaletteSetStd();
  got = GrPaletteColorGet(1);
  ok = (got(U64) == orig_col(U64));
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "palette_restore\t%s\t%X\n", s, got(U64));
  CatPrint(out, "%s", line);

  // 7. Color 15 (WHITE) in std palette: all channels == 0xFFFF
  got = GrPaletteColorGet(15);
  ok = (got.r == 0xFFFF && got.g == 0xFFFF && got.b == 0xFFFF);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "white_color\t%s\t%X\n", s, got(U64));
  CatPrint(out, "%s", line);

  // 8. Color 0 (BLACK) in std palette: all channels == 0
  got = GrPaletteColorGet(0);
  ok = (got(U64) == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "black_color\t%s\t%X\n", s, got(U64));
  CatPrint(out, "%s", line);
}
