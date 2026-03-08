// TestDefine.HC — HolyC #define macro coverage
// Tests constant #define (object-like macros only — function-like macros
// with arguments appear to corrupt the HolyC JIT preprocessor state).

#define TD_CONST_A  0xABCD
#define TD_CONST_B  42
#define TD_CONST_C  -77
#define TD_BITS_7   0x7F
#define TD_BITS_ALL 0xFFFFFFFFFFFFFFFF

U0 TestDefine(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 r;

  // constant hex macro
  r = TD_CONST_A;
  if (r == 0xABCD) s = "PASS"; else s = "FAIL";
  StrPrint(line, "define_hex_const\t%s\tgot=%X\n", s, r);
  CatPrint(out, line);

  // constant integer macro
  r = TD_CONST_B;
  if (r == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "define_int_const\t%s\tgot=%d\n", s, r);
  CatPrint(out, line);

  // negative constant macro
  r = TD_CONST_C;
  if (r == -77) s = "PASS"; else s = "FAIL";
  StrPrint(line, "define_neg_const\t%s\tgot=%d\n", s, r);
  CatPrint(out, line);

  // bitmask constant
  r = TD_BITS_7;
  if (r == 0x7F) s = "PASS"; else s = "FAIL";
  StrPrint(line, "define_bitmask\t%s\tgot=%X\n", s, r);
  CatPrint(out, line);

  // all-bits-set constant (-1 as I64)
  r = TD_BITS_ALL;
  if (r == -1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "define_allbits\t%s\tgot=%d\n", s, r);
  CatPrint(out, line);

  // macro in arithmetic expression
  r = TD_CONST_B * 2;
  if (r == 84) s = "PASS"; else s = "FAIL";
  StrPrint(line, "define_in_expr\t%s\tgot=%d\n", s, r);
  CatPrint(out, line);

  // macro in comparison
  r = 0;
  if (TD_CONST_B == 42) r = 1;
  if (r == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "define_in_cond\t%s\tgot=%d\n", s, r);
  CatPrint(out, line);

  // two macros in same expression
  r = TD_CONST_A + TD_CONST_B;
  if (r == 0xABCD + 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "define_two_macros\t%s\tgot=%d\n", s, r);
  CatPrint(out, line);

  // macro used as array index-like shift
  r = 1 << 7;
  if (r == TD_BITS_7 + 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "define_shift_check\t%s\tgot=%d\n", s, r);
  CatPrint(out, line);
}
