// TestHTTPGet.HC — Tier 7: TCP 3-way handshake + HTTP GET via e1000 + QEMU SLiRP
// Prerequisites: Python HTTP server on host:8080 (10.0.2.2:8080 from guest).
//   cd /tmp && python3 -m http.server 8080 &
// Flow: SYN → SYN-ACK → ACK+GET → HTTP 200 response
// KEY: Sleep(2000) after SYN (flush_queue_timer fires, SLiRP returns SYN-ACK),
//      Sleep(2000) after GET (host roundtrip + SLiRP delivers response).
// Standalone only (NIC access).
// Results written to C:/AI/results/TestHTTPGet.txt
//
// TCP params:
//   Gateway MAC: 52:55:0A:00:02:02 (hardcoded, confirmed TestICMP)
//   src_ip: 10.0.2.15  dst_ip: 10.0.2.2
//   src_port: 4321 (0x10E1)  dst_port: 8080 (0x1F90)
//   Client ISN: 0x12345678

I64 g_http_bar0;
I64 g_http_txbase;
I64 g_http_txring[34];
I64 g_http_rxbase;
I64 g_http_rxring[34];
U8  g_http_syn[64];      // SYN packet (54 bytes)
U8  g_http_get[128];     // ACK+GET packet (88 bytes)
U8  g_http_rx0[2048];    // desc0: SYN-ACK
U8  g_http_rx1[2048];    // desc1: HTTP response (first segment)
U8  g_http_rx2[2048];    // desc2: HTTP response (continuation / pure ACK)
U8  g_http_rx3[2048];    // desc3: HTTP response (continuation)
U8  g_http_pseudo[12];   // TCP pseudo-header for checksum

// Accumulate ones-complement sum over a byte buffer (big-endian words).
I64 HttpOnesAcc(U8 *data, I64 len) {
  I64 sum, i;
  sum = 0;
  i = 0;
  while (i + 1 < len) {
    sum += (data[i] << 8) | data[i+1];
    i += 2;
  }
  if (i < len) sum += data[i] << 8;
  return sum;
}

// Fold carries and invert for ones-complement checksum.
I64 HttpOnesCompl(I64 raw) {
  while (raw >> 16)
    raw = (raw & 0xFFFF) + (raw >> 16);
  return (~raw) & 0xFFFF;
}

// IP header checksum (20-byte header, cksum field pre-zeroed).
I64 HttpIPCksum(U8 *hdr) {
  return HttpOnesCompl(HttpOnesAcc(hdr, 20));
}

// TCP checksum: pseudo-header (g_http_pseudo, 12 bytes) + TCP segment.
I64 HttpTCPCksum(U8 *tcp, I64 tcp_len) {
  I64 sum;
  sum = HttpOnesAcc(g_http_pseudo, 12) + HttpOnesAcc(tcp, tcp_len);
  return HttpOnesCompl(sum);
}

U0 TestHTTPGet() {
  U8 buf[4096];
  U8 line[128];
  U8 *s;
  I64 raw, tda, rda, i, j;
  I64 rx0a, rx1a, rx2a, rx3a, pkt_addr, cksum;
  I64 sta0, sta1;
  I64 server_isn, syn_ack_ack, syn_ack_flags_val;
  I64 ip_total_len, tcp_data_off;
  I64 http_sig_found, status_200_found;
  I64 scan_start;

  buf[0] = 0;
  CatPrint(buf, "# TestHTTPGet\n");

  // ---- NIC init ----
  g_http_bar0 = PCIReadU32(0, 3, 0, 0x10) & 0xFFFFFFF0;
  PCIWriteU16(0, 3, 0, 0x04, 0x0107);
  (g_http_bar0 + 0x0000)(U32*)[0] = 1 << 26;   // CTRL: soft reset
  i = 0; while (i < 500000) { i++; }
  (g_http_bar0 + 0x0000)(U32*)[0] = 0x241;      // SLU|FD

  // TX ring
  raw = &g_http_txring[0];
  tda = (raw + 15) & ~15;
  g_http_txbase = tda;
  (g_http_bar0 + 0x3800)(U32*)[0] = tda & 0xFFFFFFFF;
  (g_http_bar0 + 0x3804)(U32*)[0] = 0;
  (g_http_bar0 + 0x3808)(U32*)[0] = 256;
  (g_http_bar0 + 0x3810)(U32*)[0] = 0;
  (g_http_bar0 + 0x3818)(U32*)[0] = 0;
  (g_http_bar0 + 0x0400)(U32*)[0] = 0x0A;       // TCTL: EN|PSP

  // RX ring (4 descriptors: SYN-ACK + up to 3 HTTP response segments)
  raw = &g_http_rxring[0];
  rda = (raw + 15) & ~15;
  g_http_rxbase = rda;
  (g_http_bar0 + 0x2800)(U32*)[0] = rda & 0xFFFFFFFF;
  (g_http_bar0 + 0x2804)(U32*)[0] = 0;
  (g_http_bar0 + 0x2808)(U32*)[0] = 256;
  (g_http_bar0 + 0x2810)(U32*)[0] = 0;
  (g_http_bar0 + 0x2818)(U32*)[0] = 0;

  rx0a = &g_http_rx0[0];
  rx1a = &g_http_rx1[0];
  rx2a = &g_http_rx2[0];
  rx3a = &g_http_rx3[0];
  g_http_rxbase(I64*)[0]        = rx0a;
  (g_http_rxbase +  8)(I64*)[0] = 0;
  (g_http_rxbase + 16)(I64*)[0] = rx1a;
  (g_http_rxbase + 24)(I64*)[0] = 0;
  (g_http_rxbase + 32)(I64*)[0] = rx2a;
  (g_http_rxbase + 40)(I64*)[0] = 0;
  (g_http_rxbase + 48)(I64*)[0] = rx3a;
  (g_http_rxbase + 56)(I64*)[0] = 0;

  // Enable RX: BAM=broadcast accept. Arm flush_queue_timer (+1000ms virtual).
  (g_http_bar0 + 0x0100)(U32*)[0] = 0x8002;
  (g_http_bar0 + 0x2818)(U32*)[0] = 4;  // RDT=4: give all 4 descs to HW

  // ---- Build SYN packet ----
  // Eth(14) + IP(20) + TCP(20) = 54 bytes
  // IP total_len=40 (0x0028), TCP flags=0x02 (SYN), seq=0x12345678
  MemSet(g_http_syn, 0, 64);

  // Ethernet: dst=52:55:0A:00:02:02 (gw), src=52:54:00:12:34:56, type=0x0800
  g_http_syn[0]=0x52; g_http_syn[1]=0x55; g_http_syn[2]=0x0A;
  g_http_syn[3]=0x00; g_http_syn[4]=0x02; g_http_syn[5]=0x02;
  g_http_syn[6]=0x52; g_http_syn[7]=0x54; g_http_syn[8]=0x00;
  g_http_syn[9]=0x12; g_http_syn[10]=0x34; g_http_syn[11]=0x56;
  g_http_syn[12]=0x08; g_http_syn[13]=0x00;

  // IP: src=10.0.2.15, dst=10.0.2.2, proto=6, total_len=40
  g_http_syn[14]=0x45;
  g_http_syn[15]=0x00;
  g_http_syn[16]=0x00; g_http_syn[17]=0x28;  // total_len=40
  g_http_syn[18]=0x00; g_http_syn[19]=0x01;  // ID=1
  g_http_syn[20]=0x40; g_http_syn[21]=0x00;  // DF bit
  g_http_syn[22]=64;                          // TTL
  g_http_syn[23]=6;                           // proto=TCP
  g_http_syn[24]=0x00; g_http_syn[25]=0x00;  // cksum (filled below)
  g_http_syn[26]=0x0A; g_http_syn[27]=0x00;
  g_http_syn[28]=0x02; g_http_syn[29]=0x0F;  // src=10.0.2.15
  g_http_syn[30]=0x0A; g_http_syn[31]=0x00;
  g_http_syn[32]=0x02; g_http_syn[33]=0x02;  // dst=10.0.2.2

  // TCP: src_port=4321, dst_port=8080, seq=0x12345678, flags=SYN
  g_http_syn[34]=0x10; g_http_syn[35]=0xE1;  // src_port=4321
  g_http_syn[36]=0x1F; g_http_syn[37]=0x90;  // dst_port=8080
  g_http_syn[38]=0x12; g_http_syn[39]=0x34;  // seq=0x12345678
  g_http_syn[40]=0x56; g_http_syn[41]=0x78;
  // ack=0 (SYN has no ack), already zeroed
  g_http_syn[46]=0x50;   // data_offset=5 (20 bytes), no options
  g_http_syn[47]=0x02;   // flags=SYN
  g_http_syn[48]=0xFF; g_http_syn[49]=0xFF;  // window=65535

  // TCP checksum for SYN (tcp_len=20)
  g_http_pseudo[0]=0x0A; g_http_pseudo[1]=0x00;
  g_http_pseudo[2]=0x02; g_http_pseudo[3]=0x0F;  // src=10.0.2.15
  g_http_pseudo[4]=0x0A; g_http_pseudo[5]=0x00;
  g_http_pseudo[6]=0x02; g_http_pseudo[7]=0x02;  // dst=10.0.2.2
  g_http_pseudo[8]=0;    // zero
  g_http_pseudo[9]=6;    // proto=TCP
  g_http_pseudo[10]=0; g_http_pseudo[11]=20;   // tcp_len=20

  cksum = HttpTCPCksum(&g_http_syn[34], 20);
  g_http_syn[50] = (cksum >> 8) & 0xFF;
  g_http_syn[51] =  cksum       & 0xFF;

  // IP checksum
  cksum = HttpIPCksum(&g_http_syn[14]);
  g_http_syn[24] = (cksum >> 8) & 0xFF;
  g_http_syn[25] =  cksum       & 0xFF;

  // TX desc 0: SYN (54 bytes)
  pkt_addr = &g_http_syn[0];
  g_http_txbase(I64*)[0]       = pkt_addr;
  (g_http_txbase + 8)(I64*)[0] = 54 | (0x0B << 24);
  (g_http_bar0 + 0x3818)(U32*)[0] = 1;  // TDT=1: kick SYN TX

  // Sleep(2000): flush_queue_timer fires, SLiRP returns SYN-ACK to desc0
  Sleep(2000);

  // Poll desc0 for SYN-ACK
  i = 0;
  while (i < 500000) {
    sta0 = (g_http_rxbase + 12)(U8*)[0];
    if (sta0 & 1) break;
    i++;
  }

  // Extract SYN-ACK fields (TCP header at frame offset 34)
  // seq at TCP[4-7]=frame[38-41] = server ISN
  // ack at TCP[8-11]=frame[42-45] = should be our ISN+1 = 0x12345679
  // flags at TCP[13]=frame[47] = 0x12 (SYN|ACK)
  server_isn     = (g_http_rx0[38] << 24) | (g_http_rx0[39] << 16) |
                   (g_http_rx0[40] <<  8) |  g_http_rx0[41];
  syn_ack_ack    = (g_http_rx0[42] << 24) | (g_http_rx0[43] << 16) |
                   (g_http_rx0[44] <<  8) |  g_http_rx0[45];
  syn_ack_flags_val = g_http_rx0[47];

  // --- 1. syn_ack_rxd: SYN-ACK received (desc0 DD bit set) ---
  if (sta0 & 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "syn_ack_rxd\t%s\tsta=%02X iters=%d\n", s, sta0, i);
  CatPrint(buf, "%s", line);

  // --- 2. syn_ack_ack_ok: ACK field = our ISN+1 = 0x12345679 ---
  if (syn_ack_ack == 0x12345679) s = "PASS"; else s = "FAIL";
  StrPrint(line, "syn_ack_ack_ok\t%s\tack=%08X\n", s, syn_ack_ack);
  CatPrint(buf, "%s", line);

  // --- 3. syn_ack_flags: flags byte = 0x12 (SYN|ACK) ---
  if (syn_ack_flags_val == 0x12) s = "PASS"; else s = "FAIL";
  StrPrint(line, "syn_ack_flags\t%s\tflags=%02X\n", s, syn_ack_flags_val);
  CatPrint(buf, "%s", line);

  // --- 4. server_isn: server ISN is non-zero ---
  if (server_isn != 0) s = "PASS"; else s = "FAIL";
  StrPrint(line, "server_isn\t%s\tisn=%08X\n", s, server_isn);
  CatPrint(buf, "%s", line);

  // ---- Build ACK+GET packet ----
  // Eth(14)+IP(20)+TCP(20)+data(34)=88 bytes
  // seq=0x12345679 (ISN+1), ack=server_isn+1, flags=PSH|ACK=0x18
  // HTTP: "GET / HTTP/1.0\r\nHost: 10.0.2.2\r\n\r\n" = 34 bytes
  MemSet(g_http_get, 0, 128);

  // Ethernet
  g_http_get[0]=0x52; g_http_get[1]=0x55; g_http_get[2]=0x0A;
  g_http_get[3]=0x00; g_http_get[4]=0x02; g_http_get[5]=0x02;
  g_http_get[6]=0x52; g_http_get[7]=0x54; g_http_get[8]=0x00;
  g_http_get[9]=0x12; g_http_get[10]=0x34; g_http_get[11]=0x56;
  g_http_get[12]=0x08; g_http_get[13]=0x00;

  // IP: total_len=74 (0x004A = 20+20+34)
  g_http_get[14]=0x45;
  g_http_get[15]=0x00;
  g_http_get[16]=0x00; g_http_get[17]=0x4A;  // total_len=74
  g_http_get[18]=0x00; g_http_get[19]=0x02;  // ID=2
  g_http_get[20]=0x40; g_http_get[21]=0x00;  // DF
  g_http_get[22]=64;
  g_http_get[23]=6;                           // TCP
  g_http_get[24]=0x00; g_http_get[25]=0x00;  // cksum (filled below)
  g_http_get[26]=0x0A; g_http_get[27]=0x00;
  g_http_get[28]=0x02; g_http_get[29]=0x0F;  // src=10.0.2.15
  g_http_get[30]=0x0A; g_http_get[31]=0x00;
  g_http_get[32]=0x02; g_http_get[33]=0x02;  // dst=10.0.2.2

  // TCP: src=4321, dst=8080, seq=0x12345679, flags=PSH|ACK
  g_http_get[34]=0x10; g_http_get[35]=0xE1;  // src_port=4321
  g_http_get[36]=0x1F; g_http_get[37]=0x90;  // dst_port=8080
  g_http_get[38]=0x12; g_http_get[39]=0x34;  // seq=0x12345679
  g_http_get[40]=0x56; g_http_get[41]=0x79;
  // ack = server_isn + 1
  g_http_get[42] = ((server_isn + 1) >> 24) & 0xFF;
  g_http_get[43] = ((server_isn + 1) >> 16) & 0xFF;
  g_http_get[44] = ((server_isn + 1) >>  8) & 0xFF;
  g_http_get[45] =  (server_isn + 1)        & 0xFF;
  g_http_get[46]=0x50;   // data_offset=5 (20 bytes)
  g_http_get[47]=0x18;   // PSH|ACK
  g_http_get[48]=0xFF; g_http_get[49]=0xFF;  // window

  // HTTP request data at offset 54: "GET / HTTP/1.0\r\nHost: 10.0.2.2\r\n\r\n"
  g_http_get[54]=0x47; g_http_get[55]=0x45; g_http_get[56]=0x54;  // GET
  g_http_get[57]=0x20; g_http_get[58]=0x2F; g_http_get[59]=0x20;  // ' / '
  g_http_get[60]=0x48; g_http_get[61]=0x54; g_http_get[62]=0x54;  // HTT
  g_http_get[63]=0x50; g_http_get[64]=0x2F; g_http_get[65]=0x31;  // P/1
  g_http_get[66]=0x2E; g_http_get[67]=0x30; g_http_get[68]=0x0D;  // .0\r
  g_http_get[69]=0x0A; g_http_get[70]=0x48; g_http_get[71]=0x6F;  // \nHo
  g_http_get[72]=0x73; g_http_get[73]=0x74; g_http_get[74]=0x3A;  // st:
  g_http_get[75]=0x20; g_http_get[76]=0x31; g_http_get[77]=0x30;  // ' 10'
  g_http_get[78]=0x2E; g_http_get[79]=0x30; g_http_get[80]=0x2E;  // .0.
  g_http_get[81]=0x32; g_http_get[82]=0x2E; g_http_get[83]=0x32;  // 2.2
  g_http_get[84]=0x0D; g_http_get[85]=0x0A;  // \r\n
  g_http_get[86]=0x0D; g_http_get[87]=0x0A;  // \r\n

  // TCP checksum for ACK+GET (tcp_len=54: 20 header + 34 data)
  g_http_pseudo[10]=0; g_http_pseudo[11]=54;
  cksum = HttpTCPCksum(&g_http_get[34], 54);
  g_http_get[50] = (cksum >> 8) & 0xFF;
  g_http_get[51] =  cksum       & 0xFF;

  // IP checksum
  cksum = HttpIPCksum(&g_http_get[14]);
  g_http_get[24] = (cksum >> 8) & 0xFF;
  g_http_get[25] =  cksum       & 0xFF;

  // TX desc 1: ACK+GET (88 bytes)
  pkt_addr = &g_http_get[0];
  (g_http_txbase + 16)(I64*)[0] = pkt_addr;
  (g_http_txbase + 24)(I64*)[0] = 88 | (0x0B << 24);
  (g_http_bar0 + 0x3818)(U32*)[0] = 2;  // TDT=2: kick ACK+GET TX

  // Sleep(2000): host Python server processes request, SLiRP delivers HTTP response
  Sleep(2000);

  // Poll desc1 for HTTP response (or pure ACK)
  i = 0;
  while (i < 500000) {
    sta1 = (g_http_rxbase + 28)(U8*)[0];
    if (sta1 & 1) break;
    i++;
  }

  // Determine which RX buffer has the HTTP data.
  // If desc1 is a pure TCP ACK (ip_total_len=40, no payload), HTTP data is in desc2.
  ip_total_len = (g_http_rx1[16] << 8) | g_http_rx1[17];
  tcp_data_off = (g_http_rx1[46] >> 4) * 4;
  scan_start   = 14 + 20 + tcp_data_off;  // byte offset of TCP data in rx1

  if (ip_total_len > 40) {
    // rx1 has payload: scan it for "HTTP/" and "200"
    http_sig_found  = 0;
    status_200_found = 0;
    j = scan_start;
    while (j + 4 < 2048) {
      if (!http_sig_found) {
        if (g_http_rx1[j]=='H' && g_http_rx1[j+1]=='T' &&
            g_http_rx1[j+2]=='T' && g_http_rx1[j+3]=='P' &&
            g_http_rx1[j+4]=='/') {
          http_sig_found = 1;
        }
      }
      if (!status_200_found && j + 2 < 2048) {
        if (g_http_rx1[j]=='2' && g_http_rx1[j+1]=='0' &&
            g_http_rx1[j+2]=='0') {
          status_200_found = 1;
        }
      }
      j++;
    }
  } else {
    // rx1 is a pure ACK — HTTP data should be in rx2 (desc2)
    ip_total_len = (g_http_rx2[16] << 8) | g_http_rx2[17];
    tcp_data_off = (g_http_rx2[46] >> 4) * 4;
    scan_start   = 14 + 20 + tcp_data_off;
    http_sig_found  = 0;
    status_200_found = 0;
    j = scan_start;
    while (j + 4 < 2048) {
      if (!http_sig_found) {
        if (g_http_rx2[j]=='H' && g_http_rx2[j+1]=='T' &&
            g_http_rx2[j+2]=='T' && g_http_rx2[j+3]=='P' &&
            g_http_rx2[j+4]=='/') {
          http_sig_found = 1;
        }
      }
      if (!status_200_found && j + 2 < 2048) {
        if (g_http_rx2[j]=='2' && g_http_rx2[j+1]=='0' &&
            g_http_rx2[j+2]=='0') {
          status_200_found = 1;
        }
      }
      j++;
    }
  }

  // --- 5. http_rxd: HTTP response received in desc1 ---
  if (sta1 & 1) s = "PASS"; else s = "FAIL";
  StrPrint(line, "http_rxd\t%s\tsta=%02X iters=%d\n", s, sta1, i);
  CatPrint(buf, "%s", line);

  // --- 6. http_sig: "HTTP/" signature found in response ---
  if (http_sig_found) s = "PASS"; else s = "FAIL";
  StrPrint(line, "http_sig\t%s\tfound=%d\n", s, http_sig_found);
  CatPrint(buf, "%s", line);

  // --- 7. status_200: "200" status code found ---
  if (status_200_found) s = "PASS"; else s = "FAIL";
  StrPrint(line, "status_200\t%s\tfound=%d\n", s, status_200_found);
  CatPrint(buf, "%s", line);

  // --- 8. resp_len: IP total_len > 40 (response has payload) ---
  if (ip_total_len > 40) s = "PASS"; else s = "FAIL";
  StrPrint(line, "resp_len\t%s\tip_total_len=%d\n", s, ip_total_len);
  CatPrint(buf, "%s", line);

  DirMk("C:/AI");
  DirMk("C:/AI/results");
  FileWrite("C:/AI/results/TestHTTPGet.txt", buf, StrLen(buf));
  Print("TestHTTPGet done -- 8 tests\n");
}

TestHTTPGet;
