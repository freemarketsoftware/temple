#include "C:/Home/UartConst.HC"
U0 UartInit(U16 div){
OutU8(UART_LCR,LCR_DLAB);
OutU8(UART_DATA,div&0xFF);
OutU8(UART_IER,(div>>8)&0xFF);
OutU8(UART_LCR,LCR_8N1);
OutU8(UART_FCR,FCR_ENABLE|FCR_CLR_RX|FCR_CLR_TX|FCR_TRIG14);
OutU8(UART_MCR,MCR_DTR|MCR_RTS|MCR_OUT2);
OutU8(UART_IER,0);
}
Bool UartTxReady(){
return (InU8(UART_LSR)&LSR_TX_EMPTY)\!=0;
}
U0 UartPutChar(U8 ch){
while(\!UartTxReady());
OutU8(UART_DATA,ch);
}
Bool UartRxReady(){
return (InU8(UART_LSR)&LSR_RX_READY)\!=0;
}
U8 UartGetChar(){
while(\!UartRxReady());
return InU8(UART_DATA);
}
I64 UartGetCharTimeout(I64 spins){
while(spins-->0)if(UartRxReady())return InU8(UART_DATA);
return -1;
}
U0 UartPrint(U8 *str){
while(*str)UartPutChar(*str++);
}
