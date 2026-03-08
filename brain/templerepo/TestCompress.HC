// TestCompress.HC — CompressBuf / ExpandBuf roundtrip
// CompressBuf(U8 *src, I64 size) -> CArcCompress*
// ExpandBuf(CArcCompress *arc)   -> U8*  (caller frees both)

U0 TestCompress(U8 *out) {
  U8 line[128];
  U8 *s;
  U8 *src;
  U8 *expanded;
  CArcCompress *arc;
  I64 ok;
  I64 src_len;

  // basic roundtrip: compress a short string (include null terminator)
  src = "Hello, TempleOS!";
  src_len = StrLen(src) + 1;
  arc = CompressBuf(src, src_len);
  ok = (arc != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "compress_nonnull\t%s\t\n", s);
  CatPrint(out, line);

  if (arc) {
    expanded = ExpandBuf(arc);
    ok = (expanded != 0);
    if (ok) s = "PASS"; else s = "FAIL";
    StrPrint(line, "expand_nonnull\t%s\t\n", s);
    CatPrint(out, line);

    if (expanded) {
      ok = (StrCmp(expanded, src) == 0);
      if (ok) s = "PASS"; else s = "FAIL";
      StrPrint(line, "roundtrip_short\t%s\t\n", s);
      CatPrint(out, line);
      Free(expanded);
    }
    Free(arc);
  }

  // repetitive data compresses well (long string of same byte)
  src = MAlloc(256);
  MemSet(src, 'A', 255);
  src[255] = 0;
  arc = CompressBuf(src, 256);
  ok = (arc != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "compress_repetitive\t%s\t\n", s);
  CatPrint(out, line);

  if (arc) {
    expanded = ExpandBuf(arc);
    ok = (expanded != 0);
    if (ok) s = "PASS"; else s = "FAIL";
    StrPrint(line, "expand_repetitive\t%s\t\n", s);
    CatPrint(out, line);

    if (expanded) {
      ok = (MemCmp(expanded, src, 256) == 0);
      if (ok) s = "PASS"; else s = "FAIL";
      StrPrint(line, "roundtrip_repetitive\t%s\t\n", s);
      CatPrint(out, line);
      Free(expanded);
    }
    Free(arc);
  }

  Free(src);

  // longer text roundtrip
  src = "The quick brown fox jumps over the lazy dog. 0123456789.";
  src_len = StrLen(src) + 1;
  arc = CompressBuf(src, src_len);
  if (arc) {
    expanded = ExpandBuf(arc);
    if (expanded) {
      ok = (StrCmp(expanded, src) == 0);
      if (ok) s = "PASS"; else s = "FAIL";
      StrPrint(line, "roundtrip_longer\t%s\t\n", s);
      CatPrint(out, line);
      Free(expanded);
    }
    Free(arc);
  }
}
