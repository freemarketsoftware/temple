
U0 Probe9() {
  // Simulate packet header parsing: raw U8 buf, cast to typed ptr at offset
  U8 *buf = MAlloc(32);
  // write known byte pattern
  I64 i;
  for (i = 0; i < 32; i++) buf[i] = i;
  U8 buf2[256];
  // read U16 at offset 4 (bytes 4,5 = 0x04, 0x05 -> little-endian 0x0504)
  U16 *u16p = buf + 4;
  StrPrint(buf2, "u16_at4=%X
", *u16p);
  // read U32 at offset 8
  U32 *u32p = buf + 8;
  CatPrint(buf2, "u32_at8=%X
", *u32p);
  // read I64 at offset 0
  I64 *i64p = buf(I64 *);
  CatPrint(buf2, "i64_at0=%X
", *i64p);
  Free(buf);
  FileWrite("C:/AI/results/ptr_probe.txt", buf2, StrLen(buf2));
}
Probe9;
