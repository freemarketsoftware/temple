
I64 g_probe1 = 0;
I64 g_probe2 = 0;
U0 ProbeTask1(I64 d) { g_probe1 = 99; }
U0 ProbeTask2(I64 arg) { g_probe2 = arg; }

U0 RunProbes() {
  U8 buf[512];
  CTask *pt;

  // Test 1: basic spawn + DeathWait
  g_probe1 = 0;
  pt = Spawn(&ProbeTask1, 0, "P1");
  DeathWait(&pt);
  StrPrint(buf, "spawn_basic=%d
", g_probe1);

  // Test 2: DeathWait sets pointer to NULL
  pt = Spawn(&ProbeTask1, 0, "P2");
  DeathWait(&pt);
  CatPrint(buf, "deathwait_null=%d
", pt == NULL);

  // Test 3: arg passing (I64 42)
  g_probe2 = 0;
  pt = Spawn(&ProbeTask2, 42, "P3");
  DeathWait(&pt);
  CatPrint(buf, "spawn_arg=%d
", g_probe2);

  FileWrite("C:/AI/results/probe_tasks.txt", buf, StrLen(buf));
}
RunProbes;
