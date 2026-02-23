// TestStrUtil.HC — StrUtil (case/whitespace), StrFind, StrIMatch
// Called by TestRunner with shared output buffer

U0 TestStrUtil(U8 *out) {
  U8 line[128];
  U8 buf[64];
  U8 *s, *r;

  // --- SUF_TO_UPPER: "hello" -> "HELLO" ---
  StrCpy(buf, "hello");
  StrUtil(buf, SUF_TO_UPPER);
  if (StrCmp(buf, "HELLO") == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "to_upper\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- SUF_TO_LOWER: "HELLO" -> "hello" ---
  StrCpy(buf, "HELLO");
  StrUtil(buf, SUF_TO_LOWER);
  if (StrCmp(buf, "hello") == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "to_lower\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- SUF_REM_LEADING: "  hello" -> "hello" ---
  StrCpy(buf, "  hello");
  StrUtil(buf, SUF_REM_LEADING);
  if (StrCmp(buf, "hello") == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rem_leading\t%s\t|%s|\n", s, buf);
  CatPrint(out, "%s", line);

  // --- SUF_REM_TRAILING: "hello  " -> "hello" ---
  StrCpy(buf, "hello  ");
  StrUtil(buf, SUF_REM_TRAILING);
  if (StrCmp(buf, "hello") == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rem_trailing\t%s\t|%s|\n", s, buf);
  CatPrint(out, "%s", line);

  // --- SUF_REM_SPACES: "he ll o" -> "hello" ---
  StrCpy(buf, "he ll o");
  StrUtil(buf, SUF_REM_SPACES);
  if (StrCmp(buf, "hello") == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rem_spaces\t%s\t|%s|\n", s, buf);
  CatPrint(out, "%s", line);

  // --- SUF_SINGLE_SPACE: "a   b" -> "a b" ---
  StrCpy(buf, "a   b");
  StrUtil(buf, SUF_SINGLE_SPACE);
  if (StrCmp(buf, "a b") == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "single_space\t%s\t|%s|\n", s, buf);
  CatPrint(out, "%s", line);

  // --- StrFind: found ---
  r = StrFind("lo", "hello world", 0);
  if (r != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strfind_found\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- StrFind: not found ---
  r = StrFind("xyz", "hello world", 0);
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strfind_notfound\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- StrFind: case-insensitive (SFF_IGNORE_CASE=1) ---
  r = StrFind("LO", "hello world", SFF_IGNORE_CASE);
  if (r != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strfind_nocase\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- StrIMatch: case-insensitive find ---
  r = StrIMatch("WOR", "hello world");
  if (r != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strimatch_found\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- StrIMatch: not found ---
  r = StrIMatch("ZZZ", "hello world");
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strimatch_notfound\t%s\t\n", s);
  CatPrint(out, "%s", line);
}
