// TestStrEdge.HC — String API edge cases
// StrPrint return value, StrNew heap copy, StrCpy return, CatPrint return

U0 TestStrEdge(U8 *out) {
  U8 line[128];
  U8 *s;
  U8 buf[64];
  U8 *rv;
  U8 *p;
  I64 ok;

  // StrPrint returns dst pointer
  rv = StrPrint(buf, "hello");
  ok = (rv == buf);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strprint_retval\t%s\t\n", s);
  CatPrint(out, line);

  // StrPrint with no format args (literal string)
  StrPrint(buf, "world");
  ok = (StrCmp(buf, "world") == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strprint_literal\t%s\t\n", s);
  CatPrint(out, line);

  // StrPrint with empty format string -> empty dst
  StrPrint(buf, "");
  ok = (StrLen(buf) == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strprint_empty_fmt\t%s\tlen=%d\n", s, StrLen(buf));
  CatPrint(out, line);

  // StrCpy is U0 (void) — no return value; verify effect instead
  StrCpy(buf, "testval");
  ok = (StrCmp(buf, "testval") == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strcpy_void_effect\t%s\t\n", s);
  CatPrint(out, line);

  // StrNew: heap copy is non-null
  p = StrNew("hello");
  ok = (p != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strnew_nonnull\t%s\t\n", s);
  CatPrint(out, line);

  // StrNew: content matches
  ok = (StrCmp(p, "hello") == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strnew_content\t%s\t\n", s);
  CatPrint(out, line);

  // StrNew: different pointer from literal (heap allocated)
  ok = (p != "hello");
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strnew_heap_ptr\t%s\t\n", s);
  CatPrint(out, line);

  Free(p);

  // StrNew("") — empty string heap copy
  p = StrNew("");
  ok = (p != 0 && StrLen(p) == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "strnew_empty\t%s\t\n", s);
  CatPrint(out, line);

  Free(p);

  // CatPrint returns dst
  StrCpy(buf, "a");
  rv = CatPrint(buf, "b");
  ok = (rv == buf && StrCmp(buf, "ab") == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "catprint_retval\t%s\tcontent=%s\n", s, buf);
  CatPrint(out, line);
}
