// TestE1000Init.HC — Tier 5: e1000 NIC full init verification (standalone)
// Verifies: PCI bus master enable, soft reset, TX ring register setup.
// CRITICAL: PCIWriteU16(0,3,0,0x04,0x0107) enables Bus Master (bit 2).
//   Without it, pci_dma_read returns zeros and TX silently fails.
// Results written to C:/AI/results/TestE1000Init.txt

I64 g_ei_bar0;
I64 g_ei_ring_base;
I64 g_ei_txring[34];

U0 TestE1000Init() {
  U8 buf[4096];
  U8 line[128];
  U8 *s;
  I64 pci_cmd, pci_bm;
  I64 ctrl, status, tctl;
  I64 tdbal, tdbah, tdlen, tdh, tdt;
  I64 raw, tda, i;

  buf[0] = 0;
  CatPrint(buf, "# TestE1000Init\n");

  // --- 1. Read BAR0 ---
  g_ei_bar0 = PCIReadU32(0, 3, 0, 0x10) & 0xFFFFFFF0;
  if (g_ei_bar0 == 0xFEB80000) s = "PASS"; else s = "FAIL";
  StrPrint(line, "bar0_addr\t%s\t%08X\n", s, g_ei_bar0);
  CatPrint(buf, "%s", line);

  // --- 2. Enable Bus Master (bit 2) in PCI Command register ---
  // Without this, QEMU's pci_dma_read returns zeros — TX silently fails.
  PCIWriteU16(0, 3, 0, 0x04, 0x0107);
  pci_cmd = PCIReadU32(0, 3, 0, 0x04) & 0xFFFF;
  pci_bm = (pci_cmd >> 2) & 1;
  if (pci_bm == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "pci_bus_master\t%s\tcmd=%04X bm=%d\n", s, pci_cmd, pci_bm);
  CatPrint(buf, "%s", line);

  // --- 3. Soft reset via CTRL (U32 write to avoid split-write side-effects) ---
  (g_ei_bar0 + 0x0000)(U32*)[0] = 1 << 26;
  i = 0; while(i < 500000) { i++; }
  (g_ei_bar0 + 0x0000)(U32*)[0] = 0x241;    // SLU | SPEED=01 | FD

  // CTRL: bit 26 (RST) must be cleared after reset (self-clearing)
  ctrl = (g_ei_bar0 + 0x0000)(U32*)[0];
  if (!((ctrl >> 26) & 1)) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ctrl_rst_cleared\t%s\tCTRL=%08X\n", s, ctrl);
  CatPrint(buf, "%s", line);

  // --- 4. STATUS: link up (bit 1) and full duplex (bit 0) ---
  status = (g_ei_bar0 + 0x0008)(U32*)[0];
  if ((status & 2) && (status & 1)) s = "PASS"; else s = "FAIL";
  StrPrint(line, "status_lu_fd\t%s\tSTATUS=%08X\n", s, status);
  CatPrint(buf, "%s", line);

  // --- 5. Set up TX descriptor ring ---
  raw = &g_ei_txring[0];
  tda = (raw + 15) & ~15;          // 16-byte align
  g_ei_ring_base = tda;
  (g_ei_bar0 + 0x3800)(U32*)[0] = tda & 0xFFFFFFFF;  // TDBAL
  (g_ei_bar0 + 0x3804)(U32*)[0] = 0;                  // TDBAH = 0
  (g_ei_bar0 + 0x3808)(U32*)[0] = 256;                // TDLEN = 256 (16 slots)
  (g_ei_bar0 + 0x3810)(U32*)[0] = 0;                  // TDH = 0
  (g_ei_bar0 + 0x3818)(U32*)[0] = 0;                  // TDT = 0
  (g_ei_bar0 + 0x0400)(U32*)[0] = 0x0A;               // TCTL: EN(1) | PSP(3)

  // --- 6. TDBAL readback matches ring base ---
  tdbal = (g_ei_bar0 + 0x3800)(U32*)[0];
  if (tdbal == (tda & 0xFFFFFFFF)) s = "PASS"; else s = "FAIL";
  StrPrint(line, "tdbal_match\t%s\tTDBAL=%08X ring=%08X\n", s, tdbal, tda);
  CatPrint(buf, "%s", line);

  // --- 7. TDBAH = 0 (ring is in low 4GB) ---
  tdbah = (g_ei_bar0 + 0x3804)(U32*)[0];
  if (tdbah == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "tdbah_zero\t%s\t%08X\n", s, tdbah);
  CatPrint(buf, "%s", line);

  // --- 8. TDLEN = 256 ---
  tdlen = (g_ei_bar0 + 0x3808)(U32*)[0];
  if (tdlen == 256) s = "PASS"; else s = "FAIL";
  StrPrint(line, "tdlen_256\t%s\t%d\n", s, tdlen);
  CatPrint(buf, "%s", line);

  // --- 9. TDH = 0 after init ---
  tdh = (g_ei_bar0 + 0x3810)(U32*)[0] & 0xFFFF;
  if (tdh == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "tdh_zero\t%s\t%d\n", s, tdh);
  CatPrint(buf, "%s", line);

  // --- 10. TDT = 0 after init ---
  tdt = (g_ei_bar0 + 0x3818)(U32*)[0] & 0xFFFF;
  if (tdt == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "tdt_zero\t%s\t%d\n", s, tdt);
  CatPrint(buf, "%s", line);

  // --- 11. TCTL: TX enabled (bit 1 = EN) and PSP (bit 3) set ---
  tctl = (g_ei_bar0 + 0x0400)(U32*)[0];
  if ((tctl & 0x0A) == 0x0A) s = "PASS"; else s = "FAIL";
  StrPrint(line, "tctl_en_psp\t%s\tTCTL=%08X\n", s, tctl);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestE1000Init.txt", buf, StrLen(buf));
  Print("TestE1000Init done — 10 tests\n");
}

TestE1000Init;
