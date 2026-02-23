// TestException.HC — Comprehensive exception handling tests
// try/catch/throw, hardware exceptions, nesting, cross-function propagation
// Called by TestRunner with shared output buffer

// Helper: throws an exception from a called function
U0 ExThrowHelper(I64 code) {
  throw(code);
}

// Helper: throws div-by-zero from a called function
U0 ExDivHelper() {
  I64 x = 1, y = 0, r;
  r = x / y;
}

U0 TestException(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 x, y, r;

  // --- 1. Basic throw/catch ---
  s = "FAIL";
  try {
    throw('Test1');
  } catch {
    if (Fs->except_ch == 'Test1') s = "PASS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "basic_throw_catch\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 2. Normal try block — catch must NOT run ---
  r = 0;
  try {
    r = 42;
  } catch {
    r = -1;
    Fs->catch_except = TRUE;
  }
  if (r == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "try_no_exception\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 3. Code after throw is NOT reached ---
  r = 0;
  try {
    throw('Skip');
    r = 99;
  } catch {
    Fs->catch_except = TRUE;
  }
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "code_after_throw\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 4. Fs->except_ch holds the thrown code ---
  s = "FAIL";
  try {
    throw('Magic');
  } catch {
    if (Fs->except_ch == 'Magic') s = "PASS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "except_ch_correct\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 5. Catch hardware div-by-zero ---
  s = "FAIL";
  x = 5; y = 0;
  try {
    r = x / y;
  } catch {
    if (Fs->except_ch == 'DivZero') s = "PASS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "catch_divzero\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 6. Multiple sequential try/catch blocks in same function ---
  s = "FAIL";
  try { throw('SeqA'); } catch {
    if (Fs->except_ch == 'SeqA') s = "PASS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "sequential_a\t%s\t\n", s);
  CatPrint(out, "%s", line);

  s = "FAIL";
  try { throw('SeqB'); } catch {
    if (Fs->except_ch == 'SeqB') s = "PASS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "sequential_b\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 7. Nested try/catch: inner catches its own exception ---
  s = "FAIL";
  try {
    try {
      throw('Inner');
    } catch {
      if (Fs->except_ch == 'Inner') s = "PASS";
      Fs->catch_except = TRUE;
    }
  } catch {
    s = "FAIL";  // must NOT reach here
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "nested_inner_catches\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 8. Nested: exception propagates to outer when inner doesn't catch ---
  s = "FAIL";
  try {
    try {
      throw('Outer');
    } catch {
      // deliberately do not set catch_except — let it propagate
    }
  } catch {
    if (Fs->except_ch == 'Outer') s = "PASS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "nested_propagate\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 9. Exception from called function caught in caller ---
  s = "FAIL";
  try {
    ExThrowHelper('Callee');
  } catch {
    if (Fs->except_ch == 'Callee') s = "PASS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "cross_fn_catch\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 10. Div-by-zero in called function caught in caller ---
  s = "FAIL";
  try {
    ExDivHelper();
  } catch {
    if (Fs->except_ch == 'DivZero') s = "PASS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "cross_fn_divzero\t%s\t\n", s);
  CatPrint(out, "%s", line);

  // --- 11. Execution continues normally after caught exception ---
  r = 0;
  try {
    throw('Cont');
    r = 1;
  } catch {
    Fs->catch_except = TRUE;
  }
  r = r + 10;  // must reach here, r == 10
  if (r == 10) s = "PASS"; else s = "FAIL";
  StrPrint(line, "continues_after_catch\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 12. throw with default code 0 ---
  s = "FAIL";
  try {
    throw(0);
  } catch {
    if (Fs->except_ch == 0) s = "PASS";
    Fs->catch_except = TRUE;
  }
  StrPrint(line, "throw_zero\t%s\t\n", s);
  CatPrint(out, "%s", line);
}
