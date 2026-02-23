
U0 TestV3(){
  U8 out[256];
  StrCpy(out,"a");
  CatPrint(out,"b");
  FileWrite("C:/AI/results/tv3.txt",out,StrLen(out));
}
TestV3;
