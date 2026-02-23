
#include "C:/AI/tests/TestStrConv.HC"
U8 *out = MAlloc(8192);
StrCpy(out, "suite	name	status	detail
");
CatPrint(out, "# TestStrConv
");
TestStrConv(out);
FileWrite("C:/AI/results/TestStrConv.txt", out, StrLen(out));
Free(out);
