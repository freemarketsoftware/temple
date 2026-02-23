// TestBitOps.HC — Bit manipulation: Bt, Bts, Btr, Bsf, Bsr, bitwise ops
// Results written to C:/AI/results/TestBitOps.txt as TSV
U0 TestBitOps() {
  U8 out[2048];
  U8 line[128];
  U8 *s;
  I64 val, r;

  Del("C:/AI/results/TestBitOps.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  // --- Bitwise AND ---
  r = 0xFF & 0x0F;
  if (r == 0x0F) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bit_and\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- Bitwise OR ---
  r = 0xF0 | 0x0F;
  if (r == 0xFF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bit_or\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- Bitwise XOR ---
  r = 0xFF ^ 0x0F;
  if (r == 0xF0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bit_xor\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- Bitwise NOT ---
  r = ~0;
  if (r == -1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bit_not_0\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- Left shift ---
  r = 1 << 4;
  if (r == 16) s = "PASS"; else s = "FAIL";
  StrPrint(line, "shl_1_4\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- Right shift (unsigned) ---
  r = 0x80 >> 3;
  if (r == 0x10) s = "PASS"; else s = "FAIL";
  StrPrint(line, "shr_0x80_3\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- Arithmetic right shift (negative) ---
  r = -8 >> 1;
  StrPrint(line, "sar_neg8_1\tOBS\t%d\n", r);
  CatPrint(out, "%s", line);

  // --- Bt: bit test ---
  val = 0x42;  // bit 1 and bit 6 set
  r = Bt(&val, 1);
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bt_set\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = Bt(&val, 0);
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bt_clear\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- Bts: bit test and set ---
  val = 0;
  r = Bts(&val, 3);  // set bit 3, returns old value (0)
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bts_ret_old\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  if (val == 8) s = "PASS"; else s = "FAIL";  // 1<<3 = 8
  StrPrint(line, "bts_val_after\t%s\t%d\n", s, val);
  CatPrint(out, "%s", line);

  // --- Btr: bit test and reset ---
  val = 0xFF;
  r = Btr(&val, 2);  // clear bit 2, returns old value (1)
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "btr_ret_old\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  if (val == 0xFB) s = "PASS"; else s = "FAIL";  // 0xFF & ~4 = 0xFB
  StrPrint(line, "btr_val_after\t%s\t%d\n", s, val);
  CatPrint(out, "%s", line);

  // --- Bsf: bit scan forward (find lowest set bit) ---
  val = 0x18;  // bits 3 and 4 set, lowest is 3
  r = Bsf(val);
  if (r == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bsf_0x18\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- Bsr: bit scan reverse (find highest set bit) ---
  val = 0x18;  // bits 3 and 4 set, highest is 4
  r = Bsr(val);
  if (r == 4) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bsr_0x18\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  FileWrite("C:/AI/results/TestBitOps.txt", out, StrLen(out));
}
TestBitOps;
