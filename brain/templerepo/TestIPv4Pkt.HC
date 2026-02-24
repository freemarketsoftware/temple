// TestIPv4Pkt.HC — Tier 6: IPv4 header construction + ones-complement checksum
// Builds a 20-byte IPv4 header, verifies all fields and checksum.
// No hardware required — pure computation.
// Results written to C:/AI/results/TestIPv4Pkt.txt

U8 g_ip_hdr[20];   // 20-byte IPv4 header (no options)

// Ones-complement checksum over len bytes.
// len must be even. With checksum field zeroed: returns value to store.
// With checksum field filled: returns 0 if valid.
I64 IPv4Cksum(U8 *hdr, I64 len) {
  I64 sum = 0, i;
  for (i = 0; i < len; i += 2)
    sum += (hdr[i] << 8) | hdr[i+1];
  while (sum >> 16)
    sum = (sum & 0xFFFF) + (sum >> 16);
  return (~sum) & 0xFFFF;
}

// Build minimal IPv4 header (20 bytes, no options).
// proto: 17=UDP, 1=ICMP.  total_len includes IP header + payload.
// src_ip / dst_ip: host-order I64 (0x0A00020F = 10.0.2.15).
U0 IPv4Build(U8 *hdr, I64 proto, I64 total_len, I64 src_ip, I64 dst_ip) {
  I64 cksum;
  hdr[0]  = 0x45;                     // Version=4, IHL=5 (20 bytes)
  hdr[1]  = 0x00;                     // DSCP/ECN
  hdr[2]  = (total_len >> 8) & 0xFF;  // Total length (big-endian)
  hdr[3]  =  total_len       & 0xFF;
  hdr[4]  = 0x00;                     // Identification (0 for simplicity)
  hdr[5]  = 0x00;
  hdr[6]  = 0x40;                     // Flags: DF (don't fragment), frag offset=0
  hdr[7]  = 0x00;
  hdr[8]  = 64;                       // TTL
  hdr[9]  = proto & 0xFF;             // Protocol
  hdr[10] = 0x00;                     // Checksum high (zeroed for computation)
  hdr[11] = 0x00;                     // Checksum low
  hdr[12] = (src_ip >> 24) & 0xFF;   // Source IP (big-endian)
  hdr[13] = (src_ip >> 16) & 0xFF;
  hdr[14] = (src_ip >>  8) & 0xFF;
  hdr[15] =  src_ip        & 0xFF;
  hdr[16] = (dst_ip >> 24) & 0xFF;   // Destination IP (big-endian)
  hdr[17] = (dst_ip >> 16) & 0xFF;
  hdr[18] = (dst_ip >>  8) & 0xFF;
  hdr[19] =  dst_ip        & 0xFF;
  // Compute and insert checksum
  cksum = IPv4Cksum(hdr, 20);
  hdr[10] = (cksum >> 8) & 0xFF;
  hdr[11] =  cksum       & 0xFF;
}

U0 TestIPv4Pkt() {
  U8 buf[4096];
  U8 line[128];
  U8 *s;
  I64 version, ihl, df_flag, ttl, proto;
  I64 total_len, src_ip, dst_ip;
  I64 cksum_raw, cksum_verify;

  buf[0] = 0;
  CatPrint(buf, "# TestIPv4Pkt\n");

  // Build IP header: UDP (17), total_len=28 (20+8), src=10.0.2.15, dst=10.0.2.2
  IPv4Build(g_ip_hdr, 17, 28, 0x0A00020F, 0x0A000202);

  // --- 1. version: bits 7:4 of byte 0 = 4 ---
  version = (g_ip_hdr[0] >> 4) & 0xF;
  if (version == 4) s = "PASS"; else s = "FAIL";
  StrPrint(line, "version\t%s\t%d\n", s, version);
  CatPrint(buf, "%s", line);

  // --- 2. ihl: bits 3:0 of byte 0 = 5 (20 bytes) ---
  ihl = g_ip_hdr[0] & 0xF;
  if (ihl == 5) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ihl\t%s\t%d\n", s, ihl);
  CatPrint(buf, "%s", line);

  // --- 3. total_len: bytes 2-3 = 28 ---
  total_len = (g_ip_hdr[2] << 8) | g_ip_hdr[3];
  if (total_len == 28) s = "PASS"; else s = "FAIL";
  StrPrint(line, "total_len\t%s\t%d\n", s, total_len);
  CatPrint(buf, "%s", line);

  // --- 4. df_flag: bit 6 of byte 6 = 1 (don't fragment) ---
  df_flag = (g_ip_hdr[6] >> 6) & 1;
  if (df_flag == 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "df_flag\t%s\t%d\n", s, df_flag);
  CatPrint(buf, "%s", line);

  // --- 5. ttl: byte 8 = 64 ---
  ttl = g_ip_hdr[8];
  if (ttl == 64) s = "PASS"; else s = "FAIL";
  StrPrint(line, "ttl\t%s\t%d\n", s, ttl);
  CatPrint(buf, "%s", line);

  // --- 6. protocol: byte 9 = 17 (UDP) ---
  proto = g_ip_hdr[9];
  if (proto == 17) s = "PASS"; else s = "FAIL";
  StrPrint(line, "protocol\t%s\t%d\n", s, proto);
  CatPrint(buf, "%s", line);

  // --- 7. src_ip: bytes 12-15 = 10.0.2.15 ---
  src_ip = (g_ip_hdr[12] << 24) | (g_ip_hdr[13] << 16) |
           (g_ip_hdr[14] <<  8) |  g_ip_hdr[15];
  if (src_ip == 0x0A00020F) s = "PASS"; else s = "FAIL";
  StrPrint(line, "src_ip\t%s\t%d.%d.%d.%d\n", s,
    g_ip_hdr[12], g_ip_hdr[13], g_ip_hdr[14], g_ip_hdr[15]);
  CatPrint(buf, "%s", line);

  // --- 8. dst_ip: bytes 16-19 = 10.0.2.2 ---
  dst_ip = (g_ip_hdr[16] << 24) | (g_ip_hdr[17] << 16) |
           (g_ip_hdr[18] <<  8) |  g_ip_hdr[19];
  if (dst_ip == 0x0A000202) s = "PASS"; else s = "FAIL";
  StrPrint(line, "dst_ip\t%s\t%d.%d.%d.%d\n", s,
    g_ip_hdr[16], g_ip_hdr[17], g_ip_hdr[18], g_ip_hdr[19]);
  CatPrint(buf, "%s", line);

  // --- 9. cksum_nonzero: checksum field != 0 (non-trivial header) ---
  cksum_raw = (g_ip_hdr[10] << 8) | g_ip_hdr[11];
  if (cksum_raw != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "cksum_nonzero\t%s\t%04X\n", s, cksum_raw);
  CatPrint(buf, "%s", line);

  // --- 10. cksum_valid: re-verify over complete header (with checksum) = 0 ---
  cksum_verify = IPv4Cksum(g_ip_hdr, 20);
  if (cksum_verify == 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "cksum_valid\t%s\tverify=%04X\n", s, cksum_verify);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestIPv4Pkt.txt", buf, StrLen(buf));
  Print("TestIPv4Pkt done — 10 tests\n");
}

TestIPv4Pkt;
