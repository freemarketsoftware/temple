// TestTypeConv.HC — Integer type truncation, wrapping, and promotion
// Tests how I64 values truncate when stored to U8/U16/U32
// and how smaller types promote when loaded into I64
// Results written to C:/AI/results/TestTypeConv.txt as TSV
U0 TestTypeConv() {
  U8 out[2048];
  U8 line[128];
  U8 *s;
  U8  u8val;
  U16 u16val;
  U32 u32val;
  I8  i8val;
  I16 i16val;
  I32 i32val;
  I64 r;

  Del("C:/AI/results/TestTypeConv.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  // --- U8 truncation: store 0x1FF into U8, expect 0xFF ---
  u8val = 0x1FF;
  if (u8val == 0xFF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "u8_trunc\t%s\t%d\n", s, u8val);
  CatPrint(out, "%s", line);

  // --- U8 truncation: store 256 into U8, expect 0 ---
  u8val = 256;
  if (u8val == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "u8_wrap_256\t%s\t%d\n", s, u8val);
  CatPrint(out, "%s", line);

  // --- U16 truncation: store 0x10001 into U16, expect 1 ---
  u16val = 0x10001;
  if (u16val == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "u16_trunc\t%s\t%d\n", s, u16val);
  CatPrint(out, "%s", line);

  // --- U32 truncation: store 0x100000001 into U32, expect 1 ---
  u32val = 0x100000001;
  if (u32val == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "u32_trunc\t%s\t%d\n", s, u32val);
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

  FileWrite("C:/AI/results/TestTypeConv.txt", out, StrLen(out));
}
TestTypeConv;
