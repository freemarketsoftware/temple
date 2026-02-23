// TestMemSet2.HC — MemSetU16, MemSetI64 using typed local arrays
// Results written to C:/AI/results/TestMemSet2.txt as TSV
U0 TestMemSet2() {
  U8 out[2048];
  U8 line[128];
  U8 *s;
  U16 u16arr[4];
  I64 i64arr[2];
  I64 i;

  Del("C:/AI/results/TestMemSet2.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  // --- MemSetU16: fill 4 U16s with 0x1234 ---
  MemSetU16(u16arr, 0x1234, 4);
  s = "PASS";
  for (i = 0; i < 4; i++) {
    if (u16arr[i] != 0x1234) { s = "FAIL"; break; }
  }
  StrPrint(line, "memset_u16_val\t%s\t%d_%d_%d_%d\n", s,
    u16arr[0], u16arr[1], u16arr[2], u16arr[3]);
  CatPrint(out, "%s", line);

  // --- MemSetU16: check byte layout (little-endian: 0x34,0x12) ---
  U8 *bp = u16arr;
  if (bp[0] == 0x34 && bp[1] == 0x12) s = "PASS"; else s = "FAIL";
  StrPrint(line, "memset_u16_bytes\t%s\t%d_%d\n", s, bp[0], bp[1]);
  CatPrint(out, "%s", line);

  // --- MemSetI64: fill 2 I64s with 0xDEADBEEF ---
  MemSetI64(i64arr, 0xDEADBEEF, 2);
  s = "PASS";
  for (i = 0; i < 2; i++) {
    if (i64arr[i] != 0xDEADBEEF) { s = "FAIL"; break; }
  }
  StrPrint(line, "memset_i64_val\t%s\t%d_%d\n", s, i64arr[0], i64arr[1]);
  CatPrint(out, "%s", line);

  FileWrite("C:/AI/results/TestMemSet2.txt", out, StrLen(out));
}
TestMemSet2;
