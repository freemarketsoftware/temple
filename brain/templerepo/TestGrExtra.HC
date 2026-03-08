// TestGrExtra.HC — GrPlot, GrFloodFill, GrEllipse on offscreen DC
// All F64 params for GrEllipse declared global (F64 locals crash JIT)

F64 g_ge_rot   = 0.0;
F64 g_ge_start = 0.0;
F64 g_ge_len   = 6.283185307;  // 2*pi

U0 TestGrExtra(U8 *out) {
  U8 line[128];
  U8 *s;
  CDC *dc;
  I64 ok;
  I64 px;
  I64 rv;

  dc = DCNew(32, 32);

  // GrPlot: plot single pixel at (5,5), verify it
  MemSet(dc->body, 0, dc->width_internal * dc->height);
  dc->color = 7;
  GrPlot(dc, 5, 5);
  px = dc->body[5 * dc->width_internal + 5];
  ok = (px == 7);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grplot_pixel\t%s\tpx=%d\n", s, px);
  CatPrint(out, line);

  // GrPlot: adjacent pixel unchanged
  px = dc->body[5 * dc->width_internal + 6];
  ok = (px == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grplot_adjacent_zero\t%s\tpx=%d\n", s, px);
  CatPrint(out, line);

  // GrPlot returns Bool (nonzero)
  dc->color = 3;
  rv = GrPlot(dc, 10, 10);
  ok = (rv != 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grplot_retval\t%s\trv=%d\n", s, rv);
  CatPrint(out, line);

  // GrFloodFill: fill black DC from center -> whole DC becomes dc->color
  MemSet(dc->body, 0, dc->width_internal * dc->height);
  dc->color = 11;
  rv = GrFloodFill(dc, 16, 16, 0, 0, 0);
  px = dc->body[0];
  ok = (px == 11);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grfloodfill_corner\t%s\tpx=%d\n", s, px);
  CatPrint(out, line);

  // GrFloodFill returns pixel count > 0
  ok = (rv > 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grfloodfill_retval\t%s\trv=%d\n", s, rv);
  CatPrint(out, line);

  // GrEllipse: draw ellipse, check some pixel is set
  MemSet(dc->body, 0, dc->width_internal * dc->height);
  dc->color = 14;
  GrEllipse(dc, 16, 16, 8, 6, g_ge_rot, 1, g_ge_start, g_ge_len);
  // check pixel near top of ellipse (16, 16-6=10)
  px = dc->body[10 * dc->width_internal + 16];
  ok = (px == 14);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grellipse_top\t%s\tpx=%d\n", s, px);
  CatPrint(out, line);

  // GrEllipse: center pixel should NOT be set (outline only)
  px = dc->body[16 * dc->width_internal + 16];
  ok = (px == 0);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "grellipse_center_empty\t%s\tpx=%d\n", s, px);
  CatPrint(out, line);

  DCDel(dc);
  s = "PASS";
  StrPrint(line, "grextra_dcdel\t%s\t\n", s);
  CatPrint(out, line);
}
