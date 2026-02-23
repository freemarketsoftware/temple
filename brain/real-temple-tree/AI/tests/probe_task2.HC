
I64 g_t1 = 0;
I64 g_t2 = 0;
U0 TaskT1(I64 d) { g_t1 = 1; }
U0 TaskT2(I64 d) { g_t2 = 1; }
U0 TaskLoop(I64 d) { while(1) Yield; }

U0 RunProbes2() {
  U8 buf[512];
  CTask *pt;
  I64 vld;

  // Test 4: two sequential tasks
  g_t1 = 0; g_t2 = 0;
  pt = Spawn(&TaskT1, 0, "T1"); DeathWait(&pt);
  pt = Spawn(&TaskT2, 0, "T2"); DeathWait(&pt);
  StrPrint(buf, "two_seq=%d_%d
", g_t1, g_t2);

  // Test 5: TaskValidate on live task
  pt = Spawn(&TaskLoop, 0, "TLive");
  vld = TaskValidate(pt);
  Kill(pt);
  CatPrint(buf, "validate_live=%d
", vld);

  // Test 6: TaskValidate(NULL)
  CatPrint(buf, "validate_null=%d
", TaskValidate(NULL));

  // Test 7: Yield() without crash
  Yield;
  CatPrint(buf, "yield_ok=1
");

  // Test 8: Kill looping task (wait=TRUE default)
  pt = Spawn(&TaskLoop, 0, "TKill");
  Kill(pt);
  CatPrint(buf, "kill_ok=1
");

  FileWrite("C:/AI/results/probe_tasks2.txt", buf, StrLen(buf));
}
RunProbes2;
