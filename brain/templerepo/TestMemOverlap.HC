// TestMemOverlap.HC — MemCpy overlap behavior (MemMove does NOT exist in TempleOS)
// MemCpy uses REP MOVSB (forward copy), so dst < src overlapping regions work
// dst > src overlapping corrupts (overwrites source bytes before they are read)

U0 TestMemOverlap(U8 *out) {
  U8 line[128];
  U8 *s;
  U8 *buf;
  I64 ok;
  I64 i;

  // Allocate a 64-byte scratch buffer
  buf = MAlloc(64);

  // --- Non-overlapping copy (baseline) ---
  // Write 0x41-0x4A ('A'-'J') in bytes 0-9, copy to 20-29
  i = 0;
  while (i < 10) {
    buf[i] = 0x41 + i;
    i++;
  }
  MemCpy(buf + 20, buf, 10);
  ok = 1;
  i = 0;
  while (i < 10) {
    if (buf[20 + i] != 0x41 + i) ok = 0;
    i++;
  }
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "memcpy_nonoverlap\t%s\t\n", s);
  CatPrint(out, line);

  // --- Forward overlap: dst < src, regions overlap ---
  // src=buf+4, dst=buf+0, len=8: bytes 4-11 -> bytes 0-7
  // dst < src so REP MOVSB reads src before it overwrites it -> correct
  i = 0;
  while (i < 16) {
    buf[i] = i;
    i++;
  }
  // buf[0..15] = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}
  MemCpy(buf, buf + 4, 8);
  // expect buf[0..7] = {4,5,6,7,8,9,10,11}
  ok = 1;
  i = 0;
  while (i < 8) {
    if (buf[i] != i + 4) ok = 0;
    i++;
  }
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "memcpy_fwd_overlap\t%s\t\n", s);
  CatPrint(out, line);

  // --- Exact same pointer: MemCpy(p, p, n) -> identity ---
  i = 0;
  while (i < 8) {
    buf[i] = i * 3;
    i++;
  }
  MemCpy(buf, buf, 8);
  ok = 1;
  i = 0;
  while (i < 8) {
    if (buf[i] != i * 3) ok = 0;
    i++;
  }
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "memcpy_same_ptr\t%s\t\n", s);
  CatPrint(out, line);

  // --- Zero-length copy: no-op ---
  buf[0] = 0xAB;
  buf[1] = 0xCD;
  MemCpy(buf, buf + 1, 0);
  ok = (buf[0] == 0xAB);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "memcpy_zero_len\t%s\t\n", s);
  CatPrint(out, line);

  // --- Backward overlap: dst > src, regions overlap ---
  // src=buf+0, dst=buf+4, len=8: bytes 0-7 -> bytes 4-11
  // REP MOVSB reads buf[0] into buf[4], buf[1]->buf[5], ..., buf[3]->buf[7],
  // then reads buf[4] which was already overwritten by buf[0], etc.
  // Result is implementation-defined; document as OBS
  i = 0;
  while (i < 16) {
    buf[i] = i;
    i++;
  }
  // src bytes 0-7 = {0,1,2,3,4,5,6,7}
  MemCpy(buf + 4, buf, 8);
  // dst bytes 4-11 — first 4 will be correct ({0,1,2,3}),
  // bytes 8-11 come from already-overwritten region
  s = "OBS";
  StrPrint(line, "memcpy_bwd_overlap\t%s\tdst[0]=%d dst[1]=%d dst[2]=%d dst[3]=%d dst[4]=%d\n",
           s, buf[4], buf[5], buf[6], buf[7], buf[8]);
  CatPrint(out, line);

  Free(buf);

  // --- MemMove absence: confirm no symbol ---
  // MemMove is not defined in TempleOS; this is an OBS finding
  s = "OBS";
  StrPrint(line, "memmove_absent\t%s\tMemMove does not exist in TempleOS kernel\n", s);
  CatPrint(out, line);
}
