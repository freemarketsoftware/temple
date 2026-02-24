U0 SerSymExists(U8 *name){
  CHash *h=HashFind(name,Fs->hash_table,HTT_FUN|HTT_GLBL_VAR|HTT_CLASS);
  if(h)GStrAdd("1");else GStrAdd("0");
}
