// TestE1000Tx.HC — Tier 5: e1000 transmit one ARP packet (standalone)
// Sends a 42-byte ARP request and verifies DD=1 in the TX descriptor.
// Requires: PCIWriteU16(0,3,0,0x04,0x0107) to enable PCI Bus Master.
// Results written to C:/AI/results/TestE1000Tx.txt

I64 g_etx_bar0;
I64 g_etx_ring_base;
I64 g_etx_txring[34];
U8  g_etx_pkt[64];

U0 TestE1000Tx() {
  U8 buf[4096];
  U8 line[128];
  U8 *s;
  I64 raw, tda, i;
  I64 pci_bm, pci_cmd;
  I64 pkt_addr;
  I64 db2, db3;              // CMD byte of descriptor (byte 10, 11)
  I64 tdh_before, tdh_after;
  I64 icr_before, icr_after;
  I64 tpt_after;
  I64 sta, dd, txdw, txqe;

  buf[0] = 0;
  CatPrint(buf, "# TestE1000Tx\n");

  // ---- Init ----
  g_etx_bar0 = PCIReadU32(0, 3, 0, 0x10) & 0xFFFFFFF0;
  PCIWriteU16(0, 3, 0, 0x04, 0x0107);         // Bus Master enable
  (g_etx_bar0 + 0x0000)(U32*)[0] = 1 << 26;  // CTRL soft reset
  i = 0; while(i < 500000) { i++; }
  (g_etx_bar0 + 0x0000)(U32*)[0] = 0x241;    // CTRL: SLU|SPEED=01|FD
  raw = &g_etx_txring[0];
  tda = (raw + 15) & ~15;
  g_etx_ring_base = tda;
  (g_etx_bar0 + 0x3800)(U32*)[0] = tda & 0xFFFFFFFF;
  (g_etx_bar0 + 0x3804)(U32*)[0] = 0;
  (g_etx_bar0 + 0x3808)(U32*)[0] = 256;
  (g_etx_bar0 + 0x3810)(U32*)[0] = 0;
  (g_etx_bar0 + 0x3818)(U32*)[0] = 0;
  (g_etx_bar0 + 0x0400)(U32*)[0] = 0x0A;     // TCTL: EN | PSP

  // --- 1. pci_bus_master: confirm bit 2 is now set ---
  pci_cmd = PCIReadU32(0, 3, 0, 0x04) & 0xFFFF;
  pci_bm  = (pci_cmd >> 2) & 1;
  if (pci_bm == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "pci_bus_master\t%s\tcmd=%04X\n", s, pci_cmd);
  CatPrint(buf, "%s", line);

  // ---- Build ARP request packet (42 bytes) ----
  // Ethernet header (14 bytes)
  g_etx_pkt[0]=0xFF; g_etx_pkt[1]=0xFF; g_etx_pkt[2]=0xFF;   // dst: broadcast
  g_etx_pkt[3]=0xFF; g_etx_pkt[4]=0xFF; g_etx_pkt[5]=0xFF;
  g_etx_pkt[6]=0x52; g_etx_pkt[7]=0x54; g_etx_pkt[8]=0x00;   // src: 52:54:00:12:34:56
  g_etx_pkt[9]=0x12; g_etx_pkt[10]=0x34; g_etx_pkt[11]=0x56;
  g_etx_pkt[12]=0x08; g_etx_pkt[13]=0x06;                      // EtherType: ARP
  // ARP payload (28 bytes)
  g_etx_pkt[14]=0x00; g_etx_pkt[15]=0x01;  // HTYPE: Ethernet
  g_etx_pkt[16]=0x08; g_etx_pkt[17]=0x00;  // PTYPE: IPv4
  g_etx_pkt[18]=0x06;                        // HLEN: 6
  g_etx_pkt[19]=0x04;                        // PLEN: 4
  g_etx_pkt[20]=0x00; g_etx_pkt[21]=0x01;  // OPER: request
  g_etx_pkt[22]=0x52; g_etx_pkt[23]=0x54; g_etx_pkt[24]=0x00;  // sender MAC
  g_etx_pkt[25]=0x12; g_etx_pkt[26]=0x34; g_etx_pkt[27]=0x56;
  g_etx_pkt[28]=0x0A; g_etx_pkt[29]=0x00; g_etx_pkt[30]=0x02; g_etx_pkt[31]=0x0F; // sender IP 10.0.2.15
  g_etx_pkt[32]=0x00; g_etx_pkt[33]=0x00; g_etx_pkt[34]=0x00;  // target MAC (unknown)
  g_etx_pkt[35]=0x00; g_etx_pkt[36]=0x00; g_etx_pkt[37]=0x00;
  g_etx_pkt[38]=0x0A; g_etx_pkt[39]=0x00; g_etx_pkt[40]=0x02; g_etx_pkt[41]=0x02; // target IP 10.0.2.2

  // ---- Write legacy TX descriptor ----
  // lower.data = len(16b) | CSO(8b) | CMD(8b)
  // CMD = 0x0B: EOP(0) | IFCS(1) | RS(3) — EOP, insert FCS, report status
  pkt_addr = &g_etx_pkt[0];
  g_etx_ring_base(I64*)[0]           = pkt_addr;
  (g_etx_ring_base + 8)(I64*)[0]     = 42 | (0x0B << 24);

  // --- 2. desc_cmd_byte: CMD byte (byte 11) must be 0x0B ---
  db3 = (g_etx_ring_base + 11)(U8*)[0];
  if (db3 == 0x0B) s = "PASS"; else s = "FAIL";
  StrPrint(line, "desc_cmd_byte\t%s\tCMD=%02X\n", s, db3);
  CatPrint(buf, "%s", line);

  // --- 3. desc_len: length field (bytes 8-9) must be 42 ---
  db2 = (g_etx_ring_base + 8)(U8*)[0];
  if (db2 == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "desc_len\t%s\tlen=%d\n", s, db2);
  CatPrint(buf, "%s", line);

  // ---- Pre-kick: clear ICR, snapshot TPT and TDH ----
  icr_before  = (g_etx_bar0 + 0x00C0)(U32*)[0];   // read+clear ICR
  (g_etx_bar0 + 0x40D4)(U32*)[0];                   // read+clear TPT (discard pre-kick value)
  tdh_before  = (g_etx_bar0 + 0x3810)(U32*)[0] & 0xFFFF;

  // ---- Kick: write TDT=1 (U32 — single 4-byte MMIO write) ----
  (g_etx_bar0 + 0x3818)(U32*)[0] = 1;

  // ---- Post-kick: read results (synchronous in TCG) ----
  tdh_after  = (g_etx_bar0 + 0x3810)(U32*)[0] & 0xFFFF;
  icr_after  = (g_etx_bar0 + 0x00C0)(U32*)[0];   // read+clear ICR
  tpt_after  = (g_etx_bar0 + 0x40D4)(U32*)[0];   // TPT
  sta        = (g_etx_ring_base + 12)(U8*)[0];    // STA byte: bit 0 = DD

  dd   = sta & 1;
  txdw = (icr_after >> 0) & 1;
  txqe = (icr_after >> 1) & 1;

  // --- 4. tdh_advanced: TDH went from 0 to 1 (descriptor processed) ---
  if (tdh_before == 0 && tdh_after == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "tdh_advanced\t%s\t%d->%d\n", s, tdh_before, tdh_after);
  CatPrint(buf, "%s", line);

  // --- 5. dd_set: DD bit in STA byte = 1 (QEMU wrote back completion) ---
  if (dd == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dd_set\t%s\tsta=%02X\n", s, sta);
  CatPrint(buf, "%s", line);

  // --- 6. txdw: ICR bit 0 = TXDW (descriptor written back) ---
  if (txdw == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "txdw\t%s\tICR=%08X\n", s, icr_after);
  CatPrint(buf, "%s", line);

  // --- 7. txqe: ICR bit 1 = TXQE (TX queue empty after transmission) ---
  if (txqe == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "txqe\t%s\t%d\n", s, txqe);
  CatPrint(buf, "%s", line);

  // --- 8. tpt_one: TPT = 1 (xmit_seg ran exactly once) ---
  if (tpt_after == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "tpt_one\t%s\tTPT=%d\n", s, tpt_after);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestE1000Tx.txt", buf, StrLen(buf));
  Print("TestE1000Tx done — 8 tests\n");
}

TestE1000Tx;
