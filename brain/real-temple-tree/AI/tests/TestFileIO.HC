// TestFileIO.HC — Unit tests for FileWrite / FileRead roundtrip
// Tests: basic roundtrip, size reporting, overwrite, large content, binary data
// Called by TestRunner with shared output buffer

#define TESTFILE "C:/AI/results/_fio_tmp.txt"

U0 TestFileIO(U8 *out) {
  U8 line[128];
  U8 *s;
  U8 *rbuf;
  I64 r, sz, i;
  U8 wbuf[1024];

  // --- basic roundtrip ---
  FileWrite(TESTFILE, "hello", 5);
  rbuf = FileRead(TESTFILE, &sz);
  if (sz == 5 && MemCmp(rbuf, "hello", 5) == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "basic_roundtrip\t%s\t%d\n", s, sz);
  CatPrint(out, "%s", line);
  Free(rbuf);

  // --- FileWrite returns non-zero (disk sector index, not byte count) ---
  r = FileWrite(TESTFILE, "abc", 3);
  if (r != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "filewrite_retval_nonzero\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- FileRead reports correct size ---
  rbuf = FileRead(TESTFILE, &sz);
  if (sz == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fileread_size\t%s\t%d\n", s, sz);
  CatPrint(out, "%s", line);
  Free(rbuf);

  // --- overwrite replaces content ---
  FileWrite(TESTFILE, "first", 5);
  FileWrite(TESTFILE, "second", 6);
  rbuf = FileRead(TESTFILE, &sz);
  if (sz == 6 && MemCmp(rbuf, "second", 6) == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "overwrite\t%s\t%d\n", s, sz);
  CatPrint(out, "%s", line);
  Free(rbuf);

  // --- large content (1KB) ---
  MemSet(wbuf, 'A', 1024);
  FileWrite(TESTFILE, wbuf, 1024);
  rbuf = FileRead(TESTFILE, &sz);
  if (sz == 1024) s = "PASS"; else s = "FAIL";
  StrPrint(line, "large_1kb_size\t%s\t%d\n", s, sz);
  CatPrint(out, "%s", line);
  if (sz == 1024 && MemCmp(rbuf, wbuf, 1024) == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "large_1kb_content\t%s\t%d\n", s, sz);
  CatPrint(out, "%s", line);
  Free(rbuf);

  // --- binary data (all byte values 0x01..0xFF) ---
  for (i = 0; i < 255; i++) wbuf[i] = i + 1;
  FileWrite(TESTFILE, wbuf, 255);
  rbuf = FileRead(TESTFILE, &sz);
  if (sz == 255 && MemCmp(rbuf, wbuf, 255) == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "binary_255_bytes\t%s\t%d\n", s, sz);
  CatPrint(out, "%s", line);
  Free(rbuf);

  // --- write then read preserves newlines and tabs ---
  FileWrite(TESTFILE, "a\tb\nc\td\n", 8);
  rbuf = FileRead(TESTFILE, &sz);
  if (sz == 8 && MemCmp(rbuf, "a\tb\nc\td\n", 8) == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "whitespace_chars\t%s\t%d\n", s, sz);
  CatPrint(out, "%s", line);
  Free(rbuf);

  // cleanup temp file
  Del(TESTFILE);
}
