// TestMallocEdge3.HC — Double-free: does TempleOS detect it or corrupt silently?
U0 TestMallocEdge3() {
  U8 out[256];
  U8 *p;

  StrCpy(out, "name\tstatus\tdetail\n");

  p = MAlloc(64);
  Free(p);
  // Double-free — may panic here
  Free(p);

  // If we reach here, double-free survived
  CatPrint(out, "double_free\tOBS\tsurvived\n");

  FileWrite("C:/AI/results/TestMallocEdge3.txt", out, StrLen(out));
}
TestMallocEdge3;
