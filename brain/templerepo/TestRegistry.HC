// TestRegistry.HC — RegWrite, RegExe, RegDft, RegCnt
// Tests the TempleOS registry (persisted in ~/Registry.HC.Z).
// Uses paths under "AI/Tests/" — clean on each snap1 restore.
// Safe for TestRunner — no screen ops, no hardware.
//
// RegWrite(path, fmt, ...) → Bool — overwrites branch; FALSE if new, TRUE if existed
// RegExe(path) → I64  — compiles + executes stored HolyC code; 0 if missing
// RegDft(path, code, is_adam) → Bool — sets default if absent; FALSE if new, TRUE if existed
// RegCnt(path) → I64  — CDocEntry count in branch; 0 if missing
//
// Stored code format: "42;\n" → RegExe returns 42 (result of last expression)

U0 TestRegistry(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 ri;
  I64 rv;

  // 1. reg_write_read — write integer code fragment, read back via RegExe
  RegWrite("AI/Tests/WriteRead", "%d;\n", 42);
  ri = RegExe("AI/Tests/WriteRead");
  if (ri == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "reg_write_read\t%s\t%d\n", s, ri);
  CatPrint(out, "%s", line);

  // 2. reg_write_overwrite — second write overwrites first; second value wins
  RegWrite("AI/Tests/Overwrite", "%d;\n", 10);
  RegWrite("AI/Tests/Overwrite", "%d;\n", 20);
  ri = RegExe("AI/Tests/Overwrite");
  if (ri == 20) s = "PASS"; else s = "FAIL";
  StrPrint(line, "reg_write_overwrite\t%s\t%d\n", s, ri);
  CatPrint(out, "%s", line);

  // 3. reg_write_negative — negative integer survives round-trip
  RegWrite("AI/Tests/Negative", "%d;\n", -77);
  ri = RegExe("AI/Tests/Negative");
  if (ri == -77) s = "PASS"; else s = "FAIL";
  StrPrint(line, "reg_write_negative\t%s\t%d\n", s, ri);
  CatPrint(out, "%s", line);

  // 4. reg_exe_missing — RegExe on absent key returns 0
  ri = RegExe("AI/Tests/DoesNotExist_zzz");
  if (ri == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "reg_exe_missing\t%s\t%d\n", s, ri);
  CatPrint(out, "%s", line);

  // 5. reg_write_retval_new — RegWrite returns 0 (FALSE) when key is new
  rv = RegWrite("AI/Tests/RetvalNew", "%d;\n", 1);
  if (rv == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "reg_write_retval_new\t%s\t%d\n", s, rv);
  CatPrint(out, "%s", line);

  // 6. reg_write_retval_old — RegWrite returns 1 (TRUE) when key already existed
  rv = RegWrite("AI/Tests/RetvalNew", "%d;\n", 2);
  if (rv == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "reg_write_retval_old\t%s\t%d\n", s, rv);
  CatPrint(out, "%s", line);

  // 7. reg_dft_new — RegDft on absent key: returns 0 (FALSE=new), value is set
  rv = RegDft("AI/Tests/DftNew", "99;\n", FALSE);
  ri = RegExe("AI/Tests/DftNew");
  if (rv == 0 && ri == 99) s = "PASS"; else s = "FAIL";
  StrPrint(line, "reg_dft_new\t%s\trv=%d val=%d\n", s, rv, ri);
  CatPrint(out, "%s", line);

  // 8. reg_dft_present — RegDft on present key: returns 1 (TRUE=existed), value unchanged
  RegWrite("AI/Tests/DftPresent", "%d;\n", 55);
  rv = RegDft("AI/Tests/DftPresent", "99;\n", FALSE);
  ri = RegExe("AI/Tests/DftPresent");
  if (rv == 1 && ri == 55) s = "PASS"; else s = "FAIL";
  StrPrint(line, "reg_dft_present\t%s\trv=%d val=%d\n", s, rv, ri);
  CatPrint(out, "%s", line);

  // 9. reg_cnt_nonzero — RegCnt > 0 for a branch with content
  RegWrite("AI/Tests/CntTest", "%d;\n", 1);
  ri = RegCnt("AI/Tests/CntTest");
  if (ri > 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "reg_cnt_nonzero\t%s\t%d\n", s, ri);
  CatPrint(out, "%s", line);

  // 10. reg_cnt_missing — RegCnt returns 0 for a missing path
  ri = RegCnt("AI/Tests/DoesNotExist_zzz");
  if (ri == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "reg_cnt_missing\t%s\t%d\n", s, ri);
  CatPrint(out, "%s", line);
}
