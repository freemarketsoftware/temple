// TestICMP.HC — Tier 6: ICMP echo request/reply via e1000 + QEMU SLiRP (standalone)
// Flow: ARP discover gateway MAC → ICMP echo request → verify echo reply.
// KEY: Sleep(2000) after RCTL write lets flush_queue_timer fire for ARP reply.
//      After timer fires, ICMP reply is delivered synchronously on TX kick.
// Results written to C:/AI/results/TestICMP.txt

I64 g_icmp_bar0;
I64 g_icmp_txring_base;
I64 g_icmp_txring[34];
U8  g_icmp_arp_pkt[64];   // ARP request TX frame
U8  g_icmp_tx_pkt[64];    // ICMP echo request TX frame
I64 g_icmp_rxring_base;
I64 g_icmp_rxring[34];
U8  g_icmp_rxbuf0[2048];  // descriptor 0: receives ARP reply
U8  g_icmp_rxbuf1[2048];  // descriptor 1: receives ICMP echo reply
U8  g_icmp_gw_mac[8];     // discovered gateway MAC (6 bytes used)

U0 TestICMP() {
  U8 buf[4096];
  U8 line[128];
  U8 *s;
  I64 raw, tda, rda, i;
  I64 pkt_addr, rxbuf0_addr, rxbuf1_addr;
  I64 sta0, dd0, sta1, dd1;
  I64 sum, cksum;
  I64 icmp_type, icmp_code, icmp_id, icmp_seq;
  I64 ip_total_len, icmp_len, icmp_ok;

  buf[0] = 0;
  CatPrint(buf, "# TestICMP\n");

  // ---- Init ----
  g_icmp_bar0 = PCIReadU32(0, 3, 0, 0x10) & 0xFFFFFFF0;
  PCIWriteU16(0, 3, 0, 0x04, 0x0107);          // PCI Bus Master
  (g_icmp_bar0 + 0x0000)(U32*)[0] = 1 << 26;   // CTRL soft reset
  i = 0; while(i < 500000) { i++; }
  (g_icmp_bar0 + 0x0000)(U32*)[0] = 0x241;     // SLU|SPEED=01|FD

  // TX ring
  raw = &g_icmp_txring[0];
  tda = (raw + 15) & ~15;
  g_icmp_txring_base = tda;
  (g_icmp_bar0 + 0x3800)(U32*)[0] = tda & 0xFFFFFFFF;
  (g_icmp_bar0 + 0x3804)(U32*)[0] = 0;
  (g_icmp_bar0 + 0x3808)(U32*)[0] = 256;
  (g_icmp_bar0 + 0x3810)(U32*)[0] = 0;
  (g_icmp_bar0 + 0x3818)(U32*)[0] = 0;
  (g_icmp_bar0 + 0x0400)(U32*)[0] = 0x0A;      // TCTL: EN|PSP

  // RX ring — 2 descriptors (indices 0 and 1) for ARP reply + ICMP reply
  raw = &g_icmp_rxring[0];
  rda = (raw + 15) & ~15;
  g_icmp_rxring_base = rda;
  (g_icmp_bar0 + 0x2800)(U32*)[0] = rda & 0xFFFFFFFF;
  (g_icmp_bar0 + 0x2804)(U32*)[0] = 0;
  (g_icmp_bar0 + 0x2808)(U32*)[0] = 256;        // RDLEN = 16 slots
  (g_icmp_bar0 + 0x2810)(U32*)[0] = 0;
  (g_icmp_bar0 + 0x2818)(U32*)[0] = 0;

  // Write buffer addresses into descriptors 0 and 1
  rxbuf0_addr = &g_icmp_rxbuf0[0];
  rxbuf1_addr = &g_icmp_rxbuf1[0];
  g_icmp_rxring_base(I64*)[0]        = rxbuf0_addr;  // desc 0: buf addr
  (g_icmp_rxring_base +  8)(I64*)[0] = 0;            // desc 0: clear status
  (g_icmp_rxring_base + 16)(I64*)[0] = rxbuf1_addr;  // desc 1: buf addr
  (g_icmp_rxring_base + 24)(I64*)[0] = 0;            // desc 1: clear status

  // Enable RX: EN|BAM=0x8002. set_rx_control arms flush_queue_timer(+1000ms).
  (g_icmp_bar0 + 0x0100)(U32*)[0] = 0x8002;
  (g_icmp_bar0 + 0x2818)(U32*)[0] = 2;              // RDT=2: give descs 0+1 to HW

  // ---- ARP request: who-has 10.0.2.2 tell 10.0.2.15 ----
  g_icmp_arp_pkt[0]=0xFF; g_icmp_arp_pkt[1]=0xFF; g_icmp_arp_pkt[2]=0xFF;
  g_icmp_arp_pkt[3]=0xFF; g_icmp_arp_pkt[4]=0xFF; g_icmp_arp_pkt[5]=0xFF;
  g_icmp_arp_pkt[6]=0x52; g_icmp_arp_pkt[7]=0x54; g_icmp_arp_pkt[8]=0x00;
  g_icmp_arp_pkt[9]=0x12; g_icmp_arp_pkt[10]=0x34; g_icmp_arp_pkt[11]=0x56;
  g_icmp_arp_pkt[12]=0x08; g_icmp_arp_pkt[13]=0x06;
  g_icmp_arp_pkt[14]=0x00; g_icmp_arp_pkt[15]=0x01;
  g_icmp_arp_pkt[16]=0x08; g_icmp_arp_pkt[17]=0x00;
  g_icmp_arp_pkt[18]=0x06; g_icmp_arp_pkt[19]=0x04;
  g_icmp_arp_pkt[20]=0x00; g_icmp_arp_pkt[21]=0x01;
  g_icmp_arp_pkt[22]=0x52; g_icmp_arp_pkt[23]=0x54; g_icmp_arp_pkt[24]=0x00;
  g_icmp_arp_pkt[25]=0x12; g_icmp_arp_pkt[26]=0x34; g_icmp_arp_pkt[27]=0x56;
  g_icmp_arp_pkt[28]=0x0A; g_icmp_arp_pkt[29]=0x00; g_icmp_arp_pkt[30]=0x02; g_icmp_arp_pkt[31]=0x0F;
  g_icmp_arp_pkt[32]=0x00; g_icmp_arp_pkt[33]=0x00; g_icmp_arp_pkt[34]=0x00;
  g_icmp_arp_pkt[35]=0x00; g_icmp_arp_pkt[36]=0x00; g_icmp_arp_pkt[37]=0x00;
  g_icmp_arp_pkt[38]=0x0A; g_icmp_arp_pkt[39]=0x00; g_icmp_arp_pkt[40]=0x02; g_icmp_arp_pkt[41]=0x02;

  pkt_addr = &g_icmp_arp_pkt[0];
  g_icmp_txring_base(I64*)[0]       = pkt_addr;
  (g_icmp_txring_base + 8)(I64*)[0] = 42 | (0x0B << 24);
  (g_icmp_bar0 + 0x3818)(U32*)[0] = 1;   // TDT=1: kick ARP TX

  // Sleep(2000ms): flush_queue_timer fires (~1000ms), delivers ARP reply to desc 0
  Sleep(2000);

  // Poll descriptor 0 for ARP reply (should be immediate post-Sleep)
  i = 0;
  while(i < 500000) {
    sta0 = (g_icmp_rxring_base + 12)(U8*)[0];
    if (sta0 & 1) break;
    i++;
  }
  dd0 = sta0 & 1;

  // --- 1. arp_rxd: ARP reply received in descriptor 0 ---
  if (dd0 == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "arp_rxd\t%s\tsta=%02X iters=%d\n", s, sta0, i);
  CatPrint(buf, "%s", line);

  // Extract gateway MAC from ARP reply: sender MAC at rxbuf0[22..27]
  for (i = 0; i < 6; i++) g_icmp_gw_mac[i] = g_icmp_rxbuf0[22+i];

  // --- 2. gw_mac_valid: gateway MAC is non-zero ---
  sum = g_icmp_gw_mac[0] | g_icmp_gw_mac[1] | g_icmp_gw_mac[2] |
        g_icmp_gw_mac[3] | g_icmp_gw_mac[4] | g_icmp_gw_mac[5];
  if (sum != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "gw_mac_valid\t%s\t%02X:%02X:%02X:%02X:%02X:%02X\n", s,
    g_icmp_gw_mac[0], g_icmp_gw_mac[1], g_icmp_gw_mac[2],
    g_icmp_gw_mac[3], g_icmp_gw_mac[4], g_icmp_gw_mac[5]);
  CatPrint(buf, "%s", line);

  // ---- Build ICMP echo request (42 bytes total) ----
  // Ethernet: dst=gw_mac (discovered), src=52:54:00:12:34:56, type=0x0800
  for (i = 0; i < 6; i++) g_icmp_tx_pkt[i] = g_icmp_gw_mac[i];
  g_icmp_tx_pkt[6]=0x52; g_icmp_tx_pkt[7]=0x54; g_icmp_tx_pkt[8]=0x00;
  g_icmp_tx_pkt[9]=0x12; g_icmp_tx_pkt[10]=0x34; g_icmp_tx_pkt[11]=0x56;
  g_icmp_tx_pkt[12]=0x08; g_icmp_tx_pkt[13]=0x00;  // EtherType: IPv4

  // IP: version=4, IHL=5, proto=1 (ICMP), total_len=28, src=10.0.2.15, dst=10.0.2.2
  g_icmp_tx_pkt[14]=0x45;   // Version=4, IHL=5
  g_icmp_tx_pkt[15]=0x00;   // DSCP
  g_icmp_tx_pkt[16]=0x00;   // total_len = 28 = 0x001C
  g_icmp_tx_pkt[17]=0x1C;
  g_icmp_tx_pkt[18]=0x00;   // ID
  g_icmp_tx_pkt[19]=0x00;
  g_icmp_tx_pkt[20]=0x40;   // DF flag
  g_icmp_tx_pkt[21]=0x00;
  g_icmp_tx_pkt[22]=64;     // TTL
  g_icmp_tx_pkt[23]=1;      // Protocol: ICMP
  g_icmp_tx_pkt[24]=0x00;   // IP checksum (filled below)
  g_icmp_tx_pkt[25]=0x00;
  g_icmp_tx_pkt[26]=0x0A;   // src: 10.0.2.15
  g_icmp_tx_pkt[27]=0x00;
  g_icmp_tx_pkt[28]=0x02;
  g_icmp_tx_pkt[29]=0x0F;
  g_icmp_tx_pkt[30]=0x0A;   // dst: 10.0.2.2
  g_icmp_tx_pkt[31]=0x00;
  g_icmp_tx_pkt[32]=0x02;
  g_icmp_tx_pkt[33]=0x02;

  // ICMP: type=8 (echo req), code=0, cksum=computed, id=0x1234, seq=0x0001
  g_icmp_tx_pkt[34]=0x08;   // type: echo request
  g_icmp_tx_pkt[35]=0x00;   // code: 0
  g_icmp_tx_pkt[36]=0x00;   // checksum (filled below)
  g_icmp_tx_pkt[37]=0x00;
  g_icmp_tx_pkt[38]=0x12;   // identifier: 0x1234
  g_icmp_tx_pkt[39]=0x34;
  g_icmp_tx_pkt[40]=0x00;   // sequence: 0x0001
  g_icmp_tx_pkt[41]=0x01;

  // Compute ICMP checksum (8 bytes: type+code+cksum0+id+seq, cksum field = 0)
  sum = (0x0800)               // type=8, code=0
      + (0x0000)               // checksum field zeroed
      + (0x1234)               // id
      + (0x0001);              // seq
  while (sum >> 16) sum = (sum & 0xFFFF) + (sum >> 16);
  cksum = (~sum) & 0xFFFF;
  g_icmp_tx_pkt[36] = (cksum >> 8) & 0xFF;
  g_icmp_tx_pkt[37] =  cksum       & 0xFF;

  // Compute IP header checksum (bytes 14-33, cksum field already 0)
  sum = 0;
  for (i = 14; i < 34; i += 2)
    sum += (g_icmp_tx_pkt[i] << 8) | g_icmp_tx_pkt[i+1];
  while (sum >> 16) sum = (sum & 0xFFFF) + (sum >> 16);
  cksum = (~sum) & 0xFFFF;
  g_icmp_tx_pkt[24] = (cksum >> 8) & 0xFF;
  g_icmp_tx_pkt[25] =  cksum       & 0xFF;

  // Send ICMP echo request (TX descriptor 1: ring_base + 16)
  pkt_addr = &g_icmp_tx_pkt[0];
  (g_icmp_txring_base + 16)(I64*)[0] = pkt_addr;           // desc 1: buf addr
  (g_icmp_txring_base + 24)(I64*)[0] = 42 | (0x0B << 24);  // desc 1: len=42, CMD=0x0B
  (g_icmp_bar0 + 0x3818)(U32*)[0] = 2;   // TDT=2: kick ICMP TX
  // flush_queue_timer already fired → e1000_can_receive=TRUE →
  // ICMP reply delivered synchronously during this write

  // Poll descriptor 1 for ICMP reply (should be 0 iterations)
  i = 0;
  while(i < 500000) {
    sta1 = (g_icmp_rxring_base + 28)(U8*)[0];  // desc 1 status: base+16+12
    if (sta1 & 1) break;
    i++;
  }
  dd1 = sta1 & 1;

  // --- 3. icmp_rxd: ICMP echo reply received in descriptor 1 ---
  if (dd1 == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "icmp_rxd\t%s\tsta=%02X iters=%d\n", s, sta1, i);
  CatPrint(buf, "%s", line);

  // Parse received ICMP reply: rxbuf1[0..13]=Eth, [14..33]=IP, [34..]=ICMP
  icmp_type = g_icmp_rxbuf1[34];
  icmp_code = g_icmp_rxbuf1[35];
  icmp_id   = (g_icmp_rxbuf1[38] << 8) | g_icmp_rxbuf1[39];
  icmp_seq  = (g_icmp_rxbuf1[40] << 8) | g_icmp_rxbuf1[41];

  // --- 4. icmp_type0: type = 0 (echo reply) ---
  if (icmp_type == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "icmp_type0\t%s\ttype=%d\n", s, icmp_type);
  CatPrint(buf, "%s", line);

  // --- 5. icmp_code0: code = 0 ---
  if (icmp_code == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "icmp_code0\t%s\tcode=%d\n", s, icmp_code);
  CatPrint(buf, "%s", line);

  // --- 6. icmp_id_match: identifier echoed back = 0x1234 ---
  if (icmp_id == 0x1234) s = "PASS"; else s = "FAIL";
  StrPrint(line, "icmp_id_match\t%s\tid=%04X\n", s, icmp_id);
  CatPrint(buf, "%s", line);

  // --- 7. icmp_seq_match: sequence echoed back = 0x0001 ---
  if (icmp_seq == 0x0001) s = "PASS"; else s = "FAIL";
  StrPrint(line, "icmp_seq_match\t%s\tseq=%04X\n", s, icmp_seq);
  CatPrint(buf, "%s", line);

  // --- 8. icmp_cksum_valid: ones-complement sum of received ICMP message = 0 ---
  // Use IP total_len to get actual ICMP length (excludes padding/FCS)
  ip_total_len = (g_icmp_rxbuf1[16] << 8) | g_icmp_rxbuf1[17];
  icmp_len = ip_total_len - 20;    // subtract IP header
  sum = 0;
  for (i = 0; i < icmp_len; i += 2)
    sum += (g_icmp_rxbuf1[34+i] << 8) | g_icmp_rxbuf1[35+i];
  while (sum >> 16) sum = (sum & 0xFFFF) + (sum >> 16);
  icmp_ok = (~sum) & 0xFFFF;
  if (icmp_ok == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "icmp_cksum_valid\t%s\tverify=%04X ip_len=%d icmp_len=%d\n",
    s, icmp_ok, ip_total_len, icmp_len);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestICMP.txt", buf, StrLen(buf));
  Print("TestICMP done — 8 tests\n");
}

TestICMP;
