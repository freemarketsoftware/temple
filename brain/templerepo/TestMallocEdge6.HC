// TestMallocEdge6.HC — Does MAlloc reuse freed addresses?
// Also: MSize on a freed pointer
U0 TestMallocEdge6() {
  U8 out[512];
  U8 line[128];
  U8 *p1, *p2;
  I64 sz;

  StrCpy(out, "name\tstatus\tdetail\n");

  // Alloc, free, alloc same size — same address returned?
  p1 = MAlloc(64);
  Free(p1);
  p2 = MAlloc(64);
  if (p1 == p2) {
    CatPrint(out, "reuse_same_addr\tOBS\tyes\n");
  } else {
    CatPrint(out, "reuse_same_addr\tOBS\tno\n");
  }
  Free(p2);

  // MSize on freed pointer — what does it report?
  p1 = MAlloc(128);
  Free(p1);
  sz = MSize(p1);
  StrPrint(line, "msize_freed\tOBS\t%d\n", sz);
  CatPrint(out, "%s", line);

  FileWrite("C:/AI/results/TestMallocEdge6.txt", out, StrLen(out));
}
TestMallocEdge6;
