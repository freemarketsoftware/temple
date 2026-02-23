// TestStrings.HC — Unit tests for string functions
// Tests: StrLen, StrCpy, StrCmp, StrICmp, StrNCmp, StrMatch, StrOcc, StrNew, CatPrint
// Results written to C:/AI/results/TestStrings.txt as TSV
// Run via: #include "C:/AI/tests/TestStrings.HC";

U0 TestStrings() {
  U8 out[4096];
  U8 line[128];
  U8 buf[128];
  U8 *s;
  I64 r;
  U8 *p;

  Del("C:/AI/results/TestStrings.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  // --- StrLen ---
  r = StrLen("");
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strlen_empty\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = StrLen("hello");
  if (r == 5) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strlen_hello\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = StrLen("a");
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strlen_one\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- StrCpy ---
  StrCpy(buf, "hello");
  r = StrCmp(buf, "hello");
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strcpy_roundtrip\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  StrCpy(buf, "");
  r = StrLen(buf);
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strcpy_empty\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- StrCmp ---
  r = StrCmp("abc", "abc");
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strcmp_equal\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = StrCmp("a", "b");
  if (r < 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strcmp_less\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = StrCmp("b", "a");
  if (r > 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strcmp_greater\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = StrCmp("abc", "abcd");
  if (r < 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strcmp_prefix_shorter\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- StrICmp ---
  r = StrICmp("Hello", "hello");
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "stricmp_case\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = StrICmp("ABC", "abc");
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "stricmp_upper_lower\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = StrICmp("a", "b");
  if (r != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "stricmp_different\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- StrNCmp ---
  r = StrNCmp("abcXXX", "abcYYY", 3);
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strncmp_equal_prefix\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = StrNCmp("abc", "abd", 3);
  if (r != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strncmp_diff\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- StrMatch ---
  p = StrMatch("ll", "hello");
  if (p != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strmatch_found\t%s\t%d\n", s, p != 0);
  CatPrint(out, "%s", line);

  p = StrMatch("xyz", "hello");
  if (p == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strmatch_not_found\t%s\t%d\n", s, p == 0);
  CatPrint(out, "%s", line);

  p = StrMatch("hello", "hello");
  if (p != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strmatch_full\t%s\t%d\n", s, p != 0);
  CatPrint(out, "%s", line);

  // --- StrOcc ---
  r = StrOcc("hello world", 'l');
  if (r == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strocc_l_in_hello_world\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  r = StrOcc("hello", 'z');
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strocc_not_found\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- StrNew ---
  p = StrNew("teststr");
  r = StrCmp(p, "teststr");
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strnew_copy\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);
  Free(p);

  // --- CatPrint ---
  StrCpy(buf, "foo");
  CatPrint(buf, "%s", "bar");
  r = StrCmp(buf, "foobar");
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "catprint_append\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  StrCpy(buf, "");
  CatPrint(buf, "%s", "hello");
  r = StrCmp(buf, "hello");
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "catprint_from_empty\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  FileWrite("C:/AI/results/TestStrings.txt", out, StrLen(out));
}

TestStrings;
