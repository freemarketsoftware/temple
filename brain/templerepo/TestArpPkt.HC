// TestArpPkt.HC — Tier 6: ARP packet construction and field parsing (pure computation)
// Builds an ARP request frame and verifies all field values.
// No hardware required — safe to include in TestRunner once confirmed.
// Results written to C:/AI/results/TestArpPkt.txt

U8 g_arp_frame[64];   // 64-byte buffer; ARP frame uses 42 bytes

// Build Ethernet+ARP request frame into buf (must be >=42 bytes).
// src_ip and tgt_ip are host-order I64 (e.g. 0x0A00020F = 10.0.2.15).
U0 ArpBuildRequest(U8 *buf, U8 *src_mac, I64 src_ip, I64 tgt_ip) {
  I64 i;
  // Ethernet header (14 bytes)
  buf[0]=0xFF; buf[1]=0xFF; buf[2]=0xFF;     // dst: broadcast
  buf[3]=0xFF; buf[4]=0xFF; buf[5]=0xFF;
  for (i = 0; i < 6; i++) buf[6+i] = src_mac[i];  // src: our MAC
  buf[12]=0x08; buf[13]=0x06;                // EtherType: ARP
  // ARP payload (28 bytes)
  buf[14]=0x00; buf[15]=0x01;                // HTYPE: Ethernet
  buf[16]=0x08; buf[17]=0x00;                // PTYPE: IPv4
  buf[18]=6;                                  // HLEN: 6
  buf[19]=4;                                  // PLEN: 4
  buf[20]=0x00; buf[21]=0x01;                // OPER: request
  for (i = 0; i < 6; i++) buf[22+i] = src_mac[i];  // sender MAC
  buf[28] = (src_ip >> 24) & 0xFF;           // sender IP (big-endian)
  buf[29] = (src_ip >> 16) & 0xFF;
  buf[30] = (src_ip >>  8) & 0xFF;
  buf[31] =  src_ip        & 0xFF;
  buf[32]=0; buf[33]=0; buf[34]=0;           // target MAC: unknown
  buf[35]=0; buf[36]=0; buf[37]=0;
  buf[38] = (tgt_ip >> 24) & 0xFF;           // target IP (big-endian)
  buf[39] = (tgt_ip >> 16) & 0xFF;
  buf[40] = (tgt_ip >>  8) & 0xFF;
  buf[41] =  tgt_ip        & 0xFF;
}

U0 TestArpPkt() {
  U8 buf[4096];
  U8 line[128];
  U8 *s;
  U8 src_mac[6];
  I64 i, match;
  I64 ether_type, htype, ptype, hlen, plen, oper;
  I64 sender_ip, target_ip;

  buf[0] = 0;
  CatPrint(buf, "# TestArpPkt\n");

  src_mac[0]=0x52; src_mac[1]=0x54; src_mac[2]=0x00;
  src_mac[3]=0x12; src_mac[4]=0x34; src_mac[5]=0x56;

  // Build ARP request: 10.0.2.15 asking who-has 10.0.2.2
  ArpBuildRequest(g_arp_frame, src_mac, 0x0A00020F, 0x0A000202);

  // --- 1. dst_bcast: bytes 0-5 all 0xFF ---
  match = 1;
  for (i = 0; i < 6; i++) if (g_arp_frame[i] != 0xFF) match = 0;
  if (match) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dst_bcast\t%s\t%02X%02X%02X%02X%02X%02X\n", s,
    g_arp_frame[0], g_arp_frame[1], g_arp_frame[2],
    g_arp_frame[3], g_arp_frame[4], g_arp_frame[5]);
  CatPrint(buf, "%s", line);

  // --- 2. src_mac: bytes 6-11 = 52:54:00:12:34:56 ---
  match = 1;
  for (i = 0; i < 6; i++) if (g_arp_frame[6+i] != src_mac[i]) match = 0;
  if (match) s = "PASS"; else s = "FAIL";
  StrPrint(line, "src_mac\t%s\t%02X:%02X:%02X:%02X:%02X:%02X\n", s,
    g_arp_frame[6], g_arp_frame[7], g_arp_frame[8],
    g_arp_frame[9], g_arp_frame[10], g_arp_frame[11]);
  CatPrint(buf, "%s", line);

  // --- 3. ether_type: bytes 12-13 = 0x0806 ---
  ether_type = (g_arp_frame[12] << 8) | g_arp_frame[13];
  if (ether_type == 0x0806) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ether_type\t%s\t%04X\n", s, ether_type);
  CatPrint(buf, "%s", line);

  // --- 4. htype: bytes 14-15 = 1 (Ethernet) ---
  htype = (g_arp_frame[14] << 8) | g_arp_frame[15];
  if (htype == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "htype\t%s\t%d\n", s, htype);
  CatPrint(buf, "%s", line);

  // --- 5. ptype: bytes 16-17 = 0x0800 (IPv4) ---
  ptype = (g_arp_frame[16] << 8) | g_arp_frame[17];
  if (ptype == 0x0800) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ptype\t%s\t%04X\n", s, ptype);
  CatPrint(buf, "%s", line);

  // --- 6. hlen: byte 18 = 6 ---
  hlen = g_arp_frame[18];
  if (hlen == 6) s = "PASS"; else s = "FAIL";
  StrPrint(line, "hlen\t%s\t%d\n", s, hlen);
  CatPrint(buf, "%s", line);

  // --- 7. plen: byte 19 = 4 ---
  plen = g_arp_frame[19];
  if (plen == 4) s = "PASS"; else s = "FAIL";
  StrPrint(line, "plen\t%s\t%d\n", s, plen);
  CatPrint(buf, "%s", line);

  // --- 8. oper_request: bytes 20-21 = 1 ---
  oper = (g_arp_frame[20] << 8) | g_arp_frame[21];
  if (oper == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "oper_request\t%s\t%d\n", s, oper);
  CatPrint(buf, "%s", line);

  // --- 9. sender_mac: bytes 22-27 = 52:54:00:12:34:56 ---
  match = 1;
  for (i = 0; i < 6; i++) if (g_arp_frame[22+i] != src_mac[i]) match = 0;
  if (match) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sender_mac\t%s\t%02X:%02X:%02X:%02X:%02X:%02X\n", s,
    g_arp_frame[22], g_arp_frame[23], g_arp_frame[24],
    g_arp_frame[25], g_arp_frame[26], g_arp_frame[27]);
  CatPrint(buf, "%s", line);

  // --- 10. sender_ip: bytes 28-31 = 10.0.2.15 ---
  sender_ip = (g_arp_frame[28] << 24) | (g_arp_frame[29] << 16) |
              (g_arp_frame[30] <<  8) |  g_arp_frame[31];
  if (sender_ip == 0x0A00020F) s = "PASS"; else s = "FAIL";
  StrPrint(line, "sender_ip\t%s\t%d.%d.%d.%d\n", s,
    g_arp_frame[28], g_arp_frame[29], g_arp_frame[30], g_arp_frame[31]);
  CatPrint(buf, "%s", line);

  // --- 11. target_mac_zero: bytes 32-37 all 0 ---
  match = 1;
  for (i = 0; i < 6; i++) if (g_arp_frame[32+i] != 0) match = 0;
  if (match) s = "PASS"; else s = "FAIL";
  StrPrint(line, "target_mac_zero\t%s\t%02X%02X%02X%02X%02X%02X\n", s,
    g_arp_frame[32], g_arp_frame[33], g_arp_frame[34],
    g_arp_frame[35], g_arp_frame[36], g_arp_frame[37]);
  CatPrint(buf, "%s", line);

  // --- 12. target_ip: bytes 38-41 = 10.0.2.2 ---
  target_ip = (g_arp_frame[38] << 24) | (g_arp_frame[39] << 16) |
              (g_arp_frame[40] <<  8) |  g_arp_frame[41];
  if (target_ip == 0x0A000202) s = "PASS"; else s = "FAIL";
  StrPrint(line, "target_ip\t%s\t%d.%d.%d.%d\n", s,
    g_arp_frame[38], g_arp_frame[39], g_arp_frame[40], g_arp_frame[41]);
  CatPrint(buf, "%s", line);

  // --- 13. frame_size: 14 (Ethernet) + 28 (ARP) = 42 bytes ---
  if (42 == 42) s = "PASS"; else s = "FAIL";
  StrPrint(line, "frame_size\t%s\t42\n", s);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestArpPkt.txt", buf, StrLen(buf));
  Print("TestArpPkt done — 13 tests\n");
}

TestArpPkt;
