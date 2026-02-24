// TestE1000BAR.HC — Tier 5: e1000 MMIO BAR0 access (standalone)
// e1000 NIC: bus=0, dev=3, func=0 (8086:100E), BAR0 = 0xFEB80000
// Identity-mapped: phys == virt, direct pointer deref works.
// Results written to C:/AI/results/TestE1000BAR.txt

U0 TestE1000BAR() {
  U8 buf[8192];
  U8 line[128];
  U8 *s;
  I64 bar0, ctrl, status, rctl, tctl, ral0, rah0;
  I64 mac01, mac23, mac45;

  buf[0] = 0;
  CatPrint(buf, "# TestE1000BAR\n");

  // --- 1. bar0_nonzero: BAR0 must be assigned (non-zero) ---
  bar0 = PCIReadU32(0, 3, 0, 0x10);
  if (bar0 != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bar0_nonzero\t%s\tBAR0=%08X\n", s, bar0);
  CatPrint(buf, "%s", line);

  // --- 2. bar0_aligned: bottom 12 bits must be 0 (page-aligned MMIO) ---
  if ((bar0 & 0xFFF) == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bar0_aligned\t%s\tbottom12=%X\n", s, bar0 & 0xFFF);
  CatPrint(buf, "%s", line);

  // --- MMIO register reads (I64* pointer deref, mask to 32-bit) ---
  ctrl   = bar0(I64*)[0] & 0xFFFFFFFF;          // offset 0x000 CTRL
  status = (bar0 + 0x08)(I64*)[0] & 0xFFFFFFFF; // offset 0x008 STATUS
  rctl   = (bar0 + 0x100)(I64*)[0] & 0xFFFFFFFF;// offset 0x100 RCTL
  tctl   = (bar0 + 0x400)(I64*)[0] & 0xFFFFFFFF;// offset 0x400 TCTL
  ral0   = (bar0 + 0x5400)(I64*)[0] & 0xFFFFFFFF;// offset 0x5400 RAL0
  rah0   = (bar0 + 0x5404)(I64*)[0] & 0xFFFFFFFF;// offset 0x5404 RAH0

  // --- 3. ctrl_readable: CTRL must not be all-Fs (bus error = unassigned) ---
  if (ctrl != 0xFFFFFFFF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ctrl_readable\t%s\tCTRL=%08X\n", s, ctrl);
  CatPrint(buf, "%s", line);

  // --- 4. status_link_up: bit 0 = LU (Link Up) ---
  if (status & 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "status_link_up\t%s\tSTATUS=%08X\n", s, status);
  CatPrint(buf, "%s", line);

  // --- 5. status_full_duplex: bit 1 = FD ---
  if (status & 2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "status_full_duplex\t%s\tFD=%d\n", s, (status>>1)&1);
  CatPrint(buf, "%s", line);

  // --- 6. rctl_disabled: RCTL=0 before driver init ---
  if (rctl == 0) s = "PASS"; else s = "OBS";
  StrPrint(line, "rctl_disabled\t%s\tRCTL=%08X\n", s, rctl);
  CatPrint(buf, "%s", line);

  // --- 7. tctl_disabled: TCTL=0 before driver init ---
  if (tctl == 0) s = "PASS"; else s = "OBS";
  StrPrint(line, "tctl_disabled\t%s\tTCTL=%08X\n", s, tctl);
  CatPrint(buf, "%s", line);

  // --- 8. mac_rah0_valid: bit 31 of RAH0 = AV (Address Valid) ---
  if ((rah0 >> 31) & 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mac_rah0_valid\t%s\tAV=%d\n", s, (rah0>>31)&1);
  CatPrint(buf, "%s", line);

  // --- 9. mac_bytes_01: MAC[0:1] = 52:54 (QEMU OUI), LE in RAL0 ---
  mac01 = ral0 & 0xFFFF;
  if (mac01 == 0x5452) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mac_bytes_01\t%s\tgot=%04X exp=5452\n", s, mac01);
  CatPrint(buf, "%s", line);

  // --- 10. mac_bytes_23: MAC[2:3] = 00:12 ---
  mac23 = (ral0 >> 16) & 0xFFFF;
  if (mac23 == 0x1200) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mac_bytes_23\t%s\tgot=%04X exp=1200\n", s, mac23);
  CatPrint(buf, "%s", line);

  // --- 11. mac_bytes_45: MAC[4:5] = 34:56, LE in RAH0 ---
  mac45 = rah0 & 0xFFFF;
  if (mac45 == 0x5634) s = "PASS"; else s = "FAIL";
  StrPrint(line, "mac_bytes_45\t%s\tgot=%04X exp=5634\n", s, mac45);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestE1000BAR.txt", buf, StrLen(buf));
  Print("TestE1000BAR done — 11 tests, results in C:/AI/results/TestE1000BAR.txt\n");
}

TestE1000BAR;
