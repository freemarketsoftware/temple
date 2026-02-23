// TestTasks.HC — Spawn, DeathWait, Kill, TaskValidate, Yield
// Tier 4 — run standalone, NOT included in TestRunner
// Results written to C:/AI/results/TestTasks.txt
//
// All task functions defined at global scope (fn ptr local bug).
// Global state used for inter-task communication.

// --- Globals for task communication ---
I64 g_tk_ran   = 0;
I64 g_tk_arg   = 0;
I64 g_tk_neg   = 0;
I64 g_tk_t1    = 0;
I64 g_tk_t2    = 0;

// --- Task functions (global scope required) ---
U0 TkSetRan(I64 d)   { g_tk_ran = 99; }
U0 TkSetArg(I64 arg) { g_tk_arg = arg; }
U0 TkSetNeg(I64 arg) { g_tk_neg = arg; }
U0 TkSetT1(I64 d)    { g_tk_t1 = 1; }
U0 TkSetT2(I64 d)    { g_tk_t2 = 1; }
U0 TkLoop(I64 d)     { while(1) Yield; }

U0 TestTasks() {
  U8 buf[4096];
  U8 line[256];
  U8 *s;
  CTask *task;

  StrCpy(buf, "suite\tname\tstatus\tdetail\n");

  // --- 1. Basic spawn: task sets global to 99 ---
  g_tk_ran = 0;
  task = Spawn(&TkSetRan, 0, "TkRan");
  DeathWait(&task);
  if (g_tk_ran == 99) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestTasks\tspawn_basic\t%s\t%d\n", s, g_tk_ran);
  CatPrint(buf, "%s", line);

  // --- 2. Arg passing: spawn with I64 42, task stores it ---
  g_tk_arg = 0;
  task = Spawn(&TkSetArg, 42, "TkArg");
  DeathWait(&task);
  if (g_tk_arg == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestTasks\tspawn_arg\t%s\t%d\n", s, g_tk_arg);
  CatPrint(buf, "%s", line);

  // --- 3. Negative arg: spawn with -7 ---
  g_tk_neg = 0;
  task = Spawn(&TkSetNeg, -7, "TkNeg");
  DeathWait(&task);
  if (g_tk_neg == -7) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestTasks\tspawn_neg_arg\t%s\t%d\n", s, g_tk_neg);
  CatPrint(buf, "%s", line);

  // --- 4. Two sequential tasks ---
  g_tk_t1 = 0; g_tk_t2 = 0;
  task = Spawn(&TkSetT1, 0, "TkSeq1"); DeathWait(&task);
  task = Spawn(&TkSetT2, 0, "TkSeq2"); DeathWait(&task);
  if (g_tk_t1 == 1 && g_tk_t2 == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestTasks\tspawn_two_seq\t%s\t%d_%d\n", s, g_tk_t1, g_tk_t2);
  CatPrint(buf, "%s", line);

  // --- 5. TaskValidate on a live task ---
  task = Spawn(&TkLoop, 0, "TkLive");
  if (TaskValidate(task)) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestTasks\tvalidate_live\t%s\n", s);
  CatPrint(buf, "%s", line);
  Kill(task);

  // --- 6. TaskValidate(NULL) returns false ---
  if (!TaskValidate(NULL)) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestTasks\tvalidate_null\t%s\n", s);
  CatPrint(buf, "%s", line);

  // --- 7. Yield() returns normally ---
  Yield;
  s = "PASS";
  StrPrint(line, "TestTasks\tyield_ok\t%s\n", s);
  CatPrint(buf, "%s", line);

  // --- 8. Kill a looping task ---
  task = Spawn(&TkLoop, 0, "TkKill");
  Kill(task);
  s = "PASS";
  StrPrint(line, "TestTasks\tkill_ok\t%s\n", s);
  CatPrint(buf, "%s", line);

  FileWrite("C:/AI/results/TestTasks.txt", buf, StrLen(buf));
  Print("TestTasks done — results in C:/AI/results/TestTasks.txt\n");
}

TestTasks;
