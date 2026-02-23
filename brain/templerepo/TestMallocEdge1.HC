// TestMallocEdge1.HC — MAlloc(0): what does zero-size allocation return?
U0 TestMallocEdge1() {
  U8 out[512];
  U8 line[128];
  U8 *s;
  U8 *p;
  I64 sz;

  Del("C:/AI/results/TestMallocEdge1.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  p = MAlloc(0);
  // Record what we got — no assertion, just observe
  if (p != 0) s = "nonnull"; else s = "null";
  StrPrint(line, "malloc_0_ptr\tOBS\t%s\n", s);
  CatPrint(out, "%s", line);

  // If non-null, check MSize
  if (p != 0) {
    sz = MSize(p);
    StrPrint(line, "malloc_0_msize\tOBS\t%d\n", sz);
    CatPrint(out, "%s", line);
    Free(p);
    CatPrint(out, "malloc_0_free\tOBS\tsurvived\n");
  }

  FileWrite("C:/AI/results/TestMallocEdge1.txt", out, StrLen(out));
}
TestMallocEdge1;
