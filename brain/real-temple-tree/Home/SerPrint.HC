/* SerPrint.HC — real-time serial debug output (no file roundtrip)
   SerPrint(s)         : send plain string
   SerFmt(fmt,a,b)     : StrPrint into g_sp then send; pass 0 for unused args
   Note: HolyC '...' forwarding throws UndefExt; fixed-arg wrappers used instead
*/
U8 g_sp[4096];
U0 SerPrint(U8 *s){SerSend(s);}
U0 SerFmt(U8 *fmt,I64 a,I64 b){StrPrint(g_sp,fmt,a,b);SerSend(g_sp);}
