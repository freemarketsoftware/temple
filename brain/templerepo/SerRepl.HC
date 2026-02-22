U8 g_replied=0;
U0 SerSend(U8 *s){UartPrint(s);UartPutChar(4);g_replied=1;}
U0 SerSendOk(){SerSend("OK");}
U0 SerSendErr(U8 *s){UartPrint("ERR:");SerSend(s);}
U0 SerRecvLine(U8 *buf,I64 max){
I64 i=0;U8 ch;
while(i<max-1){
ch=UartGetChar();
if(ch==10)break;
buf[i]=ch;i++;
}
buf[i]=0;
}
U0 SerRepl(){
U8 buf[256];
UartPrint("REPL_READY\n");
while(1){
g_replied=0;
SerRecvLine(buf,256);
if(\!StrCmp(buf,"EXIT"))break;
ExeStr(buf);
if(\!g_replied)SerSendOk();
}
}
SerRepl;
