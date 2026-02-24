// TestDHCP.HC — Tier 7: DHCP discover/offer/request/ack via e1000 + QEMU SLiRP
// Flow: Discover (broadcast) → Offer → Request → Ack → verify assigned IP.
// KEY: Sleep(2000) after Discover TX lets flush_queue_timer fire for Offer.
//      Ack arrives synchronously on Request TX (timer already fired).
// Standalone only (NIC access).
// Results written to C:/AI/results/TestDHCP.txt

I64 g_dhcp_bar0;
I64 g_dhcp_txring_base;
I64 g_dhcp_txring[34];
I64 g_dhcp_rxring_base;
I64 g_dhcp_rxring[34];
U8  g_dhcp_tx0[400];     // DHCP Discover frame (~286 bytes)
U8  g_dhcp_tx1[400];     // DHCP Request frame (~298 bytes)
U8  g_dhcp_rxbuf0[2048]; // desc 0: DHCP Offer
U8  g_dhcp_rxbuf1[2048]; // desc 1: DHCP Ack

// IP header checksum (20-byte header, cksum field pre-zeroed).
I64 DhcpIPCksum(U8 *hdr) {
  I64 sum, i;
  sum = 0;
  for (i = 0; i < 20; i += 2)
    sum += (hdr[i] << 8) | hdr[i+1];
  while (sum >> 16)
    sum = (sum & 0xFFFF) + (sum >> 16);
  return (~sum) & 0xFFFF;
}

U0 TestDHCP() {
  U8 buf[4096];
  U8 line[128];
  U8 *s;
  I64 raw, tda, rda, i;
  I64 rxbuf0_addr, rxbuf1_addr, pkt_addr;
  I64 sta0, dd0, sta1, dd1;
  I64 cksum;
  I64 offer_xid;
  I64 offer_yiaddr0, offer_yiaddr1, offer_yiaddr2, offer_yiaddr3;
  I64 ack_yiaddr0, ack_yiaddr1, ack_yiaddr2, ack_yiaddr3;
  I64 server_id0, server_id1, server_id2, server_id3;
  I64 opt_t, opt_l;
  I64 opt_type_offer, opt_type_ack;

  buf[0] = 0;
  CatPrint(buf, "# TestDHCP\n");

  // ---- NIC init ----
  g_dhcp_bar0 = PCIReadU32(0, 3, 0, 0x10) & 0xFFFFFFF0;
  PCIWriteU16(0, 3, 0, 0x04, 0x0107);          // Bus Master
  (g_dhcp_bar0 + 0x0000)(U32*)[0] = 1 << 26;   // CTRL soft reset
  i = 0; while (i < 500000) { i++; }
  (g_dhcp_bar0 + 0x0000)(U32*)[0] = 0x241;     // SLU|FD

  // TX ring
  raw = &g_dhcp_txring[0];
  tda = (raw + 15) & ~15;
  g_dhcp_txring_base = tda;
  (g_dhcp_bar0 + 0x3800)(U32*)[0] = tda & 0xFFFFFFFF;
  (g_dhcp_bar0 + 0x3804)(U32*)[0] = 0;
  (g_dhcp_bar0 + 0x3808)(U32*)[0] = 256;
  (g_dhcp_bar0 + 0x3810)(U32*)[0] = 0;
  (g_dhcp_bar0 + 0x3818)(U32*)[0] = 0;
  (g_dhcp_bar0 + 0x0400)(U32*)[0] = 0x0A;      // TCTL: EN|PSP

  // RX ring (2 descriptors: 0=Offer, 1=Ack)
  raw = &g_dhcp_rxring[0];
  rda = (raw + 15) & ~15;
  g_dhcp_rxring_base = rda;
  (g_dhcp_bar0 + 0x2800)(U32*)[0] = rda & 0xFFFFFFFF;
  (g_dhcp_bar0 + 0x2804)(U32*)[0] = 0;
  (g_dhcp_bar0 + 0x2808)(U32*)[0] = 256;
  (g_dhcp_bar0 + 0x2810)(U32*)[0] = 0;
  (g_dhcp_bar0 + 0x2818)(U32*)[0] = 0;

  rxbuf0_addr = &g_dhcp_rxbuf0[0];
  rxbuf1_addr = &g_dhcp_rxbuf1[0];
  g_dhcp_rxring_base(I64*)[0]        = rxbuf0_addr;
  (g_dhcp_rxring_base +  8)(I64*)[0] = 0;
  (g_dhcp_rxring_base + 16)(I64*)[0] = rxbuf1_addr;
  (g_dhcp_rxring_base + 24)(I64*)[0] = 0;

  // Enable RX: EN|BAM. Arms flush_queue_timer(+1000ms virtual).
  (g_dhcp_bar0 + 0x0100)(U32*)[0] = 0x8002;
  (g_dhcp_bar0 + 0x2818)(U32*)[0] = 2;  // RDT=2: give descs 0+1 to HW

  // ---- Build DHCP Discover ----
  // Ethernet(14)+IP(20)+UDP(8)+DHCP(244) = 286 bytes total
  // DHCP(244) = fixed(236) + magic(4) + opt53(3) + end(1)
  // UDP len=252, IP total_len=272
  MemSet(g_dhcp_tx0, 0, 400);

  // Ethernet: broadcast dst, src=52:54:00:12:34:56, type=0x0800
  g_dhcp_tx0[0]=0xFF; g_dhcp_tx0[1]=0xFF; g_dhcp_tx0[2]=0xFF;
  g_dhcp_tx0[3]=0xFF; g_dhcp_tx0[4]=0xFF; g_dhcp_tx0[5]=0xFF;
  g_dhcp_tx0[6]=0x52; g_dhcp_tx0[7]=0x54; g_dhcp_tx0[8]=0x00;
  g_dhcp_tx0[9]=0x12; g_dhcp_tx0[10]=0x34; g_dhcp_tx0[11]=0x56;
  g_dhcp_tx0[12]=0x08; g_dhcp_tx0[13]=0x00;

  // IP: src=0.0.0.0, dst=255.255.255.255, proto=17, total_len=272=0x0110
  g_dhcp_tx0[14]=0x45;
  g_dhcp_tx0[15]=0x00;
  g_dhcp_tx0[16]=0x01; g_dhcp_tx0[17]=0x10;  // total_len=272
  g_dhcp_tx0[18]=0x00; g_dhcp_tx0[19]=0x00;  // ID=0
  g_dhcp_tx0[20]=0x00; g_dhcp_tx0[21]=0x00;  // no flags
  g_dhcp_tx0[22]=64;                          // TTL
  g_dhcp_tx0[23]=17;                          // proto=UDP
  g_dhcp_tx0[24]=0x00; g_dhcp_tx0[25]=0x00;  // cksum (filled below)
  // src: 0.0.0.0 (already zero from MemSet)
  g_dhcp_tx0[30]=0xFF; g_dhcp_tx0[31]=0xFF;  // dst: 255.255.255.255
  g_dhcp_tx0[32]=0xFF; g_dhcp_tx0[33]=0xFF;

  // UDP: src=68, dst=67, len=252=0x00FC, cksum=0 (optional per RFC 768)
  g_dhcp_tx0[34]=0x00; g_dhcp_tx0[35]=0x44;  // src_port=68
  g_dhcp_tx0[36]=0x00; g_dhcp_tx0[37]=0x43;  // dst_port=67
  g_dhcp_tx0[38]=0x00; g_dhcp_tx0[39]=0xFC;  // udp_len=252
  // cksum=0: already zero

  // DHCP payload starts at byte 42
  g_dhcp_tx0[42]=0x01;  // op=BOOTREQUEST
  g_dhcp_tx0[43]=0x01;  // htype=Ethernet
  g_dhcp_tx0[44]=0x06;  // hlen=6
  // hops, secs, ciaddr, yiaddr, siaddr, giaddr = 0
  g_dhcp_tx0[46]=0x12; g_dhcp_tx0[47]=0x34;  // xid=0x12345678
  g_dhcp_tx0[48]=0x56; g_dhcp_tx0[49]=0x78;
  g_dhcp_tx0[52]=0x80; g_dhcp_tx0[53]=0x00;  // flags=0x8000 (broadcast)
  // chaddr at DHCP+28 = byte 70
  g_dhcp_tx0[70]=0x52; g_dhcp_tx0[71]=0x54; g_dhcp_tx0[72]=0x00;
  g_dhcp_tx0[73]=0x12; g_dhcp_tx0[74]=0x34; g_dhcp_tx0[75]=0x56;
  // sname[64] at byte 86, file[128] at byte 150: already zero
  // magic cookie at DHCP+236 = byte 278
  g_dhcp_tx0[278]=0x63; g_dhcp_tx0[279]=0x82;
  g_dhcp_tx0[280]=0x53; g_dhcp_tx0[281]=0x63;
  // options start at byte 282
  g_dhcp_tx0[282]=53; g_dhcp_tx0[283]=1; g_dhcp_tx0[284]=1;  // type=Discover
  g_dhcp_tx0[285]=0xFF;                                        // end

  // Compute and store IP checksum
  cksum = DhcpIPCksum(&g_dhcp_tx0[14]);
  g_dhcp_tx0[24] = (cksum >> 8) & 0xFF;
  g_dhcp_tx0[25] =  cksum       & 0xFF;

  // TX desc 0: DHCP Discover (286 bytes)
  pkt_addr = &g_dhcp_tx0[0];
  g_dhcp_txring_base(I64*)[0]       = pkt_addr;
  (g_dhcp_txring_base + 8)(I64*)[0] = 286 | (0x0B << 24);
  (g_dhcp_bar0 + 0x3818)(U32*)[0] = 1;  // TDT=1: kick Discover TX

  // Sleep(2000): flush_queue_timer fires, delivers DHCP Offer to desc 0
  Sleep(2000);

  // Poll desc 0 for DHCP Offer
  i = 0;
  while (i < 500000) {
    sta0 = (g_dhcp_rxring_base + 12)(U8*)[0];
    if (sta0 & 1) break;
    i++;
  }
  dd0 = sta0 & 1;

  // --- 1. offer_rxd: DHCP Offer received ---
  if (dd0 == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "offer_rxd\t%s\tsta=%02X iters=%d\n", s, sta0, i);
  CatPrint(buf, "%s", line);

  // Parse DHCP Offer from rxbuf0:
  //   Eth(14)+IP(20)+UDP(8) = 42 bytes before DHCP payload
  //   xid  at DHCP+4  = rxbuf0[46]
  //   yiaddr at DHCP+16 = rxbuf0[58]
  //   magic at DHCP+236 = rxbuf0[278]
  //   options at rxbuf0[282]
  offer_xid = (g_dhcp_rxbuf0[46] << 24) | (g_dhcp_rxbuf0[47] << 16) |
              (g_dhcp_rxbuf0[48] <<  8) |  g_dhcp_rxbuf0[49];
  offer_yiaddr0 = g_dhcp_rxbuf0[58];
  offer_yiaddr1 = g_dhcp_rxbuf0[59];
  offer_yiaddr2 = g_dhcp_rxbuf0[60];
  offer_yiaddr3 = g_dhcp_rxbuf0[61];

  opt_type_offer = 0;
  server_id0 = 0; server_id1 = 0; server_id2 = 0; server_id3 = 0;
  i = 282;
  while (i < 512) {
    opt_t = g_dhcp_rxbuf0[i];
    if (opt_t == 255) break;
    if (opt_t != 0) {
      opt_l = g_dhcp_rxbuf0[i+1];
      if (opt_t == 53 && opt_l == 1)  opt_type_offer = g_dhcp_rxbuf0[i+2];
      if (opt_t == 54 && opt_l == 4) {
        server_id0 = g_dhcp_rxbuf0[i+2];
        server_id1 = g_dhcp_rxbuf0[i+3];
        server_id2 = g_dhcp_rxbuf0[i+4];
        server_id3 = g_dhcp_rxbuf0[i+5];
      }
      i += 2 + opt_l;
    } else {
      i++;
    }
  }

  // --- 2. offer_type: option 53 = 2 (DHCP Offer) ---
  if (opt_type_offer == 2) s = "PASS"; else s = "FAIL";
  StrPrint(line, "offer_type\t%s\ttype=%d\n", s, opt_type_offer);
  CatPrint(buf, "%s", line);

  // --- 3. yiaddr_nonzero: offered IP is not 0.0.0.0 ---
  if ((offer_yiaddr0 | offer_yiaddr1 | offer_yiaddr2 | offer_yiaddr3) != 0)
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "yiaddr_nonzero\t%s\t%d.%d.%d.%d\n", s,
    offer_yiaddr0, offer_yiaddr1, offer_yiaddr2, offer_yiaddr3);
  CatPrint(buf, "%s", line);

  // --- 4. yiaddr_net: first octet = 10 (10.0.2.x range) ---
  if (offer_yiaddr0 == 10) s = "PASS"; else s = "FAIL";
  StrPrint(line, "yiaddr_net\t%s\t%d.%d.%d.%d\n", s,
    offer_yiaddr0, offer_yiaddr1, offer_yiaddr2, offer_yiaddr3);
  CatPrint(buf, "%s", line);

  // --- 5. xid_match: xid in Offer matches our xid ---
  if (offer_xid == 0x12345678) s = "PASS"; else s = "FAIL";
  StrPrint(line, "xid_match\t%s\txid=%08X\n", s, offer_xid);
  CatPrint(buf, "%s", line);

  // ---- Build DHCP Request ----
  // Ethernet(14)+IP(20)+UDP(8)+DHCP(256) = 298 bytes
  // DHCP(256) = fixed(236) + magic(4) + opt53(3) + opt50(6) + opt54(6) + end(1)
  // UDP len=264=0x0108, IP total_len=284=0x011C
  MemSet(g_dhcp_tx1, 0, 400);

  // Ethernet: broadcast dst, same src
  g_dhcp_tx1[0]=0xFF; g_dhcp_tx1[1]=0xFF; g_dhcp_tx1[2]=0xFF;
  g_dhcp_tx1[3]=0xFF; g_dhcp_tx1[4]=0xFF; g_dhcp_tx1[5]=0xFF;
  g_dhcp_tx1[6]=0x52; g_dhcp_tx1[7]=0x54; g_dhcp_tx1[8]=0x00;
  g_dhcp_tx1[9]=0x12; g_dhcp_tx1[10]=0x34; g_dhcp_tx1[11]=0x56;
  g_dhcp_tx1[12]=0x08; g_dhcp_tx1[13]=0x00;

  // IP: src=0.0.0.0, dst=255.255.255.255, total_len=284=0x011C
  g_dhcp_tx1[14]=0x45;
  g_dhcp_tx1[15]=0x00;
  g_dhcp_tx1[16]=0x01; g_dhcp_tx1[17]=0x1C;
  g_dhcp_tx1[18]=0x00; g_dhcp_tx1[19]=0x00;
  g_dhcp_tx1[20]=0x00; g_dhcp_tx1[21]=0x00;
  g_dhcp_tx1[22]=64;
  g_dhcp_tx1[23]=17;
  g_dhcp_tx1[24]=0x00; g_dhcp_tx1[25]=0x00;  // cksum (filled below)
  // src: 0.0.0.0 (already zero)
  g_dhcp_tx1[30]=0xFF; g_dhcp_tx1[31]=0xFF;
  g_dhcp_tx1[32]=0xFF; g_dhcp_tx1[33]=0xFF;

  // UDP: src=68, dst=67, len=264=0x0108, cksum=0
  g_dhcp_tx1[34]=0x00; g_dhcp_tx1[35]=0x44;
  g_dhcp_tx1[36]=0x00; g_dhcp_tx1[37]=0x43;
  g_dhcp_tx1[38]=0x01; g_dhcp_tx1[39]=0x08;

  // DHCP
  g_dhcp_tx1[42]=0x01; g_dhcp_tx1[43]=0x01; g_dhcp_tx1[44]=0x06;
  g_dhcp_tx1[46]=0x12; g_dhcp_tx1[47]=0x34;  // xid
  g_dhcp_tx1[48]=0x56; g_dhcp_tx1[49]=0x78;
  g_dhcp_tx1[52]=0x80; g_dhcp_tx1[53]=0x00;  // flags=broadcast
  // chaddr
  g_dhcp_tx1[70]=0x52; g_dhcp_tx1[71]=0x54; g_dhcp_tx1[72]=0x00;
  g_dhcp_tx1[73]=0x12; g_dhcp_tx1[74]=0x34; g_dhcp_tx1[75]=0x56;
  // magic cookie
  g_dhcp_tx1[278]=0x63; g_dhcp_tx1[279]=0x82;
  g_dhcp_tx1[280]=0x53; g_dhcp_tx1[281]=0x63;
  // opt 53: DHCP Request (3)
  g_dhcp_tx1[282]=53; g_dhcp_tx1[283]=1; g_dhcp_tx1[284]=3;
  // opt 50: requested IP (from offer)
  g_dhcp_tx1[285]=50; g_dhcp_tx1[286]=4;
  g_dhcp_tx1[287]=offer_yiaddr0; g_dhcp_tx1[288]=offer_yiaddr1;
  g_dhcp_tx1[289]=offer_yiaddr2; g_dhcp_tx1[290]=offer_yiaddr3;
  // opt 54: server identifier (from offer)
  g_dhcp_tx1[291]=54; g_dhcp_tx1[292]=4;
  g_dhcp_tx1[293]=server_id0; g_dhcp_tx1[294]=server_id1;
  g_dhcp_tx1[295]=server_id2; g_dhcp_tx1[296]=server_id3;
  // end
  g_dhcp_tx1[297]=0xFF;

  // IP checksum
  cksum = DhcpIPCksum(&g_dhcp_tx1[14]);
  g_dhcp_tx1[24] = (cksum >> 8) & 0xFF;
  g_dhcp_tx1[25] =  cksum       & 0xFF;

  // TX desc 1: DHCP Request (298 bytes)
  // flush_queue_timer already fired → Ack delivered synchronously
  pkt_addr = &g_dhcp_tx1[0];
  (g_dhcp_txring_base + 16)(I64*)[0] = pkt_addr;
  (g_dhcp_txring_base + 24)(I64*)[0] = 298 | (0x0B << 24);
  (g_dhcp_bar0 + 0x3818)(U32*)[0] = 2;  // TDT=2: kick Request TX

  // Poll desc 1 for DHCP Ack (synchronous, iters should be ~0)
  i = 0;
  while (i < 500000) {
    sta1 = (g_dhcp_rxring_base + 28)(U8*)[0];
    if (sta1 & 1) break;
    i++;
  }
  dd1 = sta1 & 1;

  // --- 6. ack_rxd: DHCP Ack received ---
  if (dd1 == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ack_rxd\t%s\tsta=%02X iters=%d\n", s, sta1, i);
  CatPrint(buf, "%s", line);

  // Parse DHCP Ack: yiaddr + option 53
  ack_yiaddr0 = g_dhcp_rxbuf1[58];
  ack_yiaddr1 = g_dhcp_rxbuf1[59];
  ack_yiaddr2 = g_dhcp_rxbuf1[60];
  ack_yiaddr3 = g_dhcp_rxbuf1[61];

  opt_type_ack = 0;
  i = 282;
  while (i < 512) {
    opt_t = g_dhcp_rxbuf1[i];
    if (opt_t == 255) break;
    if (opt_t != 0) {
      opt_l = g_dhcp_rxbuf1[i+1];
      if (opt_t == 53 && opt_l == 1) opt_type_ack = g_dhcp_rxbuf1[i+2];
      i += 2 + opt_l;
    } else {
      i++;
    }
  }

  // --- 7. ack_type: option 53 = 5 (DHCP Ack) ---
  if (opt_type_ack == 5) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ack_type\t%s\ttype=%d\n", s, opt_type_ack);
  CatPrint(buf, "%s", line);

  // --- 8. ack_ip_match: Ack yiaddr matches Offer yiaddr ---
  if (ack_yiaddr0 == offer_yiaddr0 && ack_yiaddr1 == offer_yiaddr1 &&
      ack_yiaddr2 == offer_yiaddr2 && ack_yiaddr3 == offer_yiaddr3)
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "ack_ip_match\t%s\t%d.%d.%d.%d\n", s,
    ack_yiaddr0, ack_yiaddr1, ack_yiaddr2, ack_yiaddr3);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestDHCP.txt", buf, StrLen(buf));
  Print("TestDHCP done — 8 tests\n");
}

TestDHCP;
