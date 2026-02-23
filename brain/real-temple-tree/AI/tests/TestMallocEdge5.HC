// TestMallocEdge5.HC — Use-after-free: write to freed memory, then alloc again
// Called by TestRunner with shared output buffer

U0 TestMallocEdge5(U8 *out) {
  U8 *p;
  U8 *q;

  p = MAlloc(64);
  Free(p);

  // Write to freed memory — may corrupt heap or panic
  p[0] = 0x41;

  CatPrint(out, "write_after_free\tOBS\tsurvived\n");

  // Alloc again — heap may be corrupted
  q = MAlloc(64);
  if (q != 0) {
    CatPrint(out, "alloc_after_uaf\tOBS\tnonnull\n");
    Free(q);
  } else {
    CatPrint(out, "alloc_after_uaf\tOBS\tnull\n");
  }
}
