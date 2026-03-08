// TestSwitch.HC — HolyC switch/case: basic, default, range (...), fall-through
// HolyC range case syntax: case LOW...HIGH: (three dots, inclusive)

U0 TestSwitch(U8 *out) {
  U8 line[128];
  U8 *s;
  I64 x;
  I64 result;

  // basic: case 3 out of 1,2,3,default
  x = 3;
  result = -1;
  switch (x) {
    case 1: result = 10; break;
    case 2: result = 20; break;
    case 3: result = 30; break;
    default: result = 99;
  }
  if (result == 30) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_basic\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // default: no case matches
  x = 77;
  result = -1;
  switch (x) {
    case 1: result = 10; break;
    case 2: result = 20; break;
    default: result = 55;
  }
  if (result == 55) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_default\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // range: case 1...5 matches midpoint (x=3)
  x = 3;
  result = -1;
  switch (x) {
    case 1...5: result = 100; break;
    default:    result = 0;
  }
  if (result == 100) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_range_mid\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // range: lower boundary (x=1)
  x = 1;
  result = -1;
  switch (x) {
    case 1...5: result = 200; break;
    default:    result = 0;
  }
  if (result == 200) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_range_lo\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // range: upper boundary (x=5)
  x = 5;
  result = -1;
  switch (x) {
    case 1...5: result = 300; break;
    default:    result = 0;
  }
  if (result == 300) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_range_hi\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // range: just outside upper bound -> default
  x = 6;
  result = -1;
  switch (x) {
    case 1...5: result = 100; break;
    default:    result = 0;
  }
  if (result == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_range_out\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // negative range: case -10...-1 matches -5
  x = -5;
  result = -1;
  switch (x) {
    case -10...-1: result = 44; break;
    case 0:        result = 0; break;
    default:       result = -99;
  }
  if (result == 44) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_neg_range\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // switch on zero
  x = 0;
  result = -1;
  switch (x) {
    case 0:  result = 42; break;
    default: result = -1;
  }
  if (result == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_zero\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // char range: 'A'...'Z' matches 'M'=77
  x = 'M';
  result = -1;
  switch (x) {
    case 'A'...'Z': result = 1; break;
    case 'a'...'z': result = 2; break;
    default:        result = 0;
  }
  if (result == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_char_upper\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // char range: lowercase
  x = 'm';
  result = -1;
  switch (x) {
    case 'A'...'Z': result = 1; break;
    case 'a'...'z': result = 2; break;
    default:        result = 0;
  }
  if (result == 2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_char_lower\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // mixed: single cases + ranges, pick correct branch
  x = 7;
  result = -1;
  switch (x) {
    case 1...3: result = 1; break;
    case 5:     result = 5; break;
    case 6...9: result = 6; break;
    default:    result = 0;
  }
  if (result == 6) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_mixed\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);

  // fall-through: case 1 has no break, falls into case 2
  // Expected (C-style): result = 1 + 2 = 3
  x = 1;
  result = 0;
  switch (x) {
    case 1: result = 1;        // fall through
    case 2: result = result + 2; break;
    case 3: result = 99;
  }
  if (result == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "switch_fallthrough\t%s\tgot=%d\n", s, result);
  CatPrint(out, line);
}
