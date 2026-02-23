
#include "C:/AI/tests/TestPointers.HC"
U8 *out = MAlloc(4096);
StrCpy(out, "suite	name	status	detail
");
CatPrint(out, "# TestPointers
");
TestPointers(out);
FileWrite("C:/AI/results/TestPointers.txt", out, StrLen(out));
Free(out);
