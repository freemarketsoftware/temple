// TestRunner.HC — Runs all safe tests and writes results to a single file
// Output: C:/AI/results/TestResults.txt (TSV with section headers)
// Usage: #include "C:/AI/tests/TestRunner.HC";
//
// Skipped (would panic the OS):
//   TestIntDivZero  — unguarded div-by-zero kills runner
//   TestMallocEdge2/2b/2c/2d — OOM causes panic
//   TestMallocEdge3 — double-free causes panic

#include "C:/AI/tests/TestMalloc.HC"
#include "C:/AI/tests/TestIntMath.HC"
#include "C:/AI/tests/TestStrings.HC"
#include "C:/AI/tests/TestFileIO.HC"
#include "C:/AI/tests/TestIntDiv.HC"
#include "C:/AI/tests/TestMallocEdge1.HC"
#include "C:/AI/tests/TestMallocEdge4.HC"
#include "C:/AI/tests/TestMallocEdge5.HC"
#include "C:/AI/tests/TestMallocEdge6.HC"
#include "C:/AI/tests/TestStrUtil.HC"
#include "C:/AI/tests/TestMath2.HC"
#include "C:/AI/tests/TestMemUtil.HC"
#include "C:/AI/tests/TestTypeConv.HC"
#include "C:/AI/tests/TestMemSet2.HC"
#include "C:/AI/tests/TestBitOps.HC"
#include "C:/AI/tests/TestException.HC"
#include "C:/AI/tests/TestStruct.HC"
#include "C:/AI/tests/TestI64Edge.HC"
#include "C:/AI/tests/TestGlobals.HC"
#include "C:/AI/tests/TestFmtSpec.HC"
#include "C:/AI/tests/TestFnPtr.HC"
#include "C:/AI/tests/TestDateTime.HC"
#include "C:/AI/tests/TestDirOps.HC"
#include "C:/AI/tests/TestF64Edge.HC"
#include "C:/AI/tests/TestQSort.HC"
#include "C:/AI/tests/TestKernelUtils.HC"
#include "C:/AI/tests/TestPointers.HC"
#include "C:/AI/tests/TestStrConv.HC"
#include "C:/AI/tests/TestDolDoc.HC"
#include "C:/AI/tests/TestDolDoc2.HC"
#include "C:/AI/tests/TestMath3.HC"
#include "C:/AI/tests/TestRegistry.HC"
#include "C:/AI/tests/TestGrPalette.HC"
#include "C:/AI/tests/TestGrDraw.HC"
#include "C:/AI/tests/TestTextBase.HC"
#include "C:/AI/tests/TestShiftEdge.HC"
#include "C:/AI/tests/TestGrPrint.HC"
#include "C:/AI/tests/TestMemOverlap.HC"
#include "C:/AI/tests/TestSwitch.HC"
#include "C:/AI/tests/TestDefine.HC"
#include "C:/AI/tests/TestStrEdge.HC"
#include "C:/AI/tests/TestGrExtra.HC"
#include "C:/AI/tests/TestCompress.HC"
#include "C:/AI/tests/TestHashKernel.HC"

U0 TestRunner() {
  U8 *out = MAlloc(131072);
  StrCpy(out, "suite\tname\tstatus\tdetail\n");

  CatPrint(out, "# TestMalloc\n");      TestMalloc(out);
  CatPrint(out, "# TestIntMath\n");     TestIntMath(out);
  CatPrint(out, "# TestStrings\n");     TestStrings(out);
  CatPrint(out, "# TestFileIO\n");      TestFileIO(out);
  CatPrint(out, "# TestIntDiv\n");      TestIntDiv(out);
  CatPrint(out, "# TestMallocEdge1\n"); TestMallocEdge1(out);
  CatPrint(out, "# TestMallocEdge4\n"); TestMallocEdge4(out);
  CatPrint(out, "# TestMallocEdge5\n"); TestMallocEdge5(out);
  CatPrint(out, "# TestMallocEdge6\n"); TestMallocEdge6(out);
  CatPrint(out, "# TestStrUtil\n");     TestStrUtil(out);
  CatPrint(out, "# TestMath2\n");       TestMath2(out);
  CatPrint(out, "# TestMemUtil\n");     TestMemUtil(out);
  CatPrint(out, "# TestTypeConv\n");    TestTypeConv(out);
  CatPrint(out, "# TestMemSet2\n");     TestMemSet2(out);
  CatPrint(out, "# TestBitOps\n");      TestBitOps(out);
  CatPrint(out, "# TestException\n");   TestException(out);
  CatPrint(out, "# TestStruct\n");      TestStruct(out);
  CatPrint(out, "# TestI64Edge\n");     TestI64Edge(out);
  CatPrint(out, "# TestGlobals\n");     TestGlobals(out);
  CatPrint(out, "# TestFmtSpec\n");     TestFmtSpec(out);
  CatPrint(out, "# TestFnPtr\n");       TestFnPtr(out);
  CatPrint(out, "# TestDateTime\n");   TestDateTime(out);
  CatPrint(out, "# TestDirOps\n");    TestDirOps(out);
  CatPrint(out, "# TestF64Edge\n");   TestF64Edge(out);
  CatPrint(out, "# TestQSort\n");     TestQSort(out);
  CatPrint(out, "# TestKernelUtils\n"); TestKernelUtils(out);
  CatPrint(out, "# TestPointers\n");  TestPointers(out);
  CatPrint(out, "# TestStrConv\n");  TestStrConv(out);
  CatPrint(out, "# TestDolDoc\n");   TestDolDoc(out);
  CatPrint(out, "# TestDolDoc2\n");  TestDolDoc2(out);
  CatPrint(out, "# TestMath3\n");   TestMath3(out);
  CatPrint(out, "# TestRegistry\n"); TestRegistry(out);
  CatPrint(out, "# TestGrPalette\n"); TestGrPalette(out);
  CatPrint(out, "# TestGrDraw\n");   TestGrDraw(out);
  CatPrint(out, "# TestTextBase\n"); TestTextBase(out);
  CatPrint(out, "# TestShiftEdge\n"); TestShiftEdge(out);
  CatPrint(out, "# TestGrPrint\n");   TestGrPrint(out);
  CatPrint(out, "# TestMemOverlap\n"); TestMemOverlap(out);
  CatPrint(out, "# TestSwitch\n");    TestSwitch(out);
  CatPrint(out, "# TestDefine\n");    TestDefine(out);
  CatPrint(out, "# TestStrEdge\n");   TestStrEdge(out);
  CatPrint(out, "# TestGrExtra\n");   TestGrExtra(out);
  CatPrint(out, "# TestCompress\n");  TestCompress(out);
  CatPrint(out, "# TestHashKernel\n"); TestHashKernel(out);
  FileWrite("C:/AI/results/TestResults.txt", out, StrLen(out));
  Free(out);
}

TestRunner;
