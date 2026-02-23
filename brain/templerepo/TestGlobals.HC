// TestGlobals.HC — Global variable behavior
// Persistence across calls, default init, shared state between functions,
// global arrays, global structs, global pointers
// Results written to C:/AI/results/TestGlobals.txt as TSV

// --- Global declarations ---

I64 g_counter = 0;
I64 g_uninit;
U8  g_flag = 0;
I64 g_arr[4];
U8  g_str[32];

class TGPoint {
  I64 x;
  I64 y;
};
TGPoint g_point;

I64 *g_ptr = 0;

// --- Helper functions that use globals ---

U0 GlobIncrement() {
  g_counter++;
}

U0 GlobSetFlag() {
  g_flag = 1;
}

I64 GlobGetCounter() {
  return g_counter;
}

// --- Test function ---

U0 TestGlobals() {
  U8 out[4096];
  U8 line[128];
  U8 *s;
  I64 r, i;

  Del("C:/AI/results/TestGlobals.txt");
  StrCpy(out, "name\tstatus\tdetail\n");

  // --- 1. Initialized global has correct value at start ---
  if (g_counter == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_init_zero\t%s\t%d\n", s, g_counter);
  CatPrint(out, "%s", line);

  // --- 2. Global persists after function call increments it ---
  GlobIncrement();
  GlobIncrement();
  GlobIncrement();
  if (g_counter == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_persist\t%s\t%d\n", s, g_counter);
  CatPrint(out, "%s", line);

  // --- 3. Read global via helper function ---
  r = GlobGetCounter();
  if (r == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_read_via_fn\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 4. Global modified by one function visible to another ---
  GlobSetFlag();
  if (g_flag == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_shared_state\t%s\t%d\n", s, g_flag);
  CatPrint(out, "%s", line);

  // --- 5. Direct global write and read ---
  g_counter = 99;
  if (g_counter == 99) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_direct_write\t%s\t%d\n", s, g_counter);
  CatPrint(out, "%s", line);

  // --- 6. Uninitialised global — observe its value ---
  StrPrint(line, "global_uninit\tOBS\t%d\n", g_uninit);
  CatPrint(out, "%s", line);

  // --- 7. Global array write and read ---
  g_arr[0] = 10;
  g_arr[1] = 20;
  g_arr[2] = 30;
  g_arr[3] = 40;
  if (g_arr[0]==10 && g_arr[1]==20 && g_arr[2]==30 && g_arr[3]==40) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_array\t%s\t%d %d %d %d\n", s, g_arr[0], g_arr[1], g_arr[2], g_arr[3]);
  CatPrint(out, "%s", line);

  // --- 8. Global struct field access ---
  g_point.x = 77;
  g_point.y = 88;
  if (g_point.x == 77 && g_point.y == 88) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_struct\t%s\t%d %d\n", s, g_point.x, g_point.y);
  CatPrint(out, "%s", line);

  // --- 9. Global string ---
  StrCpy(g_str, "hello");
  if (!StrCmp(g_str, "hello")) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_string\t%s\t%s\n", s, g_str);
  CatPrint(out, "%s", line);

  // --- 10. Global pointer — point at a local, read back ---
  I64 local_val = 42;
  g_ptr = &local_val;
  if (*g_ptr == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_ptr\t%s\t%d\n", s, *g_ptr);
  CatPrint(out, "%s", line);

  // --- 11. Global persists across re-entry: call increment again ---
  g_counter = 0;
  GlobIncrement();
  GlobIncrement();
  r = GlobGetCounter();
  if (r == 2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_reuse\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 12. Global array default init — observe first element ---
  // g_arr was written above; verify it still holds the last written value
  if (g_arr[0] == 10) s = "PASS"; else s = "FAIL";
  StrPrint(line, "global_array_persist\t%s\t%d\n", s, g_arr[0]);
  CatPrint(out, "%s", line);

  FileWrite("C:/AI/results/TestGlobals.txt", out, StrLen(out));
}
TestGlobals;
