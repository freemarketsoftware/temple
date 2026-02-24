// TestHTTPPost.HC — Tier 7: HTTP POST via TCP to agent_server.py on host:8081
// Flow: SYN → SYN-ACK → ACK+POST → HTTP 200 + ECHO response
// Standalone only (NIC access).
// Prerequisites: python3 serial/agent_server.py   (listens on 10.0.2.2:8081)
//
// POST body: "hello_temple\n" (13 bytes)
// Server echoes back: "ECHO:hello_temple\n" (18 bytes)
// IP total_len = 20(IP) + 20(TCP) + 74(HTTP) = 114 = 0x0072
// Frame total = 14(Eth) + 114 = 128 bytes

I64 g_post_bar0;
I64 g_post_txbase;
I64 g_post_txring[34];
I64 g_post_rxbase;
I64 g_post_rxring[34];
U8  g_post_syn[64];     // SYN packet (54 bytes)
U8  g_post_pkt[192];    // ACK+POST  (128 bytes)
U8  g_post_rx0[2048];   // desc0: SYN-ACK
U8  g_post_rx1[2048];   // desc1: HTTP response (may be pure ACK)
U8  g_post_rx2[2048];   // desc2: HTTP response data
U8  g_post_rx3[2048];   // desc3: overflow
U8  g_post_pseudo[12];  // TCP pseudo-header

I64 PostOnesAcc(U8 *data, I64 len) {
  I64 sum, i;
  sum = 0; i = 0;
  while (i + 1 < len) { sum += (data[i] << 8) | data[i+1]; i += 2; }
  if (i < len) sum += data[i] << 8;
  return sum;
}

I64 PostOnesCompl(I64 raw) {
  while (raw >> 16) raw = (raw & 0xFFFF) + (raw >> 16);
  return (~raw) & 0xFFFF;
}

I64 PostIPCksum(U8 *hdr)              { return PostOnesCompl(PostOnesAcc(hdr, 20)); }
I64 PostTCPCksum(U8 *tcp, I64 tcplen) {
  return PostOnesCompl(PostOnesAcc(g_post_pseudo, 12) + PostOnesAcc(tcp, tcplen));
}

U0 TestHTTPPost() {
  U8 buf[4096];
  U8 line[128];
  U8 *s;
  I64 raw, tda, rda, i, j;
  I64 pkt_addr, cksum;
  I64 sta0, sta1;
  I64 server_isn, syn_ack_ack, syn_ack_flags_val;
  I64 ip_total_len, tcp_data_off, scan_start;
  I64 src_port, src_port_hi, src_port_lo;
  I64 echo_found, status_200_found;
  U8 *rx;  // pointer to whichever rx buffer holds the HTTP data

  buf[0] = 0;
  CatPrint(buf, "# TestHTTPPost\n");

  // ── NIC init ────────────────────────────────────────────────────────────────
  g_post_bar0 = PCIReadU32(0, 3, 0, 0x10) & 0xFFFFFFF0;
  PCIWriteU16(0, 3, 0, 0x04, 0x0107);
  (g_post_bar0 + 0x0000)(U32*)[0] = 1 << 26;
  i = 0; while (i < 500000) { i++; }
  (g_post_bar0 + 0x0000)(U32*)[0] = 0x241;

  // TX ring
  raw = &g_post_txring[0]; tda = (raw + 15) & ~15;
  g_post_txbase = tda;
  (g_post_bar0 + 0x3800)(U32*)[0] = tda & 0xFFFFFFFF;
  (g_post_bar0 + 0x3804)(U32*)[0] = 0;
  (g_post_bar0 + 0x3808)(U32*)[0] = 256;
  (g_post_bar0 + 0x3810)(U32*)[0] = 0;
  (g_post_bar0 + 0x3818)(U32*)[0] = 0;
  (g_post_bar0 + 0x0400)(U32*)[0] = 0x0A;

  // RX ring (4 descriptors)
  raw = &g_post_rxring[0]; rda = (raw + 15) & ~15;
  g_post_rxbase = rda;
  (g_post_bar0 + 0x2800)(U32*)[0] = rda & 0xFFFFFFFF;
  (g_post_bar0 + 0x2804)(U32*)[0] = 0;
  (g_post_bar0 + 0x2808)(U32*)[0] = 256;
  (g_post_bar0 + 0x2810)(U32*)[0] = 0;
  (g_post_bar0 + 0x2818)(U32*)[0] = 0;

  g_post_rxbase(I64*)[0]        = &g_post_rx0[0];  (g_post_rxbase +  8)(I64*)[0] = 0;
  (g_post_rxbase + 16)(I64*)[0] = &g_post_rx1[0];  (g_post_rxbase + 24)(I64*)[0] = 0;
  (g_post_rxbase + 32)(I64*)[0] = &g_post_rx2[0];  (g_post_rxbase + 40)(I64*)[0] = 0;
  (g_post_rxbase + 48)(I64*)[0] = &g_post_rx3[0];  (g_post_rxbase + 56)(I64*)[0] = 0;

  (g_post_bar0 + 0x0100)(U32*)[0] = 0x8002;  // RCTL: EN+BAM
  (g_post_bar0 + 0x2818)(U32*)[0] = 4;        // RDT=4

  // ── Dynamic source port (avoids SLiRP stale state) ──────────────────────────
  src_port    = 0xC000 + (SysTimerRead() & 0x0FFF);
  src_port_hi = (src_port >> 8) & 0xFF;
  src_port_lo =  src_port       & 0xFF;

  // ── SYN packet ──────────────────────────────────────────────────────────────
  // Eth(14) + IP(20) + TCP(20) = 54 bytes
  // dst_port=8081=0x1F91, ISN=0xBEEFC0DE, flags=SYN
  MemSet(g_post_syn, 0, 64);
  g_post_syn[0]=0x52; g_post_syn[1]=0x55; g_post_syn[2]=0x0A;
  g_post_syn[3]=0x00; g_post_syn[4]=0x02; g_post_syn[5]=0x02;  // gw MAC
  g_post_syn[6]=0x52; g_post_syn[7]=0x54; g_post_syn[8]=0x00;
  g_post_syn[9]=0x12; g_post_syn[10]=0x34; g_post_syn[11]=0x56; // src MAC
  g_post_syn[12]=0x08; g_post_syn[13]=0x00;

  g_post_syn[14]=0x45; g_post_syn[16]=0x00; g_post_syn[17]=0x28;  // total_len=40
  g_post_syn[18]=0x00; g_post_syn[19]=0x01;
  g_post_syn[20]=0x40; g_post_syn[22]=64; g_post_syn[23]=6;
  g_post_syn[26]=0x0A; g_post_syn[27]=0x00; g_post_syn[28]=0x02; g_post_syn[29]=0x0F;
  g_post_syn[30]=0x0A; g_post_syn[31]=0x00; g_post_syn[32]=0x02; g_post_syn[33]=0x02;

  g_post_syn[34]=src_port_hi; g_post_syn[35]=src_port_lo;
  g_post_syn[36]=0x1F; g_post_syn[37]=0x91;  // dst_port=8081
  g_post_syn[38]=0xBE; g_post_syn[39]=0xEF;  // ISN=0xBEEFC0DE
  g_post_syn[40]=0xC0; g_post_syn[41]=0xDE;
  g_post_syn[46]=0x50; g_post_syn[47]=0x02;  // SYN
  g_post_syn[48]=0xFF; g_post_syn[49]=0xFF;

  g_post_pseudo[0]=0x0A; g_post_pseudo[1]=0x00; g_post_pseudo[2]=0x02; g_post_pseudo[3]=0x0F;
  g_post_pseudo[4]=0x0A; g_post_pseudo[5]=0x00; g_post_pseudo[6]=0x02; g_post_pseudo[7]=0x02;
  g_post_pseudo[8]=0; g_post_pseudo[9]=6;
  g_post_pseudo[10]=0; g_post_pseudo[11]=20;

  cksum = PostTCPCksum(&g_post_syn[34], 20);
  g_post_syn[50]=(cksum>>8)&0xFF; g_post_syn[51]=cksum&0xFF;
  cksum = PostIPCksum(&g_post_syn[14]);
  g_post_syn[24]=(cksum>>8)&0xFF; g_post_syn[25]=cksum&0xFF;

  pkt_addr = &g_post_syn[0];
  g_post_txbase(I64*)[0]       = pkt_addr;
  (g_post_txbase + 8)(I64*)[0] = 54 | (0x0B << 24);
  (g_post_bar0 + 0x3818)(U32*)[0] = 1;
  Sleep(2000);

  // Poll desc0 for SYN-ACK
  i = 0;
  while (i < 500000) { sta0 = (g_post_rxbase + 12)(U8*)[0]; if (sta0 & 1) break; i++; }

  server_isn        = (g_post_rx0[38]<<24)|(g_post_rx0[39]<<16)|(g_post_rx0[40]<<8)|g_post_rx0[41];
  syn_ack_ack       = (g_post_rx0[42]<<24)|(g_post_rx0[43]<<16)|(g_post_rx0[44]<<8)|g_post_rx0[45];
  syn_ack_flags_val = g_post_rx0[47];

  if (sta0 & 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "syn_ack_rxd\t%s\tsta=%02X iters=%d\n", s, sta0, i);
  CatPrint(buf, "%s", line);

  if (syn_ack_ack == 0xBEEFC0DF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "syn_ack_ack_ok\t%s\tack=%08X\n", s, syn_ack_ack);
  CatPrint(buf, "%s", line);

  if (syn_ack_flags_val == 0x12) s = "PASS"; else s = "FAIL";
  StrPrint(line, "syn_ack_flags\t%s\tflags=%02X\n", s, syn_ack_flags_val);
  CatPrint(buf, "%s", line);

  if (server_isn != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "server_isn_ok\t%s\tisn=%08X\n", s, server_isn);
  CatPrint(buf, "%s", line);

  // ── ACK+POST packet ─────────────────────────────────────────────────────────
  // Eth(14)+IP(20)+TCP(20)+HTTP(74)=128 bytes
  // HTTP payload: "POST /result HTTP/1.0\r\nHost: 10.0.2.2\r\nContent-Length: 13\r\n\r\nhello_temple\n"
  // ip_total_len=114=0x0072, tcp_len(for cksum)=94
  MemSet(g_post_pkt, 0, 192);
  g_post_pkt[0]=0x52; g_post_pkt[1]=0x55; g_post_pkt[2]=0x0A;
  g_post_pkt[3]=0x00; g_post_pkt[4]=0x02; g_post_pkt[5]=0x02;
  g_post_pkt[6]=0x52; g_post_pkt[7]=0x54; g_post_pkt[8]=0x00;
  g_post_pkt[9]=0x12; g_post_pkt[10]=0x34; g_post_pkt[11]=0x56;
  g_post_pkt[12]=0x08; g_post_pkt[13]=0x00;

  g_post_pkt[14]=0x45; g_post_pkt[16]=0x00; g_post_pkt[17]=0x72;  // total_len=114
  g_post_pkt[18]=0x00; g_post_pkt[19]=0x02;
  g_post_pkt[20]=0x40; g_post_pkt[22]=64; g_post_pkt[23]=6;
  g_post_pkt[26]=0x0A; g_post_pkt[27]=0x00; g_post_pkt[28]=0x02; g_post_pkt[29]=0x0F;
  g_post_pkt[30]=0x0A; g_post_pkt[31]=0x00; g_post_pkt[32]=0x02; g_post_pkt[33]=0x02;

  g_post_pkt[34]=src_port_hi; g_post_pkt[35]=src_port_lo;
  g_post_pkt[36]=0x1F; g_post_pkt[37]=0x91;  // dst_port=8081
  g_post_pkt[38]=0xBE; g_post_pkt[39]=0xEF;  // seq=ISN+1=0xBEEFC0DF
  g_post_pkt[40]=0xC0; g_post_pkt[41]=0xDF;
  g_post_pkt[42]=((server_isn+1)>>24)&0xFF;   // ack=server_isn+1
  g_post_pkt[43]=((server_isn+1)>>16)&0xFF;
  g_post_pkt[44]=((server_isn+1)>>8 )&0xFF;
  g_post_pkt[45]= (server_isn+1)     &0xFF;
  g_post_pkt[46]=0x50; g_post_pkt[47]=0x18;  // PSH|ACK
  g_post_pkt[48]=0xFF; g_post_pkt[49]=0xFF;

  // HTTP: "POST /result HTTP/1.0\r\n"  (23 bytes)
  g_post_pkt[54]=0x50; g_post_pkt[55]=0x4F; g_post_pkt[56]=0x53; g_post_pkt[57]=0x54;
  g_post_pkt[58]=0x20; g_post_pkt[59]=0x2F; g_post_pkt[60]=0x72; g_post_pkt[61]=0x65;
  g_post_pkt[62]=0x73; g_post_pkt[63]=0x75; g_post_pkt[64]=0x6C; g_post_pkt[65]=0x74;
  g_post_pkt[66]=0x20; g_post_pkt[67]=0x48; g_post_pkt[68]=0x54; g_post_pkt[69]=0x54;
  g_post_pkt[70]=0x50; g_post_pkt[71]=0x2F; g_post_pkt[72]=0x31; g_post_pkt[73]=0x2E;
  g_post_pkt[74]=0x30; g_post_pkt[75]=0x0D; g_post_pkt[76]=0x0A;
  // "Host: 10.0.2.2\r\n"  (16 bytes)
  g_post_pkt[77]=0x48; g_post_pkt[78]=0x6F; g_post_pkt[79]=0x73; g_post_pkt[80]=0x74;
  g_post_pkt[81]=0x3A; g_post_pkt[82]=0x20; g_post_pkt[83]=0x31; g_post_pkt[84]=0x30;
  g_post_pkt[85]=0x2E; g_post_pkt[86]=0x30; g_post_pkt[87]=0x2E; g_post_pkt[88]=0x32;
  g_post_pkt[89]=0x2E; g_post_pkt[90]=0x32; g_post_pkt[91]=0x0D; g_post_pkt[92]=0x0A;
  // "Content-Length: 13\r\n"  (20 bytes)
  g_post_pkt[93]=0x43; g_post_pkt[94]=0x6F; g_post_pkt[95]=0x6E; g_post_pkt[96]=0x74;
  g_post_pkt[97]=0x65; g_post_pkt[98]=0x6E; g_post_pkt[99]=0x74; g_post_pkt[100]=0x2D;
  g_post_pkt[101]=0x4C; g_post_pkt[102]=0x65; g_post_pkt[103]=0x6E; g_post_pkt[104]=0x67;
  g_post_pkt[105]=0x74; g_post_pkt[106]=0x68; g_post_pkt[107]=0x3A; g_post_pkt[108]=0x20;
  g_post_pkt[109]=0x31; g_post_pkt[110]=0x33; g_post_pkt[111]=0x0D; g_post_pkt[112]=0x0A;
  // blank line "\r\n"  (2 bytes)
  g_post_pkt[113]=0x0D; g_post_pkt[114]=0x0A;
  // body: "hello_temple\n"  (13 bytes)
  g_post_pkt[115]=0x68; g_post_pkt[116]=0x65; g_post_pkt[117]=0x6C; g_post_pkt[118]=0x6C;
  g_post_pkt[119]=0x6F; g_post_pkt[120]=0x5F; g_post_pkt[121]=0x74; g_post_pkt[122]=0x65;
  g_post_pkt[123]=0x6D; g_post_pkt[124]=0x70; g_post_pkt[125]=0x6C; g_post_pkt[126]=0x65;
  g_post_pkt[127]=0x0A;

  g_post_pseudo[10]=0; g_post_pseudo[11]=94;  // tcp_len = 20+74 = 94
  cksum = PostTCPCksum(&g_post_pkt[34], 94);
  g_post_pkt[50]=(cksum>>8)&0xFF; g_post_pkt[51]=cksum&0xFF;
  cksum = PostIPCksum(&g_post_pkt[14]);
  g_post_pkt[24]=(cksum>>8)&0xFF; g_post_pkt[25]=cksum&0xFF;

  pkt_addr = &g_post_pkt[0];
  (g_post_txbase + 16)(I64*)[0] = pkt_addr;
  (g_post_txbase + 24)(I64*)[0] = 128 | (0x0B << 24);
  (g_post_bar0 + 0x3818)(U32*)[0] = 2;
  Sleep(2000);

  // Poll desc1 for HTTP response; skip desc1 if it's a pure ACK (no payload)
  i = 0;
  while (i < 500000) { sta1 = (g_post_rxbase + 28)(U8*)[0]; if (sta1 & 1) break; i++; }

  ip_total_len = (g_post_rx1[16] << 8) | g_post_rx1[17];
  tcp_data_off = (g_post_rx1[46] >> 4) * 4;
  if (ip_total_len - 20 - tcp_data_off > 0) {
    rx = &g_post_rx1[0];
  } else {
    rx = &g_post_rx2[0];
    ip_total_len = (rx[16] << 8) | rx[17];
    tcp_data_off = (rx[46] >> 4) * 4;
  }
  scan_start = 14 + 20 + tcp_data_off;

  // Scan for "200" and "ECHO:" in the response
  status_200_found = 0; echo_found = 0;
  j = scan_start;
  while (j + 4 < 2048) {
    if (!status_200_found) {
      if (rx[j]=='2' && rx[j+1]=='0' && rx[j+2]=='0') status_200_found = 1;
    }
    if (!echo_found) {
      if (rx[j]=='E' && rx[j+1]=='C' && rx[j+2]=='H' && rx[j+3]=='O' && rx[j+4]==':') echo_found = 1;
    }
    j++;
  }

  if (sta1 & 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "post_resp_rxd\t%s\tsta=%02X iters=%d\n", s, sta1, i);
  CatPrint(buf, "%s", line);

  if (status_200_found) s = "PASS"; else s = "FAIL";
  StrPrint(line, "post_status_200\t%s\tfound=%d\n", s, status_200_found);
  CatPrint(buf, "%s", line);

  if (echo_found) s = "PASS"; else s = "FAIL";
  StrPrint(line, "post_echo_found\t%s\tfound=%d\n", s, echo_found);
  CatPrint(buf, "%s", line);

  if (ip_total_len - 20 - tcp_data_off > 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "post_body_len\t%s\tpayload=%d\n", s, ip_total_len - 20 - tcp_data_off);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestHTTPPost.txt", buf, StrLen(buf));
  Print("TestHTTPPost done -- 8 tests\n");
}

TestHTTPPost;
