// TestGrDraw.HC — DCNew/DCDel, GrRect, GrLine, GrFillCircle on offscreen DC
// All operations on offscreen DCs — no screen modification.
// Safe for TestRunner.
//
// CDC.body: U8 * pixel buffer, stride = dc->width_internal
// Pixel at (x,y): dc->body[y * dc->width_internal + x] = color_index (U8)
// dc->color = N sets drawing color index N (CColorROPU32 low byte)

U0 TestGrDraw(U8 *out) {
  U8 line[128];
  U8 *s;
  CDC *dc;
  I64 ok;
  I64 px;
  I64 rv;

  // 1. DCNew returns non-NULL
  dc = DCNew(32, 32);
  ok = (dc != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dc_new_nonnull\t%s\t%d\n", s, ok);
  CatPrint(out, "%s", line);
  DCDel(dc);

  // 2. width and height fields match requested size; width_internal >= width
  dc = DCNew(32, 32);
  ok = (dc->width == 32 && dc->height == 32 && dc->width_internal >= 32);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dc_dimensions\t%s\tw=%d h=%d wi=%d\n", s, dc->width, dc->height, dc->width_internal);
  CatPrint(out, "%s", line);
  DCDel(dc);

  // 3. GrRect fills pixels: clear body to 0, fill entire DC with color 15, read center
  dc = DCNew(32, 32);
  MemSet(dc->body, 0, dc->width_internal * dc->height);
  dc->color = 15;
  GrRect(dc, 0, 0, 32, 32);
  px = dc->body[16 * dc->width_internal + 16];
  ok = (px == 15);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dc_rect_draws\t%s\t%d\n", s, px);
  CatPrint(out, "%s", line);
  DCDel(dc);

  // 4. GrRect returns pixels_changed > 0 for a filled rectangle
  dc = DCNew(32, 32);
  MemSet(dc->body, 0, dc->width_internal * dc->height);
  dc->color = 15;
  rv = GrRect(dc, 0, 0, 32, 32);
  ok = (rv > 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dc_rect_retval\t%s\t%d\n", s, rv);
  CatPrint(out, "%s", line);
  DCDel(dc);

  // 5. GrLine draws pixels: diagonal line (0,0)-(31,31), check pixel at (0,0)
  dc = DCNew(32, 32);
  MemSet(dc->body, 0, dc->width_internal * dc->height);
  dc->color = 15;
  GrLine(dc, 0, 0, 31, 31);
  px = dc->body[0 * dc->width_internal + 0];
  ok = (px == 15);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dc_line_draws\t%s\t%d\n", s, px);
  CatPrint(out, "%s", line);
  DCDel(dc);

  // 6. GrFillCircle fills center: center=(16,16), z=0, diameter=16
  dc = DCNew(32, 32);
  MemSet(dc->body, 0, dc->width_internal * dc->height);
  dc->color = 15;
  GrFillCircle(dc, 16, 16, 0, 16);
  px = dc->body[16 * dc->width_internal + 16];
  ok = (px == 15);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dc_circle_draws\t%s\t%d\n", s, px);
  CatPrint(out, "%s", line);
  DCDel(dc);

  // 7. DCDel doesn't crash
  dc = DCNew(16, 16);
  DCDel(dc);
  StrPrint(line, "dc_del_no_crash\tPASS\t1\n");
  CatPrint(out, "%s", line);
}
