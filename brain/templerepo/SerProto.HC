#include "C:/Home/Uart.HC"
U0 SerSend(U8 *s){UartPrint(s);UartPutChar(4);UartPutChar(202);UartPutChar(254);UartPutChar(186);UartPutChar(190);UartPutChar(4);UartPutChar(250);UartPutChar(206);}
U0 SerSendOk(){SerSend("OK");}
U0 SerSendErr(U8 *s){UartPrint("ERR:");SerSend(s);}
U0 SerRecvLine(U8 *buf,I64 max){I64 i=0;U8 ch;while(i<max-1){ch=UartGetChar();if(ch==10)break;buf[i]=ch;i++;}buf[i]=0;}
