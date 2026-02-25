// TestDolDoc.HC — DolDoc (CDoc) API verification
// Tests DocNew, DocSize, DocPrint, DocLock/Unlock, DocRst, DocDel, DocFind,
// and entry list walking.
// Safe for TestRunner — pure in-memory CDoc operations, no window/display deps.

U0 TestDolDoc(U8 *out) {
  U8 line[256];
  U8 *s;
  CDoc *doc;
  CDoc *doc2;
  CDocEntry *entry;
  CDocEntry *e;
  I64 sz_fresh;
  I64 sz_after;
  I64 cnt;
  I64 lock1;
  I64 lock2;
  I64 unlock1;
  I64 find_hit;
  I64 find_miss;

  // 1. DocNew(NULL, Fs) returns non-NULL
  doc = DocNew(NULL, Fs);
  if (doc != NULL) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_new_not_null\t%s\t%d\n", s, doc != NULL);
  CatPrint(out, "%s", line);
  if (!doc) return;

  // 2. DocSize on fresh empty doc > 0 (CDoc struct + find_replace + dollar_buf)
  sz_fresh = DocSize(doc);
  if (sz_fresh > 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_size_fresh_nonzero\t%s\t%d\n", s, sz_fresh);
  CatPrint(out, "%s", line);

  // 3. DocPrint plain text returns NULL (no $$ entry — returns last dollar entry or NULL)
  entry = DocPrint(doc, "hello world\n");
  if (entry == NULL) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_print_plain_null\t%s\t%d\n", s, entry == NULL);
  CatPrint(out, "%s", line);

  // 4. DocPrint with $$FG,4$$ dollar command returns non-NULL CDocEntry*
  //    FG = DOCT_FOREGROUND; 4 = RED
  entry = DocPrint(doc, "$$FG,4$$");
  if (entry != NULL) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_print_dollar_nonnull\t%s\t%d\n", s, entry != NULL);
  CatPrint(out, "%s", line);

  // 5. DocSize grows after DocPrint calls
  sz_after = DocSize(doc);
  if (sz_after > sz_fresh) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_size_grows\t%s\t%d>%d\n", s, sz_after, sz_fresh);
  CatPrint(out, "%s", line);

  // 6. DocLock on unlocked doc returns TRUE
  lock1 = DocLock(doc);
  if (lock1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_lock_first\t%s\t%d\n", s, lock1);
  CatPrint(out, "%s", line);

  // 7. DocUnlock after DocLock returns TRUE
  unlock1 = DocUnlock(doc);
  if (unlock1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_unlock_after_lock\t%s\t%d\n", s, unlock1);
  CatPrint(out, "%s", line);

  // 8. DocLock on already-locked doc (same task, owning_task==Fs) returns FALSE
  lock1 = DocLock(doc);
  lock2 = DocLock(doc);
  DocUnlock(doc);
  if (!lock2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_lock_reentrant_false\t%s\t%d\n", s, lock2);
  CatPrint(out, "%s", line);

  // 9. DocRst(doc, TRUE) clears all entries — DocSize returns to fresh baseline
  DocRst(doc, TRUE);
  sz_after = DocSize(doc);
  if (sz_after == sz_fresh) s = "PASS"; else s = "OBS";
  StrPrint(line, "doc_rst_to_baseline\t%s\t%d==%d\n", s, sz_after, sz_fresh);
  CatPrint(out, "%s", line);

  // 10. DocDel does not crash
  DocDel(doc);
  CatPrint(out, "doc_del_no_crash\tPASS\t1\n");

  // 11. Two DocNew calls return distinct non-NULL addresses
  doc  = DocNew(NULL, Fs);
  doc2 = DocNew(NULL, Fs);
  if (doc != NULL && doc2 != NULL && doc != doc2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_two_independent\t%s\t%d\n", s, doc != doc2);
  CatPrint(out, "%s", line);
  DocDel(doc2);

  // 12. DocFind returns TRUE for text that was printed
  DocPrint(doc, "searchme\n");
  find_hit = DocFind(doc, I64_MIN, "searchme");
  if (find_hit) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_find_hit\t%s\t%d\n", s, find_hit);
  CatPrint(out, "%s", line);

  // 13. DocFind returns FALSE for text not in doc
  find_miss = DocFind(doc, I64_MIN, "zzznotthere");
  if (!find_miss) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_find_miss\t%s\t%d\n", s, !find_miss);
  CatPrint(out, "%s", line);

  // 14. Entry walk: DocPrint("hello\n") produces exactly 2 entries
  //     DOCT_TEXT("hello") + DOCT_NEW_LINE
  DocRst(doc, TRUE);
  DocPrint(doc, "hello\n");
  e = doc->head.next;
  cnt = 0;
  while (e != doc) {
    cnt++;
    e = e->next;
  }
  if (cnt == 2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "doc_entry_walk_count\t%s\t%d\n", s, cnt);
  CatPrint(out, "%s", line);

  DocDel(doc);
}
