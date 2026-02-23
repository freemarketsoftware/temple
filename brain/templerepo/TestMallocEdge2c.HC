// TestMallocEdge2c.HC — find panic threshold between 256MB and 512MB
U0 TestMallocEdge2c() {
  U8 out[256];
  U8 *p;

  Del("C:/AI/results/TestMallocEdge2c.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  p = MAlloc(384 * 1024 * 1024);
  if (p != 0) {
    CatPrint(out, "alloc_384mb\tOBS\tnonnull\n");
    Free(p);
    CatPrint(out, "free_384mb\tOBS\tsurvived\n");
  } else {
    CatPrint(out, "alloc_384mb\tOBS\tnull\n");
  }

  FileWrite("C:/AI/results/TestMallocEdge2c.txt", out, StrLen(out));
}
TestMallocEdge2c;
