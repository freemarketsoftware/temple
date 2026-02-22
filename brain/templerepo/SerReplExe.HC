#include "C:/Home/SerProto.HC"
U0 SerReplExe(){
U8 buf[4096];U8 ex[32];I64 g_ex;
UartPrint("REPL_READY\n");
while(1){
SerRecvLine(buf,256);
if(!StrCmp(buf,"EXIT"))break;
g_ex=0;
FileWrite("C:/Home/_r.HC",buf,StrLen(buf));
try{ExeFile("C:/Home/_r.HC");}catch{g_ex=1;Fs->catch_except=TRUE;StrPrint(ex,"EXCEPT:%c",Fs->except_ch);}
Del("C:/Home/_r.HC");
if(g_ex)SerSend(ex);
SerSendOk();
}
}
SerReplExe;
