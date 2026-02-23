// TestMemUtil.HC — CAlloc, MemSet, MemCpy, MemCmp
// Results written to C:/AI/results/TestMemUtil.txt as TSV
U0 TestMemUtil() {
  U8 out[2048];
  U8 line[128];
  U8 *s;
  U8 *p, *q;
  I64 i, r;

  Del("C:/AI/results/TestMemUtil.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  // --- CAlloc: zero-filled ---
  p = CAlloc(64);
  s = "PASS";
  for (i = 0; i < 64; i++) {
    if (p[i] != 0) { s = "FAIL"; break; }
  }
  StrPrint(line, "calloc_zero\t%s\t64bytes\n", s);
  CatPrint(out, "%s", line);
  Free(p);

  // --- MemSet: fill U8 ---
  p = MAlloc(16);
  MemSet(p, 0xAB, 16);
  s = "PASS";
  for (i = 0; i < 16; i++) {
    if (p[i] != 0xAB) { s = "FAIL"; break; }
  }
  StrPrint(line, "memset_u8\t%s\t0xAB\n", s);
  CatPrint(out, "%s", line);
  Free(p);

  // --- MemCpy: basic copy 16 bytes ---
  p = MAlloc(16);
  q = CAlloc(16);
  MemSet(p, 0x55, 16);
  MemCpy(q, p, 16);
  s = "PASS";
  for (i = 0; i < 16; i++) {
    if (q[i] != 0x55) { s = "FAIL"; break; }
  }
  StrPrint(line, "memcpy_basic\t%s\t16bytes\n", s);
  CatPrint(out, "%s", line);
  Free(p);
  Free(q);

  // --- MemCmp: equal ---
  p = MAlloc(8);
  q = MAlloc(8);
  MemSet(p, 0x42, 8);
  MemSet(q, 0x42, 8);
  r = MemCmp(p, q, 8);
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "memcmp_equal\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- MemCmp: a < b returns exactly -1 (not arbitrary negative) ---
  q[4] = 0x43;
  r = MemCmp(p, q, 8);
  if (r == -1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "memcmp_lt\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- MemCmp: a > b returns exactly 1 (not arbitrary positive) ---
  q[4] = 0x41;
  r = MemCmp(p, q, 8);
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "memcmp_gt\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);
  Free(p);
  Free(q);

  FileWrite("C:/AI/results/TestMemUtil.txt", out, StrLen(out));
}
TestMemUtil;
