// TestPointers.HC — Pointer arithmetic, casting, struct ptr, double ptr, raw buffer
// Safe — no NULL deref, no UAF. Can run via TestRunner.
// Called by TestRunner with shared output buffer.

class PtrVec2 { I64 x; I64 y; };

U0 TestPointers(U8 *out) {
  U8 line[256];
  U8 *s;

  // --- 1. Address-of and dereference ---
  I64 x1 = 42;
  I64 *p1 = &x1;
  if (*p1 == 42 && p1 == &x1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "addr_deref\t%s\t*p=%d same=%d\n", s, *p1, p1 == &x1);
  CatPrint(out, "%s", line);

  // --- 2. Write through pointer ---
  I64 x2 = 10;
  I64 *p2 = &x2;
  *p2 = 99;
  if (x2 == 99 && *p2 == 99) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ptr_write\t%s\tx=%d\n", s, x2);
  CatPrint(out, "%s", line);

  // --- 3. Pointer arithmetic on array ---
  I64 arr3[4];
  arr3[0]=10; arr3[1]=20; arr3[2]=30; arr3[3]=40;
  I64 *p3 = arr3;
  I64 *q3 = &arr3[3];
  if (*(p3+1)==20 && *(p3+2)==30 && (q3-p3)==3) s = "PASS"; else s = "FAIL";
  p3++;
  if (s[0]=='P' && *p3 != 20) s = "FAIL";
  StrPrint(line, "ptr_arith\t%s\tp1=%d diff=%d pp=%d\n", s, *(arr3+1), q3-arr3, *p3);
  CatPrint(out, "%s", line);

  // --- 4. Pointer casting: I64* <-> U8* ---
  I64 x4 = 0x0102030405060708;
  U8 *b4 = &x4;
  // little-endian: byte 0 = 0x08, byte 7 = 0x01
  if (b4[0]==0x08 && b4[7]==0x01) s = "PASS"; else s = "FAIL";
  I64 *back4 = b4(I64 *);
  if (s[0]=='P' && *back4 != x4) s = "FAIL";
  StrPrint(line, "ptr_cast\t%s\tb0=%X b7=%X\n", s, b4[0], b4[7]);
  CatPrint(out, "%s", line);

  // --- 5. Struct pointer access with -> ---
  PtrVec2 v5;
  v5.x = 3; v5.y = 7;
  PtrVec2 *p5 = &v5;
  if (p5->x==3 && p5->y==7) s = "PASS"; else s = "FAIL";
  p5->x = 100;
  if (s[0]=='P' && v5.x != 100) s = "FAIL";
  StrPrint(line, "struct_ptr\t%s\tx=%d y=%d sz=%d\n", s, v5.x, p5->y, sizeof(PtrVec2));
  CatPrint(out, "%s", line);

  // --- 6. Pointer comparison and NULL ---
  I64 arr6[3];
  arr6[0]=1; arr6[1]=2; arr6[2]=3;
  I64 *p6 = arr6;
  I64 *q6 = &arr6[2];
  I64 *n6 = NULL;
  if (p6 < q6 && q6 > p6 && p6==arr6 && n6==NULL && !n6 && p6!=NULL)
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "ptr_cmp\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- 7. Heap pointer: MAlloc, index, Free ---
  I64 *h7 = MAlloc(3 * sizeof(I64));
  h7[0]=100; h7[1]=200; h7[2]=300;
  I64 *hq7 = h7 + 1;
  if (h7[0]==100 && *hq7==200 && h7[2]==300) s = "PASS"; else s = "FAIL";
  Free(h7);
  StrPrint(line, "heap_ptr\t%s\t%d %d %d\n", s, 100, 200, 300);
  CatPrint(out, "%s", line);

  // --- 8. Pointer-to-pointer (**) ---
  I64 x8 = 42;
  I64 *p8 = &x8;
  I64 **pp8 = &p8;
  if (**pp8 == 42) s = "PASS"; else s = "FAIL";
  **pp8 = 99;
  if (s[0]=='P' && x8 != 99) s = "FAIL";
  I64 y8 = 77;
  *pp8 = &y8;
  if (s[0]=='P' && *p8 != 77) s = "FAIL";
  StrPrint(line, "double_ptr\t%s\tx=%d swapped=%d\n", s, x8, *p8);
  CatPrint(out, "%s", line);

  // --- 9. Raw buffer cast at offset (packet parsing pattern) ---
  U8 *buf9 = MAlloc(32);
  I64 i9;
  for (i9 = 0; i9 < 32; i9++) buf9[i9] = i9;
  U16 *u16p9 = buf9 + 4;   // bytes 4,5 -> 0x0504 LE
  U32 *u32p9 = buf9 + 8;   // bytes 8..11 -> 0x0B0A0908 LE
  if (*u16p9 == 0x0504 && *u32p9 == 0x0B0A0908) s = "PASS"; else s = "FAIL";
  Free(buf9);
  StrPrint(line, "buf_cast\t%s\tu16=%X u32=%X\n", s, *u16p9, *u32p9);
  CatPrint(out, "%s", line);
}
