#include "C:/Home/SerProto.HC"
U0 SerReplPrint(){U8 buf[256];UartPrint("REPL_READY\n");while(1){SerRecvLine(buf,256);if(\!StrCmp(buf,"EXIT"))break;"CMD: %s\n",buf;SerSendOk();}}
SerReplPrint;
