// TestMallocEdge2.HC — Large allocations: how does TempleOS handle near-limit requests?
U0 TestMallocEdge2() {
  U8 out[512];
  U8 line[128];
  U8 *p;

  Del("C:/AI/results/TestMallocEdge2.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  // 256MB — large but plausible
  p = MAlloc(256 * 1024 * 1024);
  if (p != 0) {
    CatPrint(out, "alloc_256mb\tOBS\tnonnull\n");
    Free(p);
    CatPrint(out, "free_256mb\tOBS\tsurvived\n");
  } else {
    CatPrint(out, "alloc_256mb\tOBS\tnull\n");
  }

  // 512MB
  p = MAlloc(512 * 1024 * 1024);
  if (p != 0) {
    CatPrint(out, "alloc_512mb\tOBS\tnonnull\n");
    Free(p);
    CatPrint(out, "free_512mb\tOBS\tsurvived\n");
  } else {
    CatPrint(out, "alloc_512mb\tOBS\tnull\n");
  }

  FileWrite("C:/AI/results/TestMallocEdge2.txt", out, StrLen(out));
}
TestMallocEdge2;
