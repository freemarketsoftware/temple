#include "C:/Home/SerProto.HC"
U0 SerReplExe(){U8 buf[256];UartPrint("REPL_READY\n");while(1){SerRecvLine(buf,256);if(\!StrCmp(buf,"EXIT"))break;FileWrite("C:/Home/_r.HC",buf,StrLen(buf));ExeFile("C:/Home/_r.HC");Del("C:/Home/_r.HC");SerSendOk();}}
SerReplExe;
