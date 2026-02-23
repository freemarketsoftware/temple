// TestMallocEdge4.HC — MSize(NULL): null pointer dereference?
U0 TestMallocEdge4() {
  U8 out[256];
  I64 sz;

  Del("C:/AI/results/TestMallocEdge4.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  sz = MSize(0);

  StrPrint(out, "%s%s%d%s", out, "msize_null\tOBS\t", sz, "\n");
  FileWrite("C:/AI/results/TestMallocEdge4.txt", out, StrLen(out));
}
TestMallocEdge4;
