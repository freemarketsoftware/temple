// TestMallocEdge2d.HC — binary search: 320MB
U0 TestMallocEdge2d() {
  U8 out[256];
  U8 *p;

  Del("C:/AI/results/TestMallocEdge2d.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  p = MAlloc(320 * 1024 * 1024);
  if (p != 0) {
    CatPrint(out, "alloc_320mb\tOBS\tnonnull\n");
    Free(p);
    CatPrint(out, "free_320mb\tOBS\tsurvived\n");
  } else {
    CatPrint(out, "alloc_320mb\tOBS\tnull\n");
  }

  FileWrite("C:/AI/results/TestMallocEdge2d.txt", out, StrLen(out));
}
TestMallocEdge2d;
