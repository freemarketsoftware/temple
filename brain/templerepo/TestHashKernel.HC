// TestHashKernel.HC — HashFind on kernel symbol table
// HashFind(U8 *name, CHashTable *table, I64 type_mask) -> CHash*
// HTT_FUN = 0x40; CHash base: {next, type, str} at offsets 0/8/16

U0 TestHashKernel(U8 *out) {
  U8 line[128];
  U8 *s;
  CHash *sym;
  I64 ok;

  // find known kernel function MAlloc
  sym = HashFind("MAlloc", Fs->hash_table, 0x40);
  ok = (sym != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "hashfind_malloc\t%s\t\n", s);
  CatPrint(out, line);

  // verify found entry name matches
  if (sym) {
    ok = (StrCmp(sym->str, "MAlloc") == 0);
    if (ok) s = "PASS"; else s = "FAIL";
    StrPrint(line, "hashfind_malloc_name\t%s\tstr=%s\n", s, sym->str);
    CatPrint(out, line);
  }

  // find StrLen
  sym = HashFind("StrLen", Fs->hash_table, 0x40);
  ok = (sym != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "hashfind_strlen\t%s\t\n", s);
  CatPrint(out, line);

  // find StrPrint
  sym = HashFind("StrPrint", Fs->hash_table, 0x40);
  ok = (sym != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "hashfind_strprint\t%s\t\n", s);
  CatPrint(out, line);

  // find a function defined in our test suite (TestMalloc)
  sym = HashFind("TestMalloc", Fs->hash_table, 0x40);
  ok = (sym != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "hashfind_testfn\t%s\t\n", s);
  CatPrint(out, line);

  // miss: non-existent name returns NULL
  sym = HashFind("XxXNotARealFunctionXxX", Fs->hash_table, 0x40);
  ok = (sym == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "hashfind_miss\t%s\t\n", s);
  CatPrint(out, line);

  // find with mask -1 (match any type) — MAlloc still found
  sym = HashFind("MAlloc", Fs->hash_table, -1);
  ok = (sym != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "hashfind_anymask\t%s\t\n", s);
  CatPrint(out, line);
}
