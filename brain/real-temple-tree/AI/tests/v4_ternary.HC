
U0 TestV4(){
  U8 *p=MAlloc(1);
  U8 line[64];
  StrPrint(line,"%s",p!=0?"PASS":"FAIL");
  FileWrite("C:/AI/results/tv4.txt",line,StrLen(line));
  Free(p);
}
TestV4;
