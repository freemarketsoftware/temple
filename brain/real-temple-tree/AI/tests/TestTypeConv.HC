// TestTypeConv.HC — Integer type truncation, wrapping, and promotion
// Tests how I64 values truncate when stored to U8/U16/U32
// and how smaller types promote when loaded into I64
// Called by TestRunner with shared output buffer

U0 TestTypeConv(U8 *out) {
  U8 line[128];
  U8 *s;
  U8  u8val;
  U16 u16val;
  U32 u32val;
  I8  i8val;
  I16 i16val;
  I32 i32val;
  I64 r;

  // --- U8 local: HolyC locals are 64-bit, no truncation on assignment ---
  u8val = 0x1FF;
  StrPrint(line, "u8_local_notrunc\tOBS\t%d\n", u8val);
  CatPrint(out, "%s", line);

  u8val = 256;
  StrPrint(line, "u8_local_256\tOBS\t%d\n", u8val);
  CatPrint(out, "%s", line);

  // --- U16 local: no truncation ---
  u16val = 0x10001;
  StrPrint(line, "u16_local_notrunc\tOBS\t%d\n", u16val);
  CatPrint(out, "%s", line);

  // --- U32 local: no truncation ---
  u32val = 0x100000001;
  StrPrint(line, "u32_local_notrunc\tOBS\t%d\n", u32val);
  CatPrint(out, "%s", line);

  // --- I8 negative: store -1 into I8, load into I64 (sign extend?) ---
  i8val = -1;
  r = i8val;
  StrPrint(line, "i8_neg1_to_i64\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- I8 max: 127 ---
  i8val = 127;
  r = i8val;
  if (r == 127) s = "PASS"; else s = "FAIL";
  StrPrint(line, "i8_max\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- I8 overflow: store 128 into I8 (expect -128 on wrap) ---
  i8val = 128;
  StrPrint(line, "i8_wrap_128\tOBS\t%d\n", i8val);
  CatPrint(out, "%s", line);

  // --- U8 promotion to I64: 0xFF -> 255, not -1 ---
  u8val = 0xFF;
  r = u8val;
  if (r == 255) s = "PASS"; else s = "FAIL";
  StrPrint(line, "u8_to_i64\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- I16 negative sign extension ---
  i16val = -1;
  r = i16val;
  StrPrint(line, "i16_neg1_to_i64\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- U16 zero extension ---
  u16val = 0xFFFF;
  r = u16val;
  if (r == 65535) s = "PASS"; else s = "FAIL";
  StrPrint(line, "u16_to_i64\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- I32 negative sign extension ---
  i32val = -1;
  r = i32val;
  StrPrint(line, "i32_neg1_to_i64\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- U32 zero extension ---
  u32val = 0xFFFFFFFF;
  r = u32val;
  if (r == 4294967295) s = "PASS"; else s = "FAIL";
  StrPrint(line, "u32_to_i64\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);
}
