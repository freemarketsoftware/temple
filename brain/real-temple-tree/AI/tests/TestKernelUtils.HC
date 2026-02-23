// TestKernelUtils.HC — BCnt (popcount), EndianU16/U32/I64 (byte-swap)
// All pure computation — no hardware access, no allocation, no panic risk.
// Directly relevant to network protocol work (endian conversion for packet headers).
// Called by TestRunner with shared output buffer.

U0 TestKernelUtils(U8 *out) {
  U8 line[256];
  U8 *s;

  // --- BCnt: count set bits ---
  if (BCnt(0) == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bcnt_0\t%s\n", s);
  CatPrint(out, "%s", line);

  if (BCnt(1) == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bcnt_1\t%s\n", s);
  CatPrint(out, "%s", line);

  if (BCnt(0xFF) == 8) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bcnt_0xff\t%s\n", s);
  CatPrint(out, "%s", line);

  if (BCnt(-1) == 64) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bcnt_all_bits\t%s\n", s);
  CatPrint(out, "%s", line);

  if (BCnt(0x0F0F0F0F0F0F0F0F) == 32) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bcnt_checkerboard\t%s\n", s);
  CatPrint(out, "%s", line);

  if (BCnt(0x8000000000000000) == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bcnt_msb_only\t%s\n", s);
  CatPrint(out, "%s", line);

  if (BCnt(0xDEADBEEF) == 24) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bcnt_deadbeef\t%s\t%d\n", s, BCnt(0xDEADBEEF));
  CatPrint(out, "%s", line);

  // --- EndianU16: 2-byte swap ---
  if (EndianU16(0x1234) == 0x3412) s = "PASS"; else s = "FAIL";
  StrPrint(line, "eu16_swap\t%s\t%X\n", s, EndianU16(0x1234));
  CatPrint(out, "%s", line);

  if (EndianU16(0x0001) == 0x0100) s = "PASS"; else s = "FAIL";
  StrPrint(line, "eu16_0001\t%s\t%X\n", s, EndianU16(0x0001));
  CatPrint(out, "%s", line);

  if (EndianU16(0xFFFF) == 0xFFFF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "eu16_ffff\t%s\n", s);
  CatPrint(out, "%s", line);

  if (EndianU16(EndianU16(0xABCD)) == 0xABCD) s = "PASS"; else s = "FAIL";
  StrPrint(line, "eu16_roundtrip\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- EndianU32: 4-byte swap ---
  if (EndianU32(0x12345678) == 0x78563412) s = "PASS"; else s = "FAIL";
  StrPrint(line, "eu32_swap\t%s\t%X\n", s, EndianU32(0x12345678));
  CatPrint(out, "%s", line);

  if (EndianU32(0x00000001) == 0x01000000) s = "PASS"; else s = "FAIL";
  StrPrint(line, "eu32_0001\t%s\t%X\n", s, EndianU32(0x00000001));
  CatPrint(out, "%s", line);

  if (EndianU32(0xFFFFFFFF) == 0xFFFFFFFF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "eu32_ffff\t%s\n", s);
  CatPrint(out, "%s", line);

  if (EndianU32(EndianU32(0xDEADBEEF)) == 0xDEADBEEF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "eu32_roundtrip\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- EndianI64: 8-byte swap ---
  if (EndianI64(0x0102030405060708) == 0x0807060504030201) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ei64_swap\t%s\t%X\n", s, EndianI64(0x0102030405060708));
  CatPrint(out, "%s", line);

  if (EndianI64(0x0000000000000001) == 0x0100000000000000) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ei64_0001\t%s\t%X\n", s, EndianI64(0x0000000000000001));
  CatPrint(out, "%s", line);

  if (EndianI64(EndianI64(0xDEADBEEFCAFEBABE)) == 0xDEADBEEFCAFEBABE) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ei64_roundtrip\t%s\n", s);
  CatPrint(out, "%s", line);
}
