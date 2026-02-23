
U0 ProbeEndByte() {
  I64 i;
  U8 *end = StrScan("99rest", "%d", &i);
  U8 buf[128];
  StrPrint(buf, "val=%d end_byte=%d
", i, *end);
  FileWrite("C:/AI/results/sc_probe.txt", buf, StrLen(buf));
}
ProbeEndByte;
