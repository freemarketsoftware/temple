// TestMalloc.HC — Unit tests for MAlloc/Free/MSize
// Results written to C:/AI/results/TestMalloc.txt as TSV
// Run via: #include "C:/AI/tests/TestMalloc.HC";

U0 TestMalloc() {
  U8 out[2048];
  U8 line[128];
  U8 *p;
  U8 *s;
  I64 i, sz;

  StrCpy(out, "name\tstatus\tdetail\n");

  // alloc 1 byte returns non-null
  p = MAlloc(1);
  if (p != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "alloc_1_nonnull\t%s\t%d\n", s, p != 0);
  CatPrint(out, "%s", line);
  Free(p);

  // alloc 1024 bytes returns non-null
  p = MAlloc(1024);
  if (p != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "alloc_1024_nonnull\t%s\t%d\n", s, p != 0);
  CatPrint(out, "%s", line);
  Free(p);

  // MSize >= requested size
  p = MAlloc(256);
  sz = MSize(p);
  if (sz >= 256) s = "PASS"; else s = "FAIL";
  StrPrint(line, "msize_256\t%s\t%d\n", s, sz);
  CatPrint(out, "%s", line);
  Free(p);

  // 100x alloc/free loop — no crash = PASS
  for (i = 0; i < 100; i++) {
    p = MAlloc(64);
    Free(p);
  }
  CatPrint(out, "loop_100_alloc_free\tPASS\t100\n");

  FileWrite("C:/AI/results/TestMalloc.txt", out, StrLen(out));
}

TestMalloc;
