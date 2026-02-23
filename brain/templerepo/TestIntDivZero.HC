// TestIntDivZero.HC — Division by zero: does REPL survive?
// SerReplExe wraps ExeFile in try/catch so exception should be caught.
U0 TestIntDivZero() {
  U8 out[256];
  I64 x, y, r;

  Del("C:/AI/results/TestIntDivZero.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  x = 1;
  y = 0;
  r = x / y;

  // Should not reach here if exception is thrown
  CatPrint(out, "divzero\tOBS\tsurvived\n");

  FileWrite("C:/AI/results/TestIntDivZero.txt", out, StrLen(out));
}
TestIntDivZero;
