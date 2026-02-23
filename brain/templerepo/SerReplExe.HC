#include "C:/Home/SerProto.HC"
U0 SerReplExe(){
U8 buf[4096];U8 ex[32];U8 ecode[9];I64 g_ex;I64 ec;
UartPrint("REPL_READY\n");
while(1){
SerRecvLine(buf,256);
if(!StrCmp(buf,"EXIT"))break;
g_ex=0;
FileWrite("C:/Home/_r.HC",buf,StrLen(buf));
try{ExeFile("C:/Home/_r.HC");}catch{g_ex=1;Fs->catch_except=TRUE;ec=Fs->except_ch;MemCpy(ecode,&ec,8);ecode[8]=0;StrPrint(ex,"EXCEPT:%s",ecode);}
Del("C:/Home/_r.HC");
if(g_ex)SerSend(ex);
SerSendOk();
}
}
SerReplExe;
