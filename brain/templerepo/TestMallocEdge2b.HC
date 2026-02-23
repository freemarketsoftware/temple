// TestMallocEdge2b.HC — 256MB allocation only
U0 TestMallocEdge2b() {
  U8 out[256];
  U8 *p;

  Del("C:/AI/results/TestMallocEdge2b.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  p = MAlloc(256 * 1024 * 1024);
  if (p != 0) {
    CatPrint(out, "alloc_256mb\tOBS\tnonnull\n");
    Free(p);
    CatPrint(out, "free_256mb\tOBS\tsurvived\n");
  } else {
    CatPrint(out, "alloc_256mb\tOBS\tnull\n");
  }

  FileWrite("C:/AI/results/TestMallocEdge2b.txt", out, StrLen(out));
}
TestMallocEdge2b;
