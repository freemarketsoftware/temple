// TestDolDoc2.HC — DolDoc entry ops, type verification, DocAnchorFind
// Tests: DocEntryDel, entry type_u8, DocAnchorFind.
// Safe for TestRunner — in-memory CDoc ops only, no disk I/O or screen ops.
//
// NOTE: DocWrite/DocRead and DocGoToLine are deferred to TestDolDoc2b
//       (standalone-only) because they involve DocRecalc(RECALCt_FIND_CURSOR)
//       which aliases gr.dc2 — risky from ExeFile/REPL context.

U0 TestDolDoc2(U8 *out) {
  U8 line[256];
  U8 *s;
  CDoc *doc;
  CDoc *doc2;
  CDocEntry *entry;
  CDocEntry *e;
  I64 ok;
  I64 sz0;
  I64 sz1;
  I64 cnt0;
  I64 cnt1;
  I64 find_ok;
  I64 type_val;

  // ---- Group 2: DocEntryDel ----

  // 1. DocEntryDel reduces entry count by 1
  doc = DocNew(NULL, Fs);
  DocPrint(doc, "keep\n");
  DocPrint(doc, "remove\n");
  cnt0 = 0;
  e = doc->head.next;
  while (e != doc) {
    cnt0++;
    e = e->next;
  }
  // Delete the first DOCT_TEXT entry
  e = doc->head.next;
  while (e != doc && e->type_u8 != DOCT_TEXT) {
    e = e->next;
  }
  if (e != doc) DocEntryDel(doc, e);
  cnt1 = 0;
  e = doc->head.next;
  while (e != doc) {
    cnt1++;
    e = e->next;
  }
  ok = (cnt1 == cnt0 - 1);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "entry_del_count\t%s\t%d==%d-1\n", s, cnt1, cnt0);
  CatPrint(out, "%s", line);

  // 2. DocSize decreases after DocEntryDel
  doc2 = DocNew(NULL, Fs);
  DocPrint(doc2, "deleteme\n");
  sz0 = DocSize(doc2);
  e = doc2->head.next;
  while (e != doc2 && e->type_u8 != DOCT_TEXT) {
    e = e->next;
  }
  if (e != doc2) DocEntryDel(doc2, e);
  sz1 = DocSize(doc2);
  ok = (sz1 < sz0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "entry_del_size\t%s\t%d<%d\n", s, sz1, sz0);
  CatPrint(out, "%s", line);
  DocDel(doc2);
  DocDel(doc);

  // ---- Group 3: Entry type_u8 verification ----

  doc = DocNew(NULL, Fs);

  // 3. First entry after plain DocPrint has type_u8 == DOCT_TEXT (0)
  DocPrint(doc, "typecheck\n");
  e = doc->head.next;
  ok = (e != doc && e->type_u8 == DOCT_TEXT);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "entry_type_text\t%s\t%d\n", s, e->type_u8);
  CatPrint(out, "%s", line);

  // 4. Second entry (newline) has type_u8 == DOCT_NEW_LINE (1)
  e = doc->head.next->next;
  ok = (e != doc && e->type_u8 == DOCT_NEW_LINE);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "entry_type_newline\t%s\t%d\n", s, e->type_u8);
  CatPrint(out, "%s", line);

  // 5. $$FG,4$$ creates entry with type_u8 == DOCT_FOREGROUND (15)
  DocRst(doc, TRUE);
  entry = DocPrint(doc, "$$FG,4$$");
  ok = (entry != NULL && entry->type_u8 == DOCT_FOREGROUND);
  if (ok) s = "PASS"; else s = "FAIL";
  if (entry) type_val = entry->type_u8; else type_val = -1;
  StrPrint(line, "entry_type_fg\t%s\t%d\n", s, type_val);
  CatPrint(out, "%s", line);

  // 6. $$BK,1$$ creates entry with type_u8 == DOCT_BLINK (21)
  DocRst(doc, TRUE);
  entry = DocPrint(doc, "$$BK,1$$");
  ok = (entry != NULL && entry->type_u8 == DOCT_BLINK);
  if (ok) s = "PASS"; else s = "FAIL";
  if (entry) type_val = entry->type_u8; else type_val = -1;
  StrPrint(line, "entry_type_blink\t%s\t%d\n", s, type_val);
  CatPrint(out, "%s", line);

  DocDel(doc);

  // ---- Group 4: DocAnchorFind ----

  doc = DocNew(NULL, Fs);
  DocPrint(doc, "before anchor\n");

  // 7. Inserting anchor via $$AN,"label",A="name"$$ returns non-NULL
  entry = DocPrint(doc, "$$AN,\"anchorlabel\",A=\"testanchor\"$$");
  ok = (entry != NULL);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "anchor_insert_ok\t%s\t%d\n", s, ok);
  CatPrint(out, "%s", line);

  // 8. DocAnchorFind locates the named anchor (OBS if FAIL)
  find_ok = DocAnchorFind(doc, "testanchor");
  if (find_ok) s = "PASS"; else s = "OBS";
  StrPrint(line, "anchor_find_hit\t%s\t%d\n", s, find_ok);
  CatPrint(out, "%s", line);

  // 9. DocAnchorFind returns FALSE for a missing anchor name
  find_ok = DocAnchorFind(doc, "notexist_zzz");
  ok = !find_ok;
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "anchor_find_miss\t%s\t%d\n", s, ok);
  CatPrint(out, "%s", line);

  DocDel(doc);
}
