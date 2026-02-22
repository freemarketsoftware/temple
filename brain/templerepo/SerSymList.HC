U0 SerSymList(I64 mask){
  CHashTable *t=Fs->hash_table;
  CHash *h;I64 i;U8 k[8];
  while(t){
    for(i=0;i<=t->mask;i++){
      h=t->body[i];
      while(h){
        if(h->type&mask){
          if(h->type&64)StrCpy(k,"fun");
          else if(h->type&8)StrCpy(k,"glbl");
          else if(h->type&16)StrCpy(k,"class");
          else StrCpy(k,"oth");
          UartPrint(h->str);UartPutChar(9);
          UartPrint(k);UartPutChar(10);
        }
        h=h->next;
      }
    }
    t=t->next;
  }
  UartPutChar(4);UartPutChar(202);UartPutChar(254);
  UartPutChar(186);UartPutChar(190);UartPutChar(4);
  UartPutChar(250);UartPutChar(206);
}
