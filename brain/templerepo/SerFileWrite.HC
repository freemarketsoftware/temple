U0 SerFileWrite(U8 *path){U8 *b=MAlloc(65536);I64 n=0;U8 c;UartPutChar(4);while(1){c=UartGetChar();if(c==4)break;b[n++]=c;}FileWrite(path,b,n);Free(b);}
