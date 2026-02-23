
U0 TestV2(){
  U8 line[64];
  StrPrint(line,"hello");
  FileWrite("C:/AI/results/tv2.txt",line,StrLen(line));
}
TestV2;
