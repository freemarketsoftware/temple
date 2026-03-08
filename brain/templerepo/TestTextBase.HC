// TestTextBase.HC — TextRect, direct gr.text_base read/write
// TextRect writes (attr<<8)|char as U32 directly to gr.text_base cells.
// TextLenStr (used by TextPrint) does: RAX=attr<<8, LODSB char→AL, STOSD per cell.
// Cell format: bits 0-7 = char ASCII, bits 8-15 = attr (color index).
//
// TEXT_COLS=80, TEXT_ROWS=30 (string #defines from GrGlbls.HC via DefinePrint).
// gr.text_base is U32*; cell at (x,y) = gr.text_base[y*TEXT_COLS + x].
//
// Uses row 0 cols 0-3 for test writes (restored to original after each test).
// Visible briefly on screen — non-destructive to OS state; reset on snap1 reload.
// Safe for TestRunner.

U0 TestTextBase(U8 *out) {
  U8 line[128];
  U8 *s;
  U32 orig0;
  U32 orig1;
  U32 orig2;
  U32 orig3;
  U32 cell;
  I64 ok;

  // Save original values at row 0, cols 0-3
  orig0 = gr.text_base[0 * TEXT_COLS + 0];
  orig1 = gr.text_base[0 * TEXT_COLS + 1];
  orig2 = gr.text_base[0 * TEXT_COLS + 2];
  orig3 = gr.text_base[0 * TEXT_COLS + 3];

  // 1. gr.text_base is non-NULL
  ok = (gr.text_base != NULL);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "textbase_nonnull\t%s\t%d\n", s, ok);
  CatPrint(out, "%s", line);

  // 2. TextRect writes the exact U32 value to the cell
  //    'A' (0x41) with attr 15 = d = 0x0F41
  TextRect(0, 0, 0, 0, 0x0F41);
  cell = gr.text_base[0 * TEXT_COLS + 0];
  ok = (cell == 0x0F41);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "textrect_writes\t%s\t%X\n", s, cell);
  CatPrint(out, "%s", line);

  // 3. char byte (bits 0-7) == 'A' == 0x41
  ok = ((cell & 0xFF) == 'A');
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "textrect_char\t%s\t%d\n", s, cell & 0xFF);
  CatPrint(out, "%s", line);

  // 4. attr byte (bits 8-15) == 15 == 0x0F
  ok = (((cell >> 8) & 0xFF) == 15);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "textrect_attr\t%s\t%d\n", s, (cell >> 8) & 0xFF);
  CatPrint(out, "%s", line);

  // 5. TextRect fills a range: 'X' (0x58) with attr 7 at cols 1..3, row 0
  TextRect(1, 3, 0, 0, 0x0758);
  cell = gr.text_base[0 * TEXT_COLS + 2];  // check middle cell (col 2)
  ok = (cell == 0x0758);
  if (ok) s = "PASS"; else s = "FAIL";
  StrPrint(line, "textrect_fill\t%s\t%X\n", s, cell);
  CatPrint(out, "%s", line);

  // Restore original values
  TextRect(0, 0, 0, 0, orig0);
  TextRect(1, 1, 0, 0, orig1);
  TextRect(2, 2, 0, 0, orig2);
  TextRect(3, 3, 0, 0, orig3);
}
