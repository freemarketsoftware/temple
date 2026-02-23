// TestDirOps.HC — Directory operations: DirMk, FilesFind, Del, nested dirs
// Uses C:/AI/_tdops as scratch space — cleaned up at end.
// Called by TestRunner with shared output buffer.

U0 TestDirOps(U8 *out) {
  U8 line[256];
  U8 *s;
  U8 *content;
  I64 sz;
  I64 *d;
  I64 count;

  // --- DirMk creates a directory ---
  DirMk("C:/AI/_tdops");
  d = FilesFind("C:/AI/_tdops/*");
  if (d) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mkdir_creates\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Write file into new dir ---
  FileWrite("C:/AI/_tdops/probe.txt", "hello", 5);
  content = FileRead("C:/AI/_tdops/probe.txt", &sz);
  if (content && sz == 5) s = "PASS"; else s = "FAIL";
  StrPrint(line, "write_in_dir\t%s\t%d\n", s, sz);
  CatPrint(out, "%s", line);
  if (content) Free(content);

  // --- Content correct ---
  content = FileRead("C:/AI/_tdops/probe.txt", &sz);
  if (content && !MemCmp(content, "hello", 5)) s = "PASS"; else s = "FAIL";
  StrPrint(line, "content_correct\t%s\n", s);
  CatPrint(out, "%s", line);
  if (content) Free(content);

  // --- FilesFind lists entries in dir ---
  count = 0;
  d = FilesFind("C:/AI/_tdops/*");
  while (d) {
    count++;
    d = d[0];
  }
  if (count >= 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "filesFind_lists\t%s\t%d\n", s, count);
  CatPrint(out, "%s", line);

  // --- Del file removes it ---
  Del("C:/AI/_tdops/probe.txt");
  content = FileRead("C:/AI/_tdops/probe.txt", &sz);
  if (!content) s = "PASS"; else s = "FAIL";
  StrPrint(line, "del_file\t%s\n", s);
  CatPrint(out, "%s", line);
  if (content) Free(content);

  // --- Nested DirMk ---
  DirMk("C:/AI/_tdops/sub");
  d = FilesFind("C:/AI/_tdops/sub/*");
  if (d) s = "PASS"; else s = "FAIL";
  StrPrint(line, "nested_mkdir\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Write into nested dir ---
  FileWrite("C:/AI/_tdops/sub/inner.txt", "x", 1);
  content = FileRead("C:/AI/_tdops/sub/inner.txt", &sz);
  if (content && sz == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "write_nested\t%s\n", s);
  CatPrint(out, "%s", line);
  if (content) Free(content);

  // --- Del on a file inside nested dir ---
  Del("C:/AI/_tdops/sub/inner.txt");
  content = FileRead("C:/AI/_tdops/sub/inner.txt", &sz);
  if (!content) s = "PASS"; else s = "FAIL";
  StrPrint(line, "del_nested_file\t%s\n", s);
  CatPrint(out, "%s", line);
  if (content) Free(content);

  // --- Del subdir with del_dir=TRUE ---
  Del("C:/AI/_tdops/sub", FALSE, TRUE);
  d = FilesFind("C:/AI/_tdops/sub/*");
  if (!d) s = "PASS"; else s = "FAIL";
  StrPrint(line, "del_subdir\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Del parent dir with del_dir=TRUE ---
  Del("C:/AI/_tdops", FALSE, TRUE);
  d = FilesFind("C:/AI/_tdops/*");
  if (!d) s = "PASS"; else s = "FAIL";
  StrPrint(line, "del_dir\t%s\n", s);
  CatPrint(out, "%s", line);
}
