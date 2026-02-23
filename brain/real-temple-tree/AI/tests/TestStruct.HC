// TestStruct.HC — HolyC class/struct syntax verification
// Basic class, field access, sizeof, offset, nested, array field,
// union, inheritance, U8 field truncation in struct context
// Called by TestRunner with shared output buffer

// --- Class definitions (file scope) ---

class TSSimple {
  I64 x;
  I64 y;
};

class TSMixed {
  U8  small;
  I64 big;
};

class TSNested {
  I64 a;
  TSSimple inner;
  I64 b;
};

class TSWithArray {
  U8  buf[8];
  I64 count;
};

class TSUnion {
  union {
    I64 as_i64;
    U8  as_bytes[8];
  };
};

class TSBase {
  I64 base_val;
};

class TSChild:TSBase {
  I64 child_val;
};

// --- Test function ---

U0 TestStruct(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 r;

  // --- 1. Basic field write and read via . ---
  TSSimple ts;
  ts.x = 42;
  ts.y = 99;
  if (ts.x == 42 && ts.y == 99) s = "PASS"; else s = "FAIL";
  StrPrint(line, "basic_field_dot\t%s\t%d %d\n", s, ts.x, ts.y);
  CatPrint(out, "%s", line);

  // --- 2. Field access via pointer -> ---
  TSSimple *tp = &ts;
  tp->x = 7;
  if (ts.x == 7) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ptr_field_arrow\t%s\t%d\n", s, ts.x);
  CatPrint(out, "%s", line);

  // --- 3. sizeof(TSSimple) == 16 (two I64s) ---
  r = sizeof(TSSimple);
  if (r == 16) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sizeof_simple\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 4. offset of first field == 0 ---
  r = offset(TSSimple.x);
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "offset_first\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 5. offset of second field == 8 ---
  r = offset(TSSimple.y);
  if (r == 8) s = "PASS"; else s = "FAIL";
  StrPrint(line, "offset_second\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 6. Nested class — access inner fields ---
  TSNested tn;
  tn.a = 1;
  tn.inner.x = 2;
  tn.inner.y = 3;
  tn.b = 4;
  if (tn.inner.x == 2 && tn.inner.y == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "nested_access\t%s\t%d %d\n", s, tn.inner.x, tn.inner.y);
  CatPrint(out, "%s", line);

  // --- 7. sizeof nested class: a(8) + inner(16) + b(8) = 32 ---
  r = sizeof(TSNested);
  if (r == 32) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sizeof_nested\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 8. Array field read/write ---
  TSWithArray ta;
  ta.buf[0] = 0xAB;
  ta.buf[7] = 0xCD;
  ta.count = 2;
  if (ta.buf[0] == 0xAB && ta.buf[7] == 0xCD && ta.count == 2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "array_field\t%s\t%X %X\n", s, ta.buf[0], ta.buf[7]);
  CatPrint(out, "%s", line);

  // --- 9. Union: write I64, read as bytes[0] ---
  TSUnion tu;
  tu.as_i64 = 0x0102030405060708;
  // little-endian: byte[0] = 0x08, byte[7] = 0x01
  if (tu.as_bytes[0] == 0x08 && tu.as_bytes[7] == 0x01) s = "PASS"; else s = "FAIL";
  StrPrint(line, "union_i64_bytes\t%s\t%X %X\n", s, tu.as_bytes[0], tu.as_bytes[7]);
  CatPrint(out, "%s", line);

  // --- 10. Inheritance: child has parent field ---
  TSChild tc;
  tc.base_val = 11;
  tc.child_val = 22;
  if (tc.base_val == 11 && tc.child_val == 22) s = "PASS"; else s = "FAIL";
  StrPrint(line, "inheritance_fields\t%s\t%d %d\n", s, tc.base_val, tc.child_val);
  CatPrint(out, "%s", line);

  // --- 11. sizeof(TSChild) == 16: base_val(8) + child_val(8) ---
  r = sizeof(TSChild);
  if (r == 16) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sizeof_child\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 12. base_val at offset 0 in child ---
  r = offset(TSChild.base_val);
  if (r == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "inherited_field_offset\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 13. child_val at offset 8 in child ---
  r = offset(TSChild.child_val);
  if (r == 8) s = "PASS"; else s = "FAIL";
  StrPrint(line, "child_field_offset\t%s\t%d\n", s, r);
  CatPrint(out, "%s", line);

  // --- 14. U8 struct field truncates on write (struct != local var) ---
  TSMixed tm;
  tm.small = 0x1FF;
  if (tm.small == 0xFF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "u8_field_truncates\t%s\t%d\n", s, tm.small);
  CatPrint(out, "%s", line);

  // --- 15. U8 field does not corrupt adjacent I64 field ---
  tm.big = 0x1234567890ABCDEF;
  tm.small = 0xAB;
  if (tm.big == 0x1234567890ABCDEF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "u8_no_spill\t%s\t%d\n", s, tm.big);
  CatPrint(out, "%s", line);
}
