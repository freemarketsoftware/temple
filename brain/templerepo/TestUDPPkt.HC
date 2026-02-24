// TestUDPPkt.HC — Tier 6: UDP header construction + checksum (pure computation)
// Builds Ethernet+IP+UDP frame, verifies UDP header fields and checksum.
// UDP checksum uses pseudo-header (RFC 768): src_ip|dst_ip|0|17|udp_len.
// No hardware required — pure computation.
// Results written to C:/AI/results/TestUDPPkt.txt

U8  g_udp_frame[64];   // Eth(14)+IP(20)+UDP(8)+data(4) = 46 bytes used
U8  g_udp_pseudo[12];  // pseudo-header for UDP checksum

// Ones-complement sum over len bytes (len may be odd; pads last byte with 0).
// Returns the partial 32-bit accumulator (carry not yet folded).
I64 OnesAcc(U8 *data, I64 len) {
  I64 sum = 0, i;
  for (i = 0; i + 1 < len; i += 2)
    sum += (data[i] << 8) | data[i+1];
  if (len & 1)
    sum += data[len-1] << 8;
  return sum;
}

// Fold 32-bit accumulator to 16 bits and ones-complement.
I64 OnesFinish(I64 sum) {
  while (sum >> 16)
    sum = (sum & 0xFFFF) + (sum >> 16);
  return (~sum) & 0xFFFF;
}

// IPv4 header checksum (header must be 20 bytes, cksum field pre-zeroed).
I64 IPv4Cksum(U8 *hdr) {
  return OnesFinish(OnesAcc(hdr, 20));
}

// UDP checksum using pre-built pseudo-header in g_udp_pseudo.
I64 UDPCksum(U8 *udp, I64 udp_len) {
  I64 sum;
  sum = OnesAcc(g_udp_pseudo, 12) + OnesAcc(udp, udp_len);
  while (sum >> 16)
    sum = (sum & 0xFFFF) + (sum >> 16);
  return (~sum) & 0xFFFF;
}

U0 TestUDPPkt() {
  U8 buf[4096];
  U8 line[128];
  U8 *udp;
  U8 *s;
  I64 src_port, dst_port, udp_len, cksum_raw, cksum_verify;
  I64 data_word, et;

  buf[0] = 0;
  CatPrint(buf, "# TestUDPPkt\n");

  // ---- Build Ethernet+IP+UDP with 4-byte payload "PING" ----
  // IP: src=10.0.2.15, dst=10.0.2.2, proto=17, total_len=32 (20+8+4)

  // Ethernet header (bytes 0-13)
  g_udp_frame[0]=0xFF; g_udp_frame[1]=0xFF; g_udp_frame[2]=0xFF;
  g_udp_frame[3]=0xFF; g_udp_frame[4]=0xFF; g_udp_frame[5]=0xFF;
  g_udp_frame[6]=0x52; g_udp_frame[7]=0x54; g_udp_frame[8]=0x00;
  g_udp_frame[9]=0x12; g_udp_frame[10]=0x34; g_udp_frame[11]=0x56;
  g_udp_frame[12]=0x08; g_udp_frame[13]=0x00;  // EtherType: IPv4

  // IP header (bytes 14-33)
  g_udp_frame[14]=0x45;   // Version=4, IHL=5
  g_udp_frame[15]=0x00;   // DSCP
  g_udp_frame[16]=0x00;   // Total length: 32 = 0x0020
  g_udp_frame[17]=0x20;
  g_udp_frame[18]=0x00;   // ID
  g_udp_frame[19]=0x00;
  g_udp_frame[20]=0x40;   // DF flag
  g_udp_frame[21]=0x00;
  g_udp_frame[22]=64;     // TTL
  g_udp_frame[23]=17;     // Protocol: UDP
  g_udp_frame[24]=0x00;   // IP checksum (filled below)
  g_udp_frame[25]=0x00;
  g_udp_frame[26]=0x0A;   // src: 10.0.2.15
  g_udp_frame[27]=0x00;
  g_udp_frame[28]=0x02;
  g_udp_frame[29]=0x0F;
  g_udp_frame[30]=0x0A;   // dst: 10.0.2.2
  g_udp_frame[31]=0x00;
  g_udp_frame[32]=0x02;
  g_udp_frame[33]=0x02;

  // UDP header (bytes 34-41): src_port=1234, dst_port=5678, len=12 (8+4)
  g_udp_frame[34]=0x04;   // src port: 1234 = 0x04D2
  g_udp_frame[35]=0xD2;
  g_udp_frame[36]=0x16;   // dst port: 5678 = 0x162E
  g_udp_frame[37]=0x2E;
  g_udp_frame[38]=0x00;   // length: 12
  g_udp_frame[39]=0x0C;
  g_udp_frame[40]=0x00;   // checksum (filled below)
  g_udp_frame[41]=0x00;

  // Payload (bytes 42-45): "PING"
  g_udp_frame[42]=0x50;   // 'P'
  g_udp_frame[43]=0x49;   // 'I'
  g_udp_frame[44]=0x4E;   // 'N'
  g_udp_frame[45]=0x47;   // 'G'

  // Build UDP pseudo-header: src_ip | dst_ip | 0 | proto=17 | udp_len=12
  g_udp_pseudo[0]=0x0A; g_udp_pseudo[1]=0x00;   // src IP: 10.0.2.15
  g_udp_pseudo[2]=0x02; g_udp_pseudo[3]=0x0F;
  g_udp_pseudo[4]=0x0A; g_udp_pseudo[5]=0x00;   // dst IP: 10.0.2.2
  g_udp_pseudo[6]=0x02; g_udp_pseudo[7]=0x02;
  g_udp_pseudo[8]=0x00;                          // reserved
  g_udp_pseudo[9]=17;                            // protocol: UDP
  g_udp_pseudo[10]=0x00;                         // UDP length: 12
  g_udp_pseudo[11]=0x0C;

  // Compute and store UDP checksum
  udp = &g_udp_frame[34];
  cksum_raw = UDPCksum(udp, 12);
  g_udp_frame[40] = (cksum_raw >> 8) & 0xFF;
  g_udp_frame[41] =  cksum_raw       & 0xFF;

  // Compute and store IP checksum (over bytes 14-33)
  cksum_raw = IPv4Cksum(&g_udp_frame[14]);
  g_udp_frame[24] = (cksum_raw >> 8) & 0xFF;
  g_udp_frame[25] =  cksum_raw       & 0xFF;

  udp = &g_udp_frame[34];

  // --- 1. src_port: UDP bytes 0-1 = 1234 ---
  src_port = (udp[0] << 8) | udp[1];
  if (src_port == 1234) s = "PASS"; else s = "FAIL";
  StrPrint(line, "src_port\t%s\t%d\n", s, src_port);
  CatPrint(buf, "%s", line);

  // --- 2. dst_port: UDP bytes 2-3 = 5678 ---
  dst_port = (udp[2] << 8) | udp[3];
  if (dst_port == 5678) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dst_port\t%s\t%d\n", s, dst_port);
  CatPrint(buf, "%s", line);

  // --- 3. udp_len: UDP bytes 4-5 = 12 (8 header + 4 payload) ---
  udp_len = (udp[4] << 8) | udp[5];
  if (udp_len == 12) s = "PASS"; else s = "FAIL";
  StrPrint(line, "udp_len\t%s\t%d\n", s, udp_len);
  CatPrint(buf, "%s", line);

  // --- 4. cksum_nonzero: UDP checksum != 0 ---
  cksum_raw = (udp[6] << 8) | udp[7];
  if (cksum_raw != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "cksum_nonzero\t%s\t%04X\n", s, cksum_raw);
  CatPrint(buf, "%s", line);

  // --- 5. cksum_valid: re-verify UDP checksum = 0 ---
  cksum_verify = UDPCksum(udp, 12);
  if (cksum_verify == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "cksum_valid\t%s\tverify=%04X\n", s, cksum_verify);
  CatPrint(buf, "%s", line);

  // --- 6. payload: bytes 42-45 = "PING" ---
  data_word = (g_udp_frame[42] << 24) | (g_udp_frame[43] << 16) |
              (g_udp_frame[44] <<  8) |  g_udp_frame[45];
  if (data_word == 0x50494E47) s = "PASS"; else s = "FAIL";
  StrPrint(line, "payload\t%s\t%c%c%c%c\n", s,
    g_udp_frame[42], g_udp_frame[43], g_udp_frame[44], g_udp_frame[45]);
  CatPrint(buf, "%s", line);

  // --- 7. ip_cksum_valid: verify IP header checksum = 0 ---
  cksum_verify = IPv4Cksum(&g_udp_frame[14]);
  if (cksum_verify == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ip_cksum_valid\t%s\tverify=%04X\n", s, cksum_verify);
  CatPrint(buf, "%s", line);

  // --- 8. ether_type_ipv4: bytes 12-13 = 0x0800 ---
  et = (g_udp_frame[12] << 8) | g_udp_frame[13];
  if (et == 0x0800) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ether_type_ipv4\t%s\t%04X\n", s, et);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestUDPPkt.txt", buf, StrLen(buf));
  Print("TestUDPPkt done — 8 tests\n");
}

TestUDPPkt;
