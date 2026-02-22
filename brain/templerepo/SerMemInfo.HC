U0 SerMemInfo(){
  U8 tmp[64];
  StrPrint(tmp,"code_used\t%d\n",sys_code_bp->used_u8s);
  GStrAdd(tmp);
  StrPrint(tmp,"code_total\t%d\n",sys_code_bp->alloced_u8s);
  GStrAdd(tmp);
  if(sys_data_bp){
    StrPrint(tmp,"data_used\t%d\n",sys_data_bp->used_u8s);
    GStrAdd(tmp);
    StrPrint(tmp,"data_total\t%d\n",sys_data_bp->alloced_u8s);
    GStrAdd(tmp);
  }
  StrPrint(tmp,"heap_limit\t%d\n",mem_heap_limit);
  GStrAdd(tmp);
}
