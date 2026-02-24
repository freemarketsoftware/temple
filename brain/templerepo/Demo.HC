// Demo.HC — TempleOS Network Stack Demo
// Four-phase walkthrough: NIC init → ARP → ICMP ping → HTTP GET over TCP
// Output: C:/AI/results/Demo.txt  (plain text, read by run_demo.py)
// Run with: sudo python3 serial/run_demo.py
// Standalone only (direct MMIO NIC access).
//
// Uses 10 RX descriptors with scan-and-match so stale SLiRP RSTs/FINs
// from previous test sessions are transparently skipped.

// ── Globals ──────────────────────────────────────────────────────────────────
I64 g_demo_bar0;
I64 g_demo_txbase;
I64 g_demo_txring[34];
I64 g_demo_rxbase;
I64 g_demo_rxring[34];
I64 g_demo_rxptrs[10];   // pointers into each rx buffer for index-based access

U8  g_demo_arp_tx[64];
U8  g_demo_icmp_tx[64];
U8  g_demo_syn_tx[64];
U8  g_demo_get_tx[128];

U8  g_demo_rx0[2048];    // 10 RX buffers — absorb stale packets transparently
U8  g_demo_rx1[2048];
U8  g_demo_rx2[2048];
U8  g_demo_rx3[2048];
U8  g_demo_rx4[2048];
U8  g_demo_rx5[2048];
U8  g_demo_rx6[2048];
U8  g_demo_rx7[2048];
U8  g_demo_rx8[2048];
U8  g_demo_rx9[2048];

U8  g_demo_gw_mac[8];
U8  g_demo_pseudo[12];
U8  g_demo_out[8192];

// ── Checksum helpers ──────────────────────────────────────────────────────────
I64 DemoIPCksum(U8 *hdr) {
  I64 sum, i;
  sum = 0;
  for (i = 0; i < 20; i += 2)
    sum += (hdr[i] << 8) | hdr[i+1];
  while (sum >> 16) sum = (sum & 0xFFFF) + (sum >> 16);
  return (~sum) & 0xFFFF;
}

I64 DemoOnesAcc(U8 *data, I64 len) {
  I64 sum, i;
  sum = 0; i = 0;
  while (i + 1 < len) {
    sum += (data[i] << 8) | data[i+1];
    i += 2;
  }
  if (i < len) sum += data[i] << 8;
  return sum;
}

I64 DemoTCPCksum(U8 *tcp, I64 tcp_len) {
  I64 raw;
  raw = DemoOnesAcc(g_demo_pseudo, 12) + DemoOnesAcc(tcp, tcp_len);
  while (raw >> 16) raw = (raw & 0xFFFF) + (raw >> 16);
  return (~raw) & 0xFFFF;
}

// ── Demo ─────────────────────────────────────────────────────────────────────
U0 RunDemo() {
  U8 line[128];
  U8 *link_str, *duplex_str, *cksum_str;
  I64 raw, tda, rda, i, j;
  I64 pkt_addr, cksum, sum;
  I64 rx_sta;
  I64 ctrl_val, status_val, ral_val, rah_val;
  I64 mac0, mac1, mac2, mac3, mac4, mac5;
  I64 server_isn, synack_ack, synack_flags;
  I64 ip_total_len, tcp_data_off, scan_start, rx_end;
  I64 icmp_id, icmp_seq, icmp_len, icmp_cksum_ok;
  I64 out_len, ch;
  I64 demo_port, demo_port_hi, demo_port_lo;
  I64 arp_idx, icmp_idx, syn_idx, http_idx;

  g_demo_out[0] = 0;
  CatPrint(g_demo_out, "=== TempleOS Network Stack Demo ===\n\n");

  // ──────────────────────────────────────────────────────────────
  //  PHASE 1 — NIC INIT
  // ──────────────────────────────────────────────────────────────
  g_demo_bar0 = PCIReadU32(0, 3, 0, 0x10) & 0xFFFFFFF0;
  PCIWriteU16(0, 3, 0, 0x04, 0x0107);
  (g_demo_bar0 + 0x0000)(U32*)[0] = 1 << 26;
  i = 0; while (i < 500000) { i++; }
  (g_demo_bar0 + 0x0000)(U32*)[0] = 0x241;

  ctrl_val   = (g_demo_bar0 + 0x0000)(U32*)[0];
  status_val = (g_demo_bar0 + 0x0008)(U32*)[0];
  ral_val    = (g_demo_bar0 + 0x5400)(U32*)[0];
  rah_val    = (g_demo_bar0 + 0x5404)(U32*)[0];
  mac0 = (ral_val >>  0) & 0xFF; mac1 = (ral_val >>  8) & 0xFF;
  mac2 = (ral_val >> 16) & 0xFF; mac3 = (ral_val >> 24) & 0xFF;
  mac4 = (rah_val >>  0) & 0xFF; mac5 = (rah_val >>  8) & 0xFF;

  CatPrint(g_demo_out, "[1/4] NIC INIT\n");
  StrPrint(line, "  BAR0:   0x%08X\n", g_demo_bar0);   CatPrint(g_demo_out, "%s", line);
  StrPrint(line, "  CTRL:   0x%08X\n", ctrl_val);       CatPrint(g_demo_out, "%s", line);
  if (status_val & 2) link_str = "UP"; else link_str = "DOWN";
  if (status_val & 1) duplex_str = "FD"; else duplex_str = "HD";
  StrPrint(line, "  STATUS: 0x%08X  (link=%s, %s)\n", status_val, link_str, duplex_str);
  CatPrint(g_demo_out, "%s", line);
  StrPrint(line, "  MAC:    %02X:%02X:%02X:%02X:%02X:%02X\n",
    mac0, mac1, mac2, mac3, mac4, mac5);
  CatPrint(g_demo_out, "%s", line);
  CatPrint(g_demo_out, "\n");

  // TX ring
  raw = &g_demo_txring[0]; tda = (raw + 15) & ~15;
  g_demo_txbase = tda;
  (g_demo_bar0 + 0x3800)(U32*)[0] = tda & 0xFFFFFFFF;
  (g_demo_bar0 + 0x3804)(U32*)[0] = 0;
  (g_demo_bar0 + 0x3808)(U32*)[0] = 256;
  (g_demo_bar0 + 0x3810)(U32*)[0] = 0;
  (g_demo_bar0 + 0x3818)(U32*)[0] = 0;
  (g_demo_bar0 + 0x0400)(U32*)[0] = 0x0A;

  // RX ring — 10 descriptors (RDLEN=256=16 slots)
  raw = &g_demo_rxring[0]; rda = (raw + 15) & ~15;
  g_demo_rxbase = rda;
  (g_demo_bar0 + 0x2800)(U32*)[0] = rda & 0xFFFFFFFF;
  (g_demo_bar0 + 0x2804)(U32*)[0] = 0;
  (g_demo_bar0 + 0x2808)(U32*)[0] = 256;
  (g_demo_bar0 + 0x2810)(U32*)[0] = 0;
  (g_demo_bar0 + 0x2818)(U32*)[0] = 0;

  // Pointer table for index-based buffer access
  g_demo_rxptrs[0] = &g_demo_rx0[0]; g_demo_rxptrs[1] = &g_demo_rx1[0];
  g_demo_rxptrs[2] = &g_demo_rx2[0]; g_demo_rxptrs[3] = &g_demo_rx3[0];
  g_demo_rxptrs[4] = &g_demo_rx4[0]; g_demo_rxptrs[5] = &g_demo_rx5[0];
  g_demo_rxptrs[6] = &g_demo_rx6[0]; g_demo_rxptrs[7] = &g_demo_rx7[0];
  g_demo_rxptrs[8] = &g_demo_rx8[0]; g_demo_rxptrs[9] = &g_demo_rx9[0];

  // Write all 10 descriptors into the ring
  for (j = 0; j < 10; j++) {
    (g_demo_rxbase + j*16    )(I64*)[0] = g_demo_rxptrs[j];
    (g_demo_rxbase + j*16 + 8)(I64*)[0] = 0;
  }

  // Enable RX + give all 10 descriptors to HW
  (g_demo_bar0 + 0x0100)(U32*)[0] = 0x8002;
  (g_demo_bar0 + 0x2818)(U32*)[0] = 10;

  // ──────────────────────────────────────────────────────────────
  //  PHASE 2 — ARP
  // ──────────────────────────────────────────────────────────────
  CatPrint(g_demo_out, "[2/4] ARP\n");
  CatPrint(g_demo_out, "  Query:  who-has 10.0.2.2 tell 10.0.2.15?\n");

  MemSet(g_demo_arp_tx, 0, 64);
  g_demo_arp_tx[0]=0xFF; g_demo_arp_tx[1]=0xFF; g_demo_arp_tx[2]=0xFF;
  g_demo_arp_tx[3]=0xFF; g_demo_arp_tx[4]=0xFF; g_demo_arp_tx[5]=0xFF;
  g_demo_arp_tx[6]=0x52; g_demo_arp_tx[7]=0x54; g_demo_arp_tx[8]=0x00;
  g_demo_arp_tx[9]=0x12; g_demo_arp_tx[10]=0x34; g_demo_arp_tx[11]=0x56;
  g_demo_arp_tx[12]=0x08; g_demo_arp_tx[13]=0x06;
  g_demo_arp_tx[14]=0x00; g_demo_arp_tx[15]=0x01;
  g_demo_arp_tx[16]=0x08; g_demo_arp_tx[17]=0x00;
  g_demo_arp_tx[18]=0x06; g_demo_arp_tx[19]=0x04;
  g_demo_arp_tx[20]=0x00; g_demo_arp_tx[21]=0x01;
  g_demo_arp_tx[22]=0x52; g_demo_arp_tx[23]=0x54; g_demo_arp_tx[24]=0x00;
  g_demo_arp_tx[25]=0x12; g_demo_arp_tx[26]=0x34; g_demo_arp_tx[27]=0x56;
  g_demo_arp_tx[28]=0x0A; g_demo_arp_tx[29]=0x00;
  g_demo_arp_tx[30]=0x02; g_demo_arp_tx[31]=0x0F;
  g_demo_arp_tx[38]=0x0A; g_demo_arp_tx[39]=0x00;
  g_demo_arp_tx[40]=0x02; g_demo_arp_tx[41]=0x02;

  pkt_addr = &g_demo_arp_tx[0];
  g_demo_txbase(I64*)[0]       = pkt_addr;
  (g_demo_txbase + 8)(I64*)[0] = 42 | (0x0B << 24);
  (g_demo_bar0 + 0x3818)(U32*)[0] = 1;
  Sleep(2000);  // flush_queue_timer fires, delivers ARP reply + any stale SLiRP packets

  // Scan descriptors 0-9 for ARP reply (EtherType=0x0806, op=2)
  arp_idx = -1;
  j = 0;
  while (j < 10 && arp_idx < 0) {
    i = 0;
    while (i < 500000) {
      rx_sta = (g_demo_rxbase + j*16 + 12)(U8*)[0];
      if (rx_sta & 1) break;
      i++;
    }
    if (!(rx_sta & 1)) break;
    if ((g_demo_rxptrs[j])(U8*)[12] == 0x08 &&
        (g_demo_rxptrs[j])(U8*)[13] == 0x06 &&
        (g_demo_rxptrs[j])(U8*)[21] == 2) {
      arp_idx = j;
    } else {
      j++;
    }
  }

  if (arp_idx >= 0) {
    for (j = 0; j < 6; j++) g_demo_gw_mac[j] = (g_demo_rxptrs[arp_idx])(U8*)[22+j];
    StrPrint(line, "  Reply:  10.0.2.2 is at %02X:%02X:%02X:%02X:%02X:%02X\n",
      g_demo_gw_mac[0], g_demo_gw_mac[1], g_demo_gw_mac[2],
      g_demo_gw_mac[3], g_demo_gw_mac[4], g_demo_gw_mac[5]);
  } else {
    StrPrint(line, "  Reply:  TIMEOUT\n");
    g_demo_gw_mac[0]=0x52; g_demo_gw_mac[1]=0x55; g_demo_gw_mac[2]=0x0A;
    g_demo_gw_mac[3]=0x00; g_demo_gw_mac[4]=0x02; g_demo_gw_mac[5]=0x02;
    arp_idx = 0;
  }
  CatPrint(g_demo_out, "%s", line);
  CatPrint(g_demo_out, "\n");

  // ──────────────────────────────────────────────────────────────
  //  PHASE 3 — ICMP PING
  // ──────────────────────────────────────────────────────────────
  CatPrint(g_demo_out, "[3/4] ICMP PING\n");
  CatPrint(g_demo_out, "  Sent:   echo req  id=0xD3F0  seq=1\n");

  MemSet(g_demo_icmp_tx, 0, 64);
  for (j = 0; j < 6; j++) g_demo_icmp_tx[j] = g_demo_gw_mac[j];
  g_demo_icmp_tx[6]=0x52; g_demo_icmp_tx[7]=0x54; g_demo_icmp_tx[8]=0x00;
  g_demo_icmp_tx[9]=0x12; g_demo_icmp_tx[10]=0x34; g_demo_icmp_tx[11]=0x56;
  g_demo_icmp_tx[12]=0x08; g_demo_icmp_tx[13]=0x00;
  g_demo_icmp_tx[14]=0x45; g_demo_icmp_tx[16]=0x00; g_demo_icmp_tx[17]=0x1C;
  g_demo_icmp_tx[18]=0x00; g_demo_icmp_tx[19]=0x04;
  g_demo_icmp_tx[20]=0x40; g_demo_icmp_tx[22]=64; g_demo_icmp_tx[23]=1;
  g_demo_icmp_tx[26]=0x0A; g_demo_icmp_tx[27]=0x00;
  g_demo_icmp_tx[28]=0x02; g_demo_icmp_tx[29]=0x0F;
  g_demo_icmp_tx[30]=0x0A; g_demo_icmp_tx[31]=0x00;
  g_demo_icmp_tx[32]=0x02; g_demo_icmp_tx[33]=0x02;
  g_demo_icmp_tx[34]=0x08;
  g_demo_icmp_tx[38]=0xD3; g_demo_icmp_tx[39]=0xF0;
  g_demo_icmp_tx[40]=0x00; g_demo_icmp_tx[41]=0x01;
  sum = 0x0800 + 0x0000 + 0xD3F0 + 0x0001;
  while (sum >> 16) sum = (sum & 0xFFFF) + (sum >> 16);
  cksum = (~sum) & 0xFFFF;
  g_demo_icmp_tx[36] = (cksum >> 8) & 0xFF;
  g_demo_icmp_tx[37] =  cksum       & 0xFF;
  cksum = DemoIPCksum(&g_demo_icmp_tx[14]);
  g_demo_icmp_tx[24] = (cksum >> 8) & 0xFF;
  g_demo_icmp_tx[25] =  cksum       & 0xFF;

  pkt_addr = &g_demo_icmp_tx[0];
  (g_demo_txbase + 16)(I64*)[0] = pkt_addr;
  (g_demo_txbase + 24)(I64*)[0] = 42 | (0x0B << 24);
  (g_demo_bar0 + 0x3818)(U32*)[0] = 2;  // TDT=2

  // Scan from arp_idx+1 for ICMP echo reply (IP proto=1, type=0)
  icmp_idx = -1;
  j = arp_idx + 1;
  while (j < 10 && icmp_idx < 0) {
    i = 0;
    while (i < 500000) {
      rx_sta = (g_demo_rxbase + j*16 + 12)(U8*)[0];
      if (rx_sta & 1) break;
      i++;
    }
    if (!(rx_sta & 1)) break;
    if ((g_demo_rxptrs[j])(U8*)[12] == 0x08 &&
        (g_demo_rxptrs[j])(U8*)[13] == 0x00 &&
        (g_demo_rxptrs[j])(U8*)[23] == 1    &&
        (g_demo_rxptrs[j])(U8*)[34] == 0) {
      icmp_idx = j;
    } else {
      j++;
    }
  }

  if (icmp_idx >= 0) {
    icmp_id  = ((g_demo_rxptrs[icmp_idx])(U8*)[38] << 8) |
                (g_demo_rxptrs[icmp_idx])(U8*)[39];
    icmp_seq = ((g_demo_rxptrs[icmp_idx])(U8*)[40] << 8) |
                (g_demo_rxptrs[icmp_idx])(U8*)[41];
    ip_total_len = ((g_demo_rxptrs[icmp_idx])(U8*)[16] << 8) |
                    (g_demo_rxptrs[icmp_idx])(U8*)[17];
    icmp_len = ip_total_len - 20;
    sum = 0;
    for (j = 0; j < icmp_len; j += 2)
      sum += ((g_demo_rxptrs[icmp_idx])(U8*)[34+j] << 8) |
              (g_demo_rxptrs[icmp_idx])(U8*)[35+j];
    while (sum >> 16) sum = (sum & 0xFFFF) + (sum >> 16);
    icmp_cksum_ok = (~sum) & 0xFFFF;
    if (icmp_cksum_ok == 0) cksum_str = "OK"; else cksum_str = "FAIL";
    StrPrint(line, "  Reply:  echo rep  id=0x%04X  seq=%d  cksum=%s\n",
      icmp_id, icmp_seq, cksum_str);
  } else {
    StrPrint(line, "  Reply:  TIMEOUT\n");
    icmp_idx = arp_idx + 1;
  }
  CatPrint(g_demo_out, "%s", line);
  CatPrint(g_demo_out, "\n");

  // ──────────────────────────────────────────────────────────────
  //  PHASE 4 — HTTP GET over TCP
  // ──────────────────────────────────────────────────────────────
  CatPrint(g_demo_out, "[4/4] HTTP GET http://10.0.2.2:8080/\n");

  demo_port    = 0xC000 + (SysTimerRead() & 0x0FFF);
  demo_port_hi = (demo_port >> 8) & 0xFF;
  demo_port_lo =  demo_port       & 0xFF;
  StrPrint(line, "  Connecting from port %d\n", demo_port);
  CatPrint(g_demo_out, "%s", line);

  MemSet(g_demo_syn_tx, 0, 64);
  for (j = 0; j < 6; j++) g_demo_syn_tx[j] = g_demo_gw_mac[j];
  g_demo_syn_tx[6]=0x52; g_demo_syn_tx[7]=0x54; g_demo_syn_tx[8]=0x00;
  g_demo_syn_tx[9]=0x12; g_demo_syn_tx[10]=0x34; g_demo_syn_tx[11]=0x56;
  g_demo_syn_tx[12]=0x08; g_demo_syn_tx[13]=0x00;
  g_demo_syn_tx[14]=0x45; g_demo_syn_tx[16]=0x00; g_demo_syn_tx[17]=0x28;
  g_demo_syn_tx[18]=0x00; g_demo_syn_tx[19]=0x05;
  g_demo_syn_tx[20]=0x40; g_demo_syn_tx[22]=64; g_demo_syn_tx[23]=6;
  g_demo_syn_tx[26]=0x0A; g_demo_syn_tx[27]=0x00;
  g_demo_syn_tx[28]=0x02; g_demo_syn_tx[29]=0x0F;
  g_demo_syn_tx[30]=0x0A; g_demo_syn_tx[31]=0x00;
  g_demo_syn_tx[32]=0x02; g_demo_syn_tx[33]=0x02;
  g_demo_syn_tx[34]=demo_port_hi; g_demo_syn_tx[35]=demo_port_lo;
  g_demo_syn_tx[36]=0x1F; g_demo_syn_tx[37]=0x90;  // dst_port=8080
  g_demo_syn_tx[38]=0xDE; g_demo_syn_tx[39]=0xAD;  // ISN=0xDEADB33F
  g_demo_syn_tx[40]=0xB3; g_demo_syn_tx[41]=0x3F;
  g_demo_syn_tx[46]=0x50; g_demo_syn_tx[47]=0x02;  // SYN
  g_demo_syn_tx[48]=0xFF; g_demo_syn_tx[49]=0xFF;

  g_demo_pseudo[0]=0x0A; g_demo_pseudo[1]=0x00;
  g_demo_pseudo[2]=0x02; g_demo_pseudo[3]=0x0F;
  g_demo_pseudo[4]=0x0A; g_demo_pseudo[5]=0x00;
  g_demo_pseudo[6]=0x02; g_demo_pseudo[7]=0x02;
  g_demo_pseudo[8]=0; g_demo_pseudo[9]=6;
  g_demo_pseudo[10]=0; g_demo_pseudo[11]=20;

  cksum = DemoTCPCksum(&g_demo_syn_tx[34], 20);
  g_demo_syn_tx[50] = (cksum >> 8) & 0xFF;
  g_demo_syn_tx[51] =  cksum       & 0xFF;
  cksum = DemoIPCksum(&g_demo_syn_tx[14]);
  g_demo_syn_tx[24] = (cksum >> 8) & 0xFF;
  g_demo_syn_tx[25] =  cksum       & 0xFF;

  pkt_addr = &g_demo_syn_tx[0];
  (g_demo_txbase + 32)(I64*)[0] = pkt_addr;
  (g_demo_txbase + 40)(I64*)[0] = 54 | (0x0B << 24);
  (g_demo_bar0 + 0x3818)(U32*)[0] = 3;
  Sleep(2000);

  // Scan from icmp_idx+1 for SYN-ACK (IP proto=6, flags=0x12 or has ACK bit)
  server_isn = 0; syn_idx = -1;
  j = icmp_idx + 1;
  while (j < 10 && syn_idx < 0) {
    i = 0;
    while (i < 500000) {
      rx_sta = (g_demo_rxbase + j*16 + 12)(U8*)[0];
      if (rx_sta & 1) break;
      i++;
    }
    if (!(rx_sta & 1)) break;
    if ((g_demo_rxptrs[j])(U8*)[12] == 0x08 &&
        (g_demo_rxptrs[j])(U8*)[13] == 0x00 &&
        (g_demo_rxptrs[j])(U8*)[23] == 6    &&
        ((g_demo_rxptrs[j])(U8*)[47] & 0x12) == 0x12) {
      syn_idx = j;
    } else {
      j++;
    }
  }

  if (syn_idx >= 0) {
    server_isn   = ((g_demo_rxptrs[syn_idx])(U8*)[38]<<24) |
                   ((g_demo_rxptrs[syn_idx])(U8*)[39]<<16) |
                   ((g_demo_rxptrs[syn_idx])(U8*)[40]<< 8) |
                    (g_demo_rxptrs[syn_idx])(U8*)[41];
    synack_ack   = ((g_demo_rxptrs[syn_idx])(U8*)[42]<<24) |
                   ((g_demo_rxptrs[syn_idx])(U8*)[43]<<16) |
                   ((g_demo_rxptrs[syn_idx])(U8*)[44]<< 8) |
                    (g_demo_rxptrs[syn_idx])(U8*)[45];
    synack_flags =  (g_demo_rxptrs[syn_idx])(U8*)[47];
    StrPrint(line, "  SYN-ACK: server_isn=0x%08X  ack=0x%08X  flags=0x%02X\n",
      server_isn, synack_ack, synack_flags);
  } else {
    StrPrint(line, "  SYN-ACK: TIMEOUT\n");
    syn_idx = icmp_idx + 1;
  }
  CatPrint(g_demo_out, "%s", line);

  MemSet(g_demo_get_tx, 0, 128);
  for (j = 0; j < 6; j++) g_demo_get_tx[j] = g_demo_gw_mac[j];
  g_demo_get_tx[6]=0x52; g_demo_get_tx[7]=0x54; g_demo_get_tx[8]=0x00;
  g_demo_get_tx[9]=0x12; g_demo_get_tx[10]=0x34; g_demo_get_tx[11]=0x56;
  g_demo_get_tx[12]=0x08; g_demo_get_tx[13]=0x00;
  g_demo_get_tx[14]=0x45; g_demo_get_tx[16]=0x00; g_demo_get_tx[17]=0x4A;
  g_demo_get_tx[18]=0x00; g_demo_get_tx[19]=0x06;
  g_demo_get_tx[20]=0x40; g_demo_get_tx[22]=64; g_demo_get_tx[23]=6;
  g_demo_get_tx[26]=0x0A; g_demo_get_tx[27]=0x00;
  g_demo_get_tx[28]=0x02; g_demo_get_tx[29]=0x0F;
  g_demo_get_tx[30]=0x0A; g_demo_get_tx[31]=0x00;
  g_demo_get_tx[32]=0x02; g_demo_get_tx[33]=0x02;
  g_demo_get_tx[34]=demo_port_hi; g_demo_get_tx[35]=demo_port_lo;
  g_demo_get_tx[36]=0x1F; g_demo_get_tx[37]=0x90;
  g_demo_get_tx[38]=0xDE; g_demo_get_tx[39]=0xAD;  // seq=0xDEADB340
  g_demo_get_tx[40]=0xB3; g_demo_get_tx[41]=0x40;
  g_demo_get_tx[42] = ((server_isn+1) >> 24) & 0xFF;
  g_demo_get_tx[43] = ((server_isn+1) >> 16) & 0xFF;
  g_demo_get_tx[44] = ((server_isn+1) >>  8) & 0xFF;
  g_demo_get_tx[45] =  (server_isn+1)        & 0xFF;
  g_demo_get_tx[46]=0x50; g_demo_get_tx[47]=0x18;  // PSH|ACK
  g_demo_get_tx[48]=0xFF; g_demo_get_tx[49]=0xFF;
  // "GET / HTTP/1.0\r\nHost: 10.0.2.2\r\n\r\n"
  g_demo_get_tx[54]=0x47; g_demo_get_tx[55]=0x45; g_demo_get_tx[56]=0x54;
  g_demo_get_tx[57]=0x20; g_demo_get_tx[58]=0x2F; g_demo_get_tx[59]=0x20;
  g_demo_get_tx[60]=0x48; g_demo_get_tx[61]=0x54; g_demo_get_tx[62]=0x54;
  g_demo_get_tx[63]=0x50; g_demo_get_tx[64]=0x2F; g_demo_get_tx[65]=0x31;
  g_demo_get_tx[66]=0x2E; g_demo_get_tx[67]=0x30; g_demo_get_tx[68]=0x0D;
  g_demo_get_tx[69]=0x0A; g_demo_get_tx[70]=0x48; g_demo_get_tx[71]=0x6F;
  g_demo_get_tx[72]=0x73; g_demo_get_tx[73]=0x74; g_demo_get_tx[74]=0x3A;
  g_demo_get_tx[75]=0x20; g_demo_get_tx[76]=0x31; g_demo_get_tx[77]=0x30;
  g_demo_get_tx[78]=0x2E; g_demo_get_tx[79]=0x30; g_demo_get_tx[80]=0x2E;
  g_demo_get_tx[81]=0x32; g_demo_get_tx[82]=0x2E; g_demo_get_tx[83]=0x32;
  g_demo_get_tx[84]=0x0D; g_demo_get_tx[85]=0x0A;
  g_demo_get_tx[86]=0x0D; g_demo_get_tx[87]=0x0A;

  g_demo_pseudo[10]=0; g_demo_pseudo[11]=54;
  cksum = DemoTCPCksum(&g_demo_get_tx[34], 54);
  g_demo_get_tx[50] = (cksum >> 8) & 0xFF;
  g_demo_get_tx[51] =  cksum       & 0xFF;
  cksum = DemoIPCksum(&g_demo_get_tx[14]);
  g_demo_get_tx[24] = (cksum >> 8) & 0xFF;
  g_demo_get_tx[25] =  cksum       & 0xFF;

  CatPrint(g_demo_out, "  ACK+GET sent (GET / HTTP/1.0 ...)\n");

  pkt_addr = &g_demo_get_tx[0];
  (g_demo_txbase + 48)(I64*)[0] = pkt_addr;
  (g_demo_txbase + 56)(I64*)[0] = 88 | (0x0B << 24);
  (g_demo_bar0 + 0x3818)(U32*)[0] = 4;
  Sleep(2000);

  // Scan from syn_idx+1 for TCP segment with actual payload data
  // Must check actual TCP payload = ip_total_len - 20 - tcp_data_off > 0
  // to skip pure ACKs that may carry TCP options (ip_total_len=44, payload=0)
  http_idx = -1;
  j = syn_idx + 1;
  while (j < 10 && http_idx < 0) {
    i = 0;
    while (i < 500000) {
      rx_sta = (g_demo_rxbase + j*16 + 12)(U8*)[0];
      if (rx_sta & 1) break;
      i++;
    }
    if (!(rx_sta & 1)) break;
    ip_total_len = ((g_demo_rxptrs[j])(U8*)[16] << 8) |
                    (g_demo_rxptrs[j])(U8*)[17];
    tcp_data_off = ((g_demo_rxptrs[j])(U8*)[46] >> 4) * 4;
    if ((g_demo_rxptrs[j])(U8*)[12] == 0x08 &&
        (g_demo_rxptrs[j])(U8*)[13] == 0x00 &&
        (g_demo_rxptrs[j])(U8*)[23] == 6    &&
        ip_total_len - 20 - tcp_data_off > 0) {
      http_idx = j;
    } else {
      j++;
    }
  }

  if (http_idx >= 0) {
    ip_total_len = ((g_demo_rxptrs[http_idx])(U8*)[16] << 8) |
                    (g_demo_rxptrs[http_idx])(U8*)[17];
    tcp_data_off = ((g_demo_rxptrs[http_idx])(U8*)[46] >> 4) * 4;
    scan_start   = 14 + 20 + tcp_data_off;
    rx_end       = 14 + ip_total_len;
    if (rx_end > 2048) rx_end = 2048;

    StrPrint(line, "  Response: %d bytes IP payload  (TCP data at frame+%d)\n\n",
      ip_total_len, scan_start);
    CatPrint(g_demo_out, "%s", line);
    CatPrint(g_demo_out, "--- HTTP Response ---\n");

    out_len = StrLen(g_demo_out);
    j = scan_start;
    while (j < rx_end && out_len < 7800) {
      ch = (g_demo_rxptrs[http_idx])(U8*)[j];
      if (ch != 0x0D) {
        if (ch == 0x0A) {
          g_demo_out[out_len] = 0x0A;
          out_len++;
        } else if (ch >= 0x20 && ch < 0x7F) {
          g_demo_out[out_len] = ch;
          out_len++;
        } else {
          g_demo_out[out_len] = '.';
          out_len++;
        }
        g_demo_out[out_len] = 0;
      }
      j++;
    }
  } else {
    CatPrint(g_demo_out, "  Response: TIMEOUT\n\n");
    CatPrint(g_demo_out, "--- HTTP Response ---\n");
  }

  CatPrint(g_demo_out, "--- End Response ---\n\n");
  CatPrint(g_demo_out, "=== ALL DONE ===\n");

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/Demo.txt", g_demo_out, StrLen(g_demo_out));
  Print("Demo done\n");
}

RunDemo;
