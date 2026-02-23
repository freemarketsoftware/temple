// TestQSort.HC — QSortI64 and QSort: integers, strings, edge cases
// Comparators defined at global scope (typed fn ptr locals crash OS).
// Called by TestRunner with shared output buffer.

I64 QSCmpAsc(I64 a, I64 b)   { return a - b; }
I64 QSCmpDesc(I64 a, I64 b)  { return b - a; }
I64 QSCmpStr(U8 **a, U8 **b) { return StrCmp(*a, *b); }

U0 TestQSort(U8 *out) {
  U8 line[256];
  U8 *s;
  I64 arr[8];
  U8 *strs[5];

  // --- QSortI64 ascending ---
  arr[0]=5; arr[1]=2; arr[2]=8; arr[3]=1; arr[4]=9; arr[5]=3;
  QSortI64(arr, 6, &QSCmpAsc);
  if (arr[0]==1 && arr[1]==2 && arr[2]==3 && arr[3]==5 && arr[4]==8 && arr[5]==9)
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "int_asc\t%s\t%d %d %d %d %d %d\n", s,
    arr[0], arr[1], arr[2], arr[3], arr[4], arr[5]);
  CatPrint(out, "%s", line);

  // --- QSortI64 descending ---
  arr[0]=5; arr[1]=2; arr[2]=8; arr[3]=1; arr[4]=9; arr[5]=3;
  QSortI64(arr, 6, &QSCmpDesc);
  if (arr[0]==9 && arr[1]==8 && arr[2]==5 && arr[3]==3 && arr[4]==2 && arr[5]==1)
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "int_desc\t%s\t%d %d %d %d %d %d\n", s,
    arr[0], arr[1], arr[2], arr[3], arr[4], arr[5]);
  CatPrint(out, "%s", line);

  // --- Already sorted ---
  arr[0]=1; arr[1]=2; arr[2]=3; arr[3]=4; arr[4]=5;
  QSortI64(arr, 5, &QSCmpAsc);
  if (arr[0]==1 && arr[1]==2 && arr[2]==3 && arr[3]==4 && arr[4]==5)
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "int_presorted\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Reverse sorted ---
  arr[0]=5; arr[1]=4; arr[2]=3; arr[3]=2; arr[4]=1;
  QSortI64(arr, 5, &QSCmpAsc);
  if (arr[0]==1 && arr[1]==2 && arr[2]==3 && arr[3]==4 && arr[4]==5)
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "int_reverse\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Single element ---
  arr[0] = 42;
  QSortI64(arr, 1, &QSCmpAsc);
  if (arr[0] == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "int_single\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- Duplicates ---
  arr[0]=3; arr[1]=1; arr[2]=2; arr[3]=1; arr[4]=3;
  QSortI64(arr, 5, &QSCmpAsc);
  if (arr[0]==1 && arr[1]==1 && arr[2]==2 && arr[3]==3 && arr[4]==3)
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "int_duplicates\t%s\t%d %d %d %d %d\n", s,
    arr[0], arr[1], arr[2], arr[3], arr[4]);
  CatPrint(out, "%s", line);

  // --- Negatives ---
  arr[0]=-3; arr[1]=5; arr[2]=-1; arr[3]=0; arr[4]=2;
  QSortI64(arr, 5, &QSCmpAsc);
  if (arr[0]==-3 && arr[1]==-1 && arr[2]==0 && arr[3]==2 && arr[4]==5)
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "int_negatives\t%s\t%d %d %d %d %d\n", s,
    arr[0], arr[1], arr[2], arr[3], arr[4]);
  CatPrint(out, "%s", line);

  // --- Two elements ---
  arr[0]=9; arr[1]=1;
  QSortI64(arr, 2, &QSCmpAsc);
  if (arr[0]==1 && arr[1]==9) s = "PASS"; else s = "FAIL";
  StrPrint(line, "int_two\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- QSort with string pointers ascending ---
  strs[0]="banana"; strs[1]="apple"; strs[2]="cherry"; strs[3]="avocado";
  QSort(strs, 4, 8, &QSCmpStr);
  if (!StrCmp(strs[0],"apple") && !StrCmp(strs[1],"avocado") &&
      !StrCmp(strs[2],"banana") && !StrCmp(strs[3],"cherry"))
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "str_asc\t%s\t%s %s %s %s\n", s,
    strs[0], strs[1], strs[2], strs[3]);
  CatPrint(out, "%s", line);

  // --- QSort strings already sorted ---
  strs[0]="alpha"; strs[1]="beta"; strs[2]="gamma";
  QSort(strs, 3, 8, &QSCmpStr);
  if (!StrCmp(strs[0],"alpha") && !StrCmp(strs[1],"beta") && !StrCmp(strs[2],"gamma"))
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "str_presorted\t%s\n", s);
  CatPrint(out, "%s", line);

  // --- QSort strings with duplicates ---
  strs[0]="b"; strs[1]="a"; strs[2]="b"; strs[3]="a";
  QSort(strs, 4, 8, &QSCmpStr);
  if (!StrCmp(strs[0],"a") && !StrCmp(strs[1],"a") &&
      !StrCmp(strs[2],"b") && !StrCmp(strs[3],"b"))
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "str_duplicates\t%s\n", s);
  CatPrint(out, "%s", line);
}
