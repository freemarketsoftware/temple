// TestE1000Rx.HC — Tier 5: e1000 receive one ARP reply from QEMU SLiRP (standalone)
// Sends ARP request for 10.0.2.2, polls for ARP reply in RX descriptor ring.
// KEY: set_rx_control (RCTL write) arms flush_queue_timer (+1000ms virtual time).
//      ARP reply from SLiRP arrives while timer is pending → packet queued in QEMU.
//      A second RDT write calls qemu_flush_queued_packets(), which bypasses can_receive
//      and delivers the queued reply directly to e1000_receive_iov → DD=1.
// Results written to C:/AI/results/TestE1000Rx.txt

I64 g_rx_bar0;
I64 g_rx_txring_base;
I64 g_rx_txring[34];
U8  g_rx_txpkt[64];
I64 g_rx_rxring_base;
I64 g_rx_rxring[34];
U8  g_rx_rxbuf[2048];

U0 TestE1000Rx() {
  U8 buf[4096];
  U8 line[128];
  U8 *s;
  I64 raw, tda, rda, i;
  I64 pkt_addr, rxbuf_addr;
  I64 rctl, rdbal, rdh_after;
  I64 sta, dd, eop, len;
  I64 etype, oper;

  buf[0] = 0;
  CatPrint(buf, "# TestE1000Rx\n");

  // ---- Init (same as TestE1000Tx) ----
  g_rx_bar0 = PCIReadU32(0, 3, 0, 0x10) & 0xFFFFFFF0;
  PCIWriteU16(0, 3, 0, 0x04, 0x0107);         // Bus Master enable

  (g_rx_bar0 + 0x0000)(U32*)[0] = 1 << 26;    // CTRL soft reset
  i = 0; while(i < 500000) { i++; }
  (g_rx_bar0 + 0x0000)(U32*)[0] = 0x241;      // SLU | SPEED=01 | FD

  // TX ring
  raw = &g_rx_txring[0];
  tda = (raw + 15) & ~15;
  g_rx_txring_base = tda;
  (g_rx_bar0 + 0x3800)(U32*)[0] = tda & 0xFFFFFFFF;  // TDBAL
  (g_rx_bar0 + 0x3804)(U32*)[0] = 0;                  // TDBAH
  (g_rx_bar0 + 0x3808)(U32*)[0] = 256;                // TDLEN
  (g_rx_bar0 + 0x3810)(U32*)[0] = 0;                  // TDH
  (g_rx_bar0 + 0x3818)(U32*)[0] = 0;                  // TDT
  (g_rx_bar0 + 0x0400)(U32*)[0] = 0x0A;               // TCTL: EN | PSP

  // RX ring
  raw = &g_rx_rxring[0];
  rda = (raw + 15) & ~15;
  g_rx_rxring_base = rda;
  (g_rx_bar0 + 0x2800)(U32*)[0] = rda & 0xFFFFFFFF;  // RDBAL
  (g_rx_bar0 + 0x2804)(U32*)[0] = 0;                  // RDBAH
  (g_rx_bar0 + 0x2808)(U32*)[0] = 256;                // RDLEN = 16 slots
  (g_rx_bar0 + 0x2810)(U32*)[0] = 0;                  // RDH = 0
  (g_rx_bar0 + 0x2818)(U32*)[0] = 0;                  // RDT = 0

  // Write RX buffer address into descriptor 0, zero status
  rxbuf_addr = &g_rx_rxbuf[0];
  g_rx_rxring_base(I64*)[0]       = rxbuf_addr;  // buffer addr (bytes 0-7)
  (g_rx_rxring_base + 8)(I64*)[0] = 0;           // clear len/status/errors fields

  // Enable receiver: EN(1) | BAM(15) = 0x8002, BSIZE=00 (2048 bytes)
  // set_rx_control arms flush_queue_timer(+1000ms virtual time).
  (g_rx_bar0 + 0x0100)(U32*)[0] = 0x8002;  // RCTL: EN | BAM

  // --- 1. rctl_enabled: RCTL bit 1 = EN ---
  rctl = (g_rx_bar0 + 0x0100)(U32*)[0];
  if ((rctl & 2) == 2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rctl_enabled\t%s\tRCTL=%08X\n", s, rctl);
  CatPrint(buf, "%s", line);

  // --- 2. rdbal_match: RDBAL readback matches ring base ---
  rdbal = (g_rx_bar0 + 0x2800)(U32*)[0];
  if (rdbal == (rda & 0xFFFFFFFF)) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rdbal_match\t%s\tRDBAL=%08X ring=%08X\n", s, rdbal, rda);
  CatPrint(buf, "%s", line);

  // Give descriptor 0 to hardware: RDT = 1
  (g_rx_bar0 + 0x2818)(U32*)[0] = 1;

  // ---- Build ARP request: who-has 10.0.2.2 tell 10.0.2.15 ----
  g_rx_txpkt[0]=0xFF; g_rx_txpkt[1]=0xFF; g_rx_txpkt[2]=0xFF;  // dst: broadcast
  g_rx_txpkt[3]=0xFF; g_rx_txpkt[4]=0xFF; g_rx_txpkt[5]=0xFF;
  g_rx_txpkt[6]=0x52; g_rx_txpkt[7]=0x54; g_rx_txpkt[8]=0x00;  // src: 52:54:00:12:34:56
  g_rx_txpkt[9]=0x12; g_rx_txpkt[10]=0x34; g_rx_txpkt[11]=0x56;
  g_rx_txpkt[12]=0x08; g_rx_txpkt[13]=0x06;                     // EtherType: ARP
  g_rx_txpkt[14]=0x00; g_rx_txpkt[15]=0x01;                     // HTYPE: Ethernet
  g_rx_txpkt[16]=0x08; g_rx_txpkt[17]=0x00;                     // PTYPE: IPv4
  g_rx_txpkt[18]=0x06;                                            // HLEN
  g_rx_txpkt[19]=0x04;                                            // PLEN
  g_rx_txpkt[20]=0x00; g_rx_txpkt[21]=0x01;                     // OPER: request
  g_rx_txpkt[22]=0x52; g_rx_txpkt[23]=0x54; g_rx_txpkt[24]=0x00;// sender MAC
  g_rx_txpkt[25]=0x12; g_rx_txpkt[26]=0x34; g_rx_txpkt[27]=0x56;
  g_rx_txpkt[28]=0x0A; g_rx_txpkt[29]=0x00; g_rx_txpkt[30]=0x02; g_rx_txpkt[31]=0x0F; // sender IP 10.0.2.15
  g_rx_txpkt[32]=0x00; g_rx_txpkt[33]=0x00; g_rx_txpkt[34]=0x00;// target MAC (unknown)
  g_rx_txpkt[35]=0x00; g_rx_txpkt[36]=0x00; g_rx_txpkt[37]=0x00;
  g_rx_txpkt[38]=0x0A; g_rx_txpkt[39]=0x00; g_rx_txpkt[40]=0x02; g_rx_txpkt[41]=0x02; // target IP 10.0.2.2

  pkt_addr = &g_rx_txpkt[0];
  g_rx_txring_base(I64*)[0]       = pkt_addr;
  (g_rx_txring_base + 8)(I64*)[0] = 42 | (0x0B << 24);
  (g_rx_bar0 + 0x3818)(U32*)[0] = 1;   // TDT=1 → kick TX → SLiRP queues ARP reply
                                         // e1000_receive_iov line 923: returns 0 while
                                         // flush_queue_timer pending; reply stays queued.
                                         // Timer fires at ~1000ms virtual time via
                                         // e1000_flush_queue_timer → qemu_flush_queued_packets.

  // Sleep 2000ms so flush_queue_timer (1000ms) fires and delivers the queued ARP reply.
  Sleep(2000);

  // ---- Poll for RX completion (sanity — should be immediate after Sleep) ----
  i = 0;
  while(i < 500000) {
    sta = (g_rx_rxring_base + 12)(U8*)[0];
    if (sta & 1) break;
    i++;
  }

  dd       = sta & 1;
  eop      = (sta >> 1) & 1;
  len      = (g_rx_rxring_base + 8)(U8*)[0] | ((g_rx_rxring_base + 9)(U8*)[0] << 8);
  rdh_after = (g_rx_bar0 + 0x2810)(U32*)[0] & 0xFFFF;

  // --- 3. rx_dd: DD=1 (NIC wrote packet to buffer) ---
  if (dd == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rx_dd\t%s\tsta=%02X iters=%d\n", s, sta, i);
  CatPrint(buf, "%s", line);

  // --- 4. rx_eop: EOP=1 (single-descriptor packet, end-of-packet) ---
  if (eop == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rx_eop\t%s\tEOP=%d\n", s, eop);
  CatPrint(buf, "%s", line);

  // --- 5. rx_rdh: RDH advanced to 1 after reception ---
  if (rdh_after == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rx_rdh\t%s\tRDH=%d\n", s, rdh_after);
  CatPrint(buf, "%s", line);

  // --- 6. rx_len: received length >= 42 (ARP reply is 42 bytes) ---
  if (len >= 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rx_len\t%s\tlen=%d\n", s, len);
  CatPrint(buf, "%s", line);

  // Parse received frame (only meaningful when DD=1)
  etype = (g_rx_rxbuf[12] << 8) | g_rx_rxbuf[13];
  oper  = (g_rx_rxbuf[20] << 8) | g_rx_rxbuf[21];

  // --- 7. rx_arp: EtherType = 0x0806 ---
  if (etype == 0x0806) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rx_arp\t%s\tEtherType=%04X\n", s, etype);
  CatPrint(buf, "%s", line);

  // --- 8. rx_arp_reply: ARP OPER = 2 (reply from QEMU SLiRP gateway 10.0.2.2) ---
  if (oper == 2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "rx_arp_reply\t%s\tOPER=%04X\n", s, oper);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestE1000Rx.txt", buf, StrLen(buf));
  Print("TestE1000Rx done — 8 tests\n");
}

TestE1000Rx;
