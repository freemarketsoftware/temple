// TestFmtSpec.HC — StrPrint format specifier coverage
// %d %u %x %X %b %f %e %g %n %c %p %% width padding comma truncate
// Called by TestRunner with shared output buffer

U0 TestFmtSpec(U8 *out) {
  U8 line[256];
  U8 buf[128];
  U8 *s;
  F64 fv;

  // --- %d decimal (baseline) ---
  StrPrint(buf, "%d", 12345);
  if (!StrCmp(buf, "12345")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_d\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %d negative ---
  StrPrint(buf, "%d", -42);
  if (!StrCmp(buf, "-42")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_d_neg\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %u unsigned: -1 should print as 18446744073709551615 ---
  StrPrint(buf, "%u", -1);
  if (!StrCmp(buf, "18446744073709551615")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_u_neg1\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %x lowercase hex ---
  StrPrint(buf, "%x", 0xDEAD);
  if (!StrCmp(buf, "dead")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_x_lower\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %X uppercase hex ---
  StrPrint(buf, "%X", 0xDEAD);
  if (!StrCmp(buf, "DEAD")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_X_upper\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %b binary ---
  StrPrint(buf, "%b", 5);
  if (!StrCmp(buf, "101")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_b_binary\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %b binary larger value ---
  StrPrint(buf, "%b", 0xFF);
  if (!StrCmp(buf, "11111111")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_b_ff\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %f default (0 decimal places) ---
  StrPrint(buf, "%f", 3.14);
  if (!StrCmp(buf, "3")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_f_default\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %.2f two decimal places ---
  StrPrint(buf, "%.2f", 3.14);
  if (!StrCmp(buf, "3.14")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_f_2dp\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %.4f four decimal places ---
  StrPrint(buf, "%.4f", 3.14159);
  if (!StrCmp(buf, "3.1416")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_f_4dp\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %e scientific notation ---
  StrPrint(buf, "%e", 12345.0);
  StrPrint(line, "fmt_e\tOBS\t%s\n", buf);
  CatPrint(out, "%s", line);

  // --- %g general float ---
  StrPrint(buf, "%g", 12345.0);
  StrPrint(line, "fmt_g\tOBS\t%s\n", buf);
  CatPrint(out, "%s", line);

  // --- %n engineering notation ---
  StrPrint(buf, "%n", 1500.0);
  StrPrint(line, "fmt_n_1500\tOBS\t%s\n", buf);
  CatPrint(out, "%s", line);

  StrPrint(buf, "%n", 2500000.0);
  StrPrint(line, "fmt_n_2500000\tOBS\t%s\n", buf);
  CatPrint(out, "%s", line);

  // --- %c character ---
  StrPrint(buf, "%c", 'A');
  if (!StrCmp(buf, "A")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_c\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %% literal percent ---
  StrPrint(buf, "100%%");
  if (!StrCmp(buf, "100%")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_percent\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %5d right-align width ---
  StrPrint(buf, "%5d", 42);
  if (!StrCmp(buf, "   42")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_width_right\t%s\t'%s'\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %-5d left-align width — minus flag ignored, still right-aligns ---
  StrPrint(buf, "%-5d", 42);
  StrPrint(line, "fmt_width_left\tOBS\t'%s'\n", buf);
  CatPrint(out, "%s", line);

  // --- %05d zero-pad ---
  StrPrint(buf, "%05d", 42);
  if (!StrCmp(buf, "00042")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_zeropad\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %08X zero-padded hex ---
  StrPrint(buf, "%08X", 0xABC);
  if (!StrCmp(buf, "00000ABC")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_zeropad_hex\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %,d comma thousands separator ---
  StrPrint(buf, "%,d", 1234567);
  if (!StrCmp(buf, "1,234,567")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_comma_d\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %,X comma hex groups by 4 ---
  StrPrint(buf, "%,X", 0xDEADBEEF);
  if (!StrCmp(buf, "DEAD,BEEF")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_comma_X\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);

  // --- %p pointer (observe format) ---
  I64 local = 42;
  StrPrint(buf, "%p", &local);
  StrPrint(line, "fmt_p_ptr\tOBS\t%s\n", buf);
  CatPrint(out, "%s", line);

  // --- multiple args in one StrPrint ---
  StrPrint(buf, "%d + %d = %d", 3, 4, 7);
  if (!StrCmp(buf, "3 + 4 = 7")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "fmt_multi_args\t%s\t%s\n", s, buf);
  CatPrint(out, "%s", line);
}
