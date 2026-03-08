// TestGrPrint.HC — GrPrint on offscreen DC: verify font rendering
// GrPrint(CDC *dc, I64 x, I64 y, U8 *fmt, ...) — uses dc->color (no attr param)
// FONT_WIDTH=8, FONT_HEIGHT=8 (8x8 pixel glyphs)

U0 TestGrPrint(U8 *out) {
  U8 line[128];
  U8 *s;
  CDC *dc;
  I64 ok;
  I64 i;
  I64 found;
  I64 rv;

  // dc_create: DCNew returns non-NULL
  dc = DCNew(64, 16);
  ok = (dc != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grprint_dc_create\t%s\tdc=%d\n", s, dc);
  CatPrint(out, line);

  if (!dc) {
    StrPrint(line, "grprint_pixels_set\tFAIL\tdc is NULL\n");
    CatPrint(out, line);
    StrPrint(line, "grprint_color_index\tFAIL\tdc is NULL\n");
    CatPrint(out, line);
    StrPrint(line, "grprint_retval\tFAIL\tdc is NULL\n");
    CatPrint(out, line);
    StrPrint(line, "grprint_fmt_int\tFAIL\tdc is NULL\n");
    CatPrint(out, line);
    StrPrint(line, "grprint_dc_del\tFAIL\tdc is NULL\n");
    CatPrint(out, line);
    return;
  }

  // Clear body to 0
  MemSet(dc->body, 0, dc->width_internal * dc->height);

  // Set color to 15 (WHITE) and print "A" at (0,0)
  dc->color = 15;
  rv = GrPrint(dc, 0, 0, "A");

  // grprint_pixels_set: at least one pixel in row 0 is non-zero
  found = 0;
  i = 0;
  while (i < 8) {
    if (dc->body[i] != 0) {
      found = 1;
    }
    i++;
  }
  if (found) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grprint_pixels_set\t%s\tfound=%d\n", s, found);
  CatPrint(out, line);

  // grprint_color_index: lit pixel has value 15
  found = 0;
  i = 0;
  while (i < dc->width_internal * dc->height) {
    if (dc->body[i] == 15) {
      found = 1;
    }
    i++;
  }
  if (found) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grprint_color_index\t%s\tpixel_val_15=%d\n", s, found);
  CatPrint(out, line);

  // grprint_retval: GrPrint returns >= 1 (chars rendered or pixels advanced)
  if (rv >= 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grprint_retval\t%s\trv=%d\n", s, rv);
  CatPrint(out, line);

  // grprint_fmt_int: print integer, check new pixels appear
  MemSet(dc->body, 0, dc->width_internal * dc->height);
  dc->color = 7;
  GrPrint(dc, 0, 0, "%d", 42);
  found = 0;
  i = 0;
  while (i < dc->width_internal * dc->height) {
    if (dc->body[i] == 7) {
      found = 1;
    }
    i++;
  }
  if (found) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grprint_fmt_int\t%s\tpixel_val_7=%d\n", s, found);
  CatPrint(out, line);

  // dc_del: no crash
  DCDel(dc);
  s = "PASS";
  StrPrint(line, "grprint_dc_del\t%s\t\n", s);
  CatPrint(out, line);
}
