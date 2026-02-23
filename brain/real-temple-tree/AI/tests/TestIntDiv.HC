// TestIntDiv.HC — Integer division behavior: truncation, sign, modulo
// Called by TestRunner with shared output buffer

U0 TestIntDiv(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 r;

  // --- truncation toward zero ---
  r = 7 / 2;
  if (r == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "div_7_2\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = 8 / 2;
  if (r == 4) s = "PASS"; else s = "FAIL";
  StrPrint(line, "div_8_2\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = 1 / 2;
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "div_1_2\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- negative dividend ---
  r = -7 / 2;
  if (r == -3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "div_neg7_2\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = -8 / 2;
  if (r == -4) s = "PASS"; else s = "FAIL";
  StrPrint(line, "div_neg8_2\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- negative divisor ---
  r = 7 / -2;
  if (r == -3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "div_7_neg2\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- both negative ---
  r = -7 / -2;
  if (r == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "div_neg7_neg2\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- modulo ---
  r = 7 % 3;
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mod_7_3\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = 9 % 3;
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mod_9_3\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- negative modulo: sign follows dividend (C truncation-toward-zero) ---
  r = -7 % 3;
  if (r == -1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mod_neg7_3\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = 7 % -3;
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mod_7_neg3\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = -7 % -3;
  if (r == -1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mod_neg7_neg3\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- I64_MAX / I64_MAX ---
  r = I64_MAX / I64_MAX;
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "div_i64max_self\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- I64_MAX % 2 ---
  r = I64_MAX % 2;
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mod_i64max_2\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);
}
