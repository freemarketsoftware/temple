// TestMallocEdge4.HC — MSize(NULL): null pointer dereference?
// Called by TestRunner with shared output buffer

U0 TestMallocEdge4(U8 *out) {
  U8 line[128];
  I64 sz;

  sz = MSize(0);
  StrPrint(line, "msize_null\tOBS\t%d\n", sz);
  CatPrint(out, "%s", line);
}
