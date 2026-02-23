// TestDateTime.HC — Date/time functions: Now, Date2Struct, SysTimerRead, tS, Sleep
// Tests clock ticks, date field ranges, timer monotonicity, and sleep duration.
// Called by TestRunner with shared output buffer.
//
// SKIPPED (panic from JIT context):
//   Struct2Date       — crashes when called from dynamically-compiled code
//   NowDateTimeStruct — same; both are only safe when called from kernel context

U0 TestDateTime(U8 *out) {
  U8 line[128];
  U8 *s;
  CDate d1;
  CDate d2;
  CDateStruct ds;
  I64 t1;
  I64 t2;
  F64 f1;
  F64 f2;

  // --- Now() returns nonzero ---
  d1 = Now();
  if (d1.date != 0 || d1.time != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "now_nonzero\t%s\t%d/%d\n", s, d1.date, d1.time);
  CatPrint(out, "%s", line);

  // --- Date2Struct produces valid year ---
  Date2Struct(&ds, d1);
  if (ds.year >= 2000 && ds.year <= 2100) s = "PASS"; else s = "FAIL";
  StrPrint(line, "year_range\t%s\t%d\n", s, ds.year);
  CatPrint(out, "%s", line);

  // --- Month 1-12 ---
  if (ds.mon >= 1 && ds.mon <= 12) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mon_range\t%s\t%d\n", s, ds.mon);
  CatPrint(out, "%s", line);

  // --- Day 1-31 ---
  if (ds.day_of_mon >= 1 && ds.day_of_mon <= 31) s = "PASS"; else s = "FAIL";
  StrPrint(line, "day_range\t%s\t%d\n", s, ds.day_of_mon);
  CatPrint(out, "%s", line);

  // --- Hour 0-23 ---
  if (ds.hour >= 0 && ds.hour <= 23) s = "PASS"; else s = "FAIL";
  StrPrint(line, "hour_range\t%s\t%d\n", s, ds.hour);
  CatPrint(out, "%s", line);

  // --- Min 0-59 ---
  if (ds.min >= 0 && ds.min <= 59) s = "PASS"; else s = "FAIL";
  StrPrint(line, "min_range\t%s\t%d\n", s, ds.min);
  CatPrint(out, "%s", line);

  // --- Sec 0-59 ---
  if (ds.sec >= 0 && ds.sec <= 59) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sec_range\t%s\t%d\n", s, ds.sec);
  CatPrint(out, "%s", line);

  // --- day_of_week 0-6 ---
  if (ds.day_of_week >= 0 && ds.day_of_week <= 6) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dow_range\t%s\t%d\n", s, ds.day_of_week);
  CatPrint(out, "%s", line);

  // --- SysTimerRead() is monotonic over two calls ---
  t1 = SysTimerRead();
  t2 = SysTimerRead();
  if (t2 >= t1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "timer_monotonic\t%s\t%d->%d\n", s, t1, t2);
  CatPrint(out, "%s", line);

  // --- SysTimerRead() advances after Sleep(50) ---
  t1 = SysTimerRead();
  Sleep(50);
  t2 = SysTimerRead();
  if (t2 > t1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "timer_advances\t%s\tdelta=%d\n", s, t2 - t1);
  CatPrint(out, "%s", line);

  // --- tS() is positive ---
  f1 = tS();
  if (f1 > 0.0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ts_positive\t%s\t%f\n", s, f1);
  CatPrint(out, "%s", line);

  // --- tS() advances after Sleep(50) ---
  f1 = tS();
  Sleep(50);
  f2 = tS();
  if (f2 > f1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ts_advances\t%s\tdelta=%f\n", s, f2 - f1);
  CatPrint(out, "%s", line);

  // --- Now() is monotonic (date field should not go backward) ---
  d1 = Now();
  d2 = Now();
  if (d2.date > d1.date || (d2.date == d1.date && d2.time >= d1.time))
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "now_monotonic\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Now() returns consistent year across two calls ---
  Date2Struct(&ds, Now());
  t1 = ds.year;
  Date2Struct(&ds, Now());
  if (ds.year == t1) s = "PASS"; else s = "OBS";
  StrPrint(line, "year_stable\t%s\t%d\n", s, t1);
  CatPrint(out, "%s", line);
}
