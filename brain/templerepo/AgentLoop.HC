// AgentLoop.HC - TempleOS TCP agent loop
//
// Polls GET /cmd from agent_server.py (host:8081), executes each command,
// POSTs output to POST /result.  Runs until "EXIT" received.
//
// Command convention:
//   Commands write output to g_agent_out[] via CatPrint(g_agent_out,...).
//   AgentLoop clears g_agent_out before each command and POSTs it after.
//
// Execution: writes command to C:/AI/_cmd.HC, calls ExeFile().
// Standalone only (direct NIC MMIO).
//
// Each AgHTTP() call resets the RX/TX rings fully (RCTL off/on) so the
// flush_queue_timer re-arms and SLiRP packets are delivered reliably.
//   Sleep(2000) after SYN  — timer fires → SYN-ACK arrives
//   Sleep(200)  after DATA — response arrives synchronously after timer

// ── Debug buffer (written to C:/AI/debug.txt on exit) ─────────────────────────
U8 g_agent_dbg[2048];

// ── Globals ───────────────────────────────────────────────────────────────────
I64 g_agent_bar0;
I64 g_agent_txbase;
I64 g_agent_txring[34];
I64 g_agent_rxbase;
I64 g_agent_rxring[34];
I64 g_agent_rxptrs[8];

U8  g_agent_rx0[2048];
U8  g_agent_rx1[2048];
U8  g_agent_rx2[2048];
U8  g_agent_rx3[2048];
U8  g_agent_rx4[2048];
U8  g_agent_rx5[2048];
U8  g_agent_rx6[2048];
U8  g_agent_rx7[2048];

U8  g_agent_pkt[1600];      // TX frame (SYN=54, GET=~100, POST=up to ~1200)
U8  g_agent_pseudo[12];
U8  g_agent_gw_mac[6];

U8  g_agent_cmd[2048];      // body received from GET /cmd
U8  g_agent_out[900];       // command output — must fit in one TCP segment
U8  g_agent_post_hdr[128];  // "POST /result HTTP/1.0\r\n..." header
U8  g_agent_post_req[1100]; // post_hdr + g_agent_out combined

// ── Checksum helpers ──────────────────────────────────────────────────────────
I64 AgOnesAcc(U8 *data, I64 len) {
  I64 sum, i;
  sum = 0; i = 0;
  while (i + 1 < len) { sum += (data[i] << 8) | data[i+1]; i += 2; }
  if (i < len) sum += data[i] << 8;
  return sum;
}
I64 AgOnesCompl(I64 raw) {
  while (raw >> 16) raw = (raw & 0xFFFF) + (raw >> 16);
  return (~raw) & 0xFFFF;
}
I64 AgIPCksum(U8 *hdr)              { return AgOnesCompl(AgOnesAcc(hdr, 20)); }
I64 AgTCPCksum(U8 *tcp, I64 tcplen) {
  return AgOnesCompl(AgOnesAcc(g_agent_pseudo, 12) + AgOnesAcc(tcp, tcplen));
}

// ── RX/TX ring reset (called at the start of each HTTP round-trip) ────────────
U0 AgRingReset() {
  I64 j;
  // TX: stop, reset to slot 0, re-enable
  (g_agent_bar0 + 0x0400)(U32*)[0] = 0;
  (g_agent_bar0 + 0x3800)(U32*)[0] = g_agent_txbase & 0xFFFFFFFF;
  (g_agent_bar0 + 0x3804)(U32*)[0] = 0;
  (g_agent_bar0 + 0x3808)(U32*)[0] = 256;
  (g_agent_bar0 + 0x3810)(U32*)[0] = 0;   // TDH=0
  (g_agent_bar0 + 0x3818)(U32*)[0] = 0;   // TDT=0
  (g_agent_bar0 + 0x0400)(U32*)[0] = 0x0A;

  // RX: stop, clear all descriptor status, reset to slot 0, re-enable
  (g_agent_bar0 + 0x0100)(U32*)[0] = 0;
  for (j = 0; j < 8; j++) {
    (g_agent_rxbase + j*16    )(I64*)[0] = g_agent_rxptrs[j];
    (g_agent_rxbase + j*16 + 8)(I64*)[0] = 0;
  }
  (g_agent_bar0 + 0x2800)(U32*)[0] = g_agent_rxbase & 0xFFFFFFFF;
  (g_agent_bar0 + 0x2804)(U32*)[0] = 0;
  (g_agent_bar0 + 0x2808)(U32*)[0] = 256;
  (g_agent_bar0 + 0x2810)(U32*)[0] = 0;   // RDH=0 (safe when RCTL=0)
  (g_agent_bar0 + 0x2818)(U32*)[0] = 0;   // RDT=0
  (g_agent_bar0 + 0x0100)(U32*)[0] = 0x8002;
  (g_agent_bar0 + 0x2818)(U32*)[0] = 8;   // give all 8 to HW
}

// ── Wait for descriptor j to have DD bit, spin up to 2M iterations ───────────
I64 AgWaitDD(I64 j) {
  I64 i, sta;
  i = 0;
  while (i < 2000000) {
    sta = (g_agent_rxbase + j*16 + 12)(U8*)[0];
    if (sta & 1) return 1;
    i++;
  }
  return 0;
}

// ── Find \r\n\r\n, return offset of first body byte (-1 if not found) ─────────
I64 AgBodyOff(U8 *buf, I64 start, I64 end) {
  I64 j;
  j = start;
  while (j + 3 < end) {
    if (buf[j]==0x0D && buf[j+1]==0x0A && buf[j+2]==0x0D && buf[j+3]==0x0A)
      return j + 4;
    j++;
  }
  return -1;
}

// ── One HTTP request/response round-trip ──────────────────────────────────────
// http_data: just the HTTP request bytes (headers+body, no Ethernet/IP/TCP)
// http_len:  byte count of http_data
// out_buf:   receives HTTP response body (null-terminated)
// out_max:   max bytes to write into out_buf
// Returns 1 on success, 0 on timeout/error.
I64 AgHTTP(U8 *http_data, I64 http_len, U8 *out_buf, I64 out_max) {
  I64 src_port, src_hi, src_lo;
  I64 cksum, server_isn;
  I64 i, j;
  I64 ip_total, tcp_seg_len, frame_len;
  I64 ip_total_len, tcp_data_off, data_off, rx_end, body_off, out_len;
  U8 *rx;

  AgRingReset;  // fresh rings + re-arms flush_queue_timer

  src_port = 0xC000 + (SysTimerRead() & 0x0FFF);
  src_hi   = (src_port >> 8) & 0xFF;
  src_lo   =  src_port       & 0xFF;

  // ── SYN ──────────────────────────────────────────────────────────────────
  MemSet(g_agent_pkt, 0, 64);
  g_agent_pkt[0]=g_agent_gw_mac[0]; g_agent_pkt[1]=g_agent_gw_mac[1];
  g_agent_pkt[2]=g_agent_gw_mac[2]; g_agent_pkt[3]=g_agent_gw_mac[3];
  g_agent_pkt[4]=g_agent_gw_mac[4]; g_agent_pkt[5]=g_agent_gw_mac[5];
  g_agent_pkt[6]=0x52; g_agent_pkt[7]=0x54; g_agent_pkt[8]=0x00;
  g_agent_pkt[9]=0x12; g_agent_pkt[10]=0x34; g_agent_pkt[11]=0x56;
  g_agent_pkt[12]=0x08; g_agent_pkt[13]=0x00;
  g_agent_pkt[14]=0x45; g_agent_pkt[16]=0x00; g_agent_pkt[17]=0x28;
  g_agent_pkt[18]=0x00; g_agent_pkt[19]=0x09;
  g_agent_pkt[20]=0x40; g_agent_pkt[22]=64; g_agent_pkt[23]=6;
  g_agent_pkt[26]=0x0A; g_agent_pkt[27]=0x00; g_agent_pkt[28]=0x02; g_agent_pkt[29]=0x0F;
  g_agent_pkt[30]=0x0A; g_agent_pkt[31]=0x00; g_agent_pkt[32]=0x02; g_agent_pkt[33]=0x02;
  g_agent_pkt[34]=src_hi;  g_agent_pkt[35]=src_lo;
  g_agent_pkt[36]=0x1F; g_agent_pkt[37]=0x91;  // dst=8081
  g_agent_pkt[38]=0xCA; g_agent_pkt[39]=0xFE;  // ISN=0xCAFEF00D
  g_agent_pkt[40]=0xF0; g_agent_pkt[41]=0x0D;
  g_agent_pkt[46]=0x50; g_agent_pkt[47]=0x02;  // SYN
  g_agent_pkt[48]=0xFF; g_agent_pkt[49]=0xFF;

  g_agent_pseudo[0]=0x0A; g_agent_pseudo[1]=0x00; g_agent_pseudo[2]=0x02; g_agent_pseudo[3]=0x0F;
  g_agent_pseudo[4]=0x0A; g_agent_pseudo[5]=0x00; g_agent_pseudo[6]=0x02; g_agent_pseudo[7]=0x02;
  g_agent_pseudo[8]=0; g_agent_pseudo[9]=6; g_agent_pseudo[10]=0; g_agent_pseudo[11]=20;

  cksum = AgTCPCksum(&g_agent_pkt[34], 20);
  g_agent_pkt[50]=(cksum>>8)&0xFF; g_agent_pkt[51]=cksum&0xFF;
  cksum = AgIPCksum(&g_agent_pkt[14]);
  g_agent_pkt[24]=(cksum>>8)&0xFF; g_agent_pkt[25]=cksum&0xFF;

  g_agent_txbase(I64*)[0]       = &g_agent_pkt[0];
  (g_agent_txbase + 8)(I64*)[0] = 54 | (0x0B << 24);
  (g_agent_bar0 + 0x3818)(U32*)[0] = 1;
  Sleep(2000);  // flush_queue_timer → SYN-ACK

  // ── Scan for SYN-ACK ─────────────────────────────────────────────────────
  server_isn = 0; j = 0;
  while (j < 8) {
    if (!AgWaitDD(j)) { j = 8; }  // timeout — bail
    else if ((g_agent_rxptrs[j])(U8*)[12]==0x08 &&
             (g_agent_rxptrs[j])(U8*)[13]==0x00 &&
             (g_agent_rxptrs[j])(U8*)[23]==6    &&
             (g_agent_rxptrs[j])(U8*)[34]==0x1F &&
             (g_agent_rxptrs[j])(U8*)[35]==0x91 &&
             (g_agent_rxptrs[j])(U8*)[36]==src_hi &&
             (g_agent_rxptrs[j])(U8*)[37]==src_lo &&
             ((g_agent_rxptrs[j])(U8*)[47] & 0x12)==0x12) {
      server_isn = ((g_agent_rxptrs[j])(U8*)[38]<<24) |
                   ((g_agent_rxptrs[j])(U8*)[39]<<16) |
                   ((g_agent_rxptrs[j])(U8*)[40]<< 8) |
                    (g_agent_rxptrs[j])(U8*)[41];
      j++;
      break;
    } else { j++; }
  }
  if (!server_isn) { out_buf[0]=0; return 0; }

  // ── PSH|ACK + HTTP request ────────────────────────────────────────────────
  tcp_seg_len = 20 + http_len;      // TCP header + payload
  ip_total    = 20 + tcp_seg_len;   // IP header + TCP
  frame_len   = 14 + ip_total;      // Eth + IP + TCP

  MemSet(g_agent_pkt, 0, 64);       // clear headers (http_data copied separately)
  g_agent_pkt[0]=g_agent_gw_mac[0]; g_agent_pkt[1]=g_agent_gw_mac[1];
  g_agent_pkt[2]=g_agent_gw_mac[2]; g_agent_pkt[3]=g_agent_gw_mac[3];
  g_agent_pkt[4]=g_agent_gw_mac[4]; g_agent_pkt[5]=g_agent_gw_mac[5];
  g_agent_pkt[6]=0x52; g_agent_pkt[7]=0x54; g_agent_pkt[8]=0x00;
  g_agent_pkt[9]=0x12; g_agent_pkt[10]=0x34; g_agent_pkt[11]=0x56;
  g_agent_pkt[12]=0x08; g_agent_pkt[13]=0x00;
  g_agent_pkt[14]=0x45;
  g_agent_pkt[16]=(ip_total>>8)&0xFF; g_agent_pkt[17]=ip_total&0xFF;
  g_agent_pkt[18]=0x00; g_agent_pkt[19]=0x0A;
  g_agent_pkt[20]=0x40; g_agent_pkt[22]=64; g_agent_pkt[23]=6;
  g_agent_pkt[26]=0x0A; g_agent_pkt[27]=0x00; g_agent_pkt[28]=0x02; g_agent_pkt[29]=0x0F;
  g_agent_pkt[30]=0x0A; g_agent_pkt[31]=0x00; g_agent_pkt[32]=0x02; g_agent_pkt[33]=0x02;
  g_agent_pkt[34]=src_hi; g_agent_pkt[35]=src_lo;
  g_agent_pkt[36]=0x1F; g_agent_pkt[37]=0x91;
  g_agent_pkt[38]=0xCA; g_agent_pkt[39]=0xFE; g_agent_pkt[40]=0xF0; g_agent_pkt[41]=0x0E;
  g_agent_pkt[42]=((server_isn+1)>>24)&0xFF;
  g_agent_pkt[43]=((server_isn+1)>>16)&0xFF;
  g_agent_pkt[44]=((server_isn+1)>> 8)&0xFF;
  g_agent_pkt[45]= (server_isn+1)     &0xFF;
  g_agent_pkt[46]=0x50; g_agent_pkt[47]=0x18;  // PSH|ACK
  g_agent_pkt[48]=0xFF; g_agent_pkt[49]=0xFF;

  for (i = 0; i < http_len; i++) g_agent_pkt[54 + i] = http_data[i];

  g_agent_pseudo[10]=(tcp_seg_len>>8)&0xFF;
  g_agent_pseudo[11]= tcp_seg_len    &0xFF;
  cksum = AgTCPCksum(&g_agent_pkt[34], tcp_seg_len);
  g_agent_pkt[50]=(cksum>>8)&0xFF; g_agent_pkt[51]=cksum&0xFF;
  cksum = AgIPCksum(&g_agent_pkt[14]);
  g_agent_pkt[24]=(cksum>>8)&0xFF; g_agent_pkt[25]=cksum&0xFF;

  (g_agent_txbase + 16)(I64*)[0] = &g_agent_pkt[0];
  (g_agent_txbase + 24)(I64*)[0] = frame_len | (0x0B << 24);
  (g_agent_bar0 + 0x3818)(U32*)[0] = 2;
  Sleep(200);  // synchronous after timer fired

  // ── Scan ALL remaining slots for payload; search each for \r\n\r\n ──────────
  // SLiRP may split HTTP response across 2 TCP segments (headers in seg1,
  // \r\n\r\n + body in seg2).  We keep scanning until we find the separator.
  rx = 0; body_off = -1;
  while (j < 8 && body_off < 0) {
    if (!AgWaitDD(j)) { j = 8; }
    else {
      ip_total_len = ((g_agent_rxptrs[j])(U8*)[16]<<8) | (g_agent_rxptrs[j])(U8*)[17];
      tcp_data_off = ((g_agent_rxptrs[j])(U8*)[46]>>4)*4;
      data_off     = 14 + 20 + tcp_data_off;
      rx_end       = 14 + ip_total_len;
      if (rx_end > 2048) rx_end = 2048;
      if ((g_agent_rxptrs[j])(U8*)[12]==0x08 &&
          (g_agent_rxptrs[j])(U8*)[13]==0x00 &&
          (g_agent_rxptrs[j])(U8*)[23]==6    &&
          (g_agent_rxptrs[j])(U8*)[34]==0x1F &&
          (g_agent_rxptrs[j])(U8*)[35]==0x91 &&
          (g_agent_rxptrs[j])(U8*)[36]==src_hi &&
          (g_agent_rxptrs[j])(U8*)[37]==src_lo &&
          ip_total_len - 20 - tcp_data_off > 0) {
        body_off = AgBodyOff(g_agent_rxptrs[j], data_off, rx_end);
        if (body_off >= 0) {
          rx = g_agent_rxptrs[j];   // found \r\n\r\n in this segment
        } else {
          if (!rx) rx = g_agent_rxptrs[j];  // save first payload for debugging
          j++;
        }
      } else { j++; }
    }
  }

  if (!rx || body_off < 0) { out_buf[0]=0; return 0; }

  // ── Extract body ──────────────────────────────────────────────────────────
  // data_off, rx_end, body_off are set to the packet where \r\n\r\n was found.
  out_len = 0;
  i = body_off;
  while (i < rx_end && out_len < out_max - 1) {
    out_buf[out_len] = rx[i];
    out_len++;
    i++;
  }
  // SLiRP sometimes splits: headers in seg N, body in seg N+1.
  // If the header segment had 0 body bytes, try the very next slot.
  if (out_len == 0) {
    j++;
    if (j < 8 && AgWaitDD(j)) {
      ip_total_len = ((g_agent_rxptrs[j])(U8*)[16]<<8) | (g_agent_rxptrs[j])(U8*)[17];
      tcp_data_off = ((g_agent_rxptrs[j])(U8*)[46]>>4)*4;
      data_off     = 14 + 20 + tcp_data_off;
      rx_end       = 14 + ip_total_len;
      if (rx_end > 2048) rx_end = 2048;
      if ((g_agent_rxptrs[j])(U8*)[12]==0x08 &&
          (g_agent_rxptrs[j])(U8*)[13]==0x00 &&
          (g_agent_rxptrs[j])(U8*)[23]==6    &&
          (g_agent_rxptrs[j])(U8*)[34]==0x1F &&
          (g_agent_rxptrs[j])(U8*)[35]==0x91 &&
          (g_agent_rxptrs[j])(U8*)[36]==src_hi &&
          (g_agent_rxptrs[j])(U8*)[37]==src_lo &&
          ip_total_len - 20 - tcp_data_off > 0) {
        i = data_off;
        while (i < rx_end && out_len < out_max - 1) {
          out_buf[out_len] = (g_agent_rxptrs[j])(U8*)[i];
          out_len++;
          i++;
        }
      }
    }
  }
  out_buf[out_len] = 0;
  return 1;
}

// ── ARP: resolve gateway MAC (one-time at startup) ───────────────────────────
U0 AgARP() {
  U8 arp_tx[64];
  I64 i, j;

  AgRingReset;

  MemSet(arp_tx, 0, 64);
  arp_tx[0]=0xFF; arp_tx[1]=0xFF; arp_tx[2]=0xFF;
  arp_tx[3]=0xFF; arp_tx[4]=0xFF; arp_tx[5]=0xFF;
  arp_tx[6]=0x52; arp_tx[7]=0x54; arp_tx[8]=0x00;
  arp_tx[9]=0x12; arp_tx[10]=0x34; arp_tx[11]=0x56;
  arp_tx[12]=0x08; arp_tx[13]=0x06;
  arp_tx[14]=0x00; arp_tx[15]=0x01;
  arp_tx[16]=0x08; arp_tx[17]=0x00;
  arp_tx[18]=0x06; arp_tx[19]=0x04;
  arp_tx[20]=0x00; arp_tx[21]=0x01;
  arp_tx[22]=0x52; arp_tx[23]=0x54; arp_tx[24]=0x00;
  arp_tx[25]=0x12; arp_tx[26]=0x34; arp_tx[27]=0x56;
  arp_tx[28]=0x0A; arp_tx[29]=0x00; arp_tx[30]=0x02; arp_tx[31]=0x0F;
  arp_tx[38]=0x0A; arp_tx[39]=0x00; arp_tx[40]=0x02; arp_tx[41]=0x02;

  g_agent_txbase(I64*)[0]       = &arp_tx[0];
  (g_agent_txbase + 8)(I64*)[0] = 42 | (0x0B << 24);
  (g_agent_bar0 + 0x3818)(U32*)[0] = 1;
  Sleep(2000);

  j = 0;
  while (j < 8) {
    if (!AgWaitDD(j)) { j = 8; }
    else if ((g_agent_rxptrs[j])(U8*)[12]==0x08 &&
             (g_agent_rxptrs[j])(U8*)[13]==0x06 &&
             (g_agent_rxptrs[j])(U8*)[21]==2) {
      for (i = 0; i < 6; i++) g_agent_gw_mac[i] = (g_agent_rxptrs[j])(U8*)[22+i];
      j = 8;
    } else { j++; }
  }

  // Fallback: hardcoded SLiRP gateway MAC
  if (!g_agent_gw_mac[0] && !g_agent_gw_mac[1]) {
    g_agent_gw_mac[0]=0x52; g_agent_gw_mac[1]=0x55; g_agent_gw_mac[2]=0x0A;
    g_agent_gw_mac[3]=0x00; g_agent_gw_mac[4]=0x02; g_agent_gw_mac[5]=0x02;
  }
}

// ── Main loop ─────────────────────────────────────────────────────────────────
U0 AgentLoop() {
  U8 get_req[64];
  I64 i, running, body_len, hdr_len, post_len;
  I64 raw, tda, rda;
  I64 http_ok, attempt;

  g_agent_dbg[0] = 0;
  CatPrint(g_agent_dbg, "START\n");

  // ── NIC init ───────────────────────────────────────────────────────────────
  g_agent_bar0 = PCIReadU32(0, 3, 0, 0x10) & 0xFFFFFFF0;
  PCIWriteU16(0, 3, 0, 0x04, 0x0107);
  (g_agent_bar0 + 0x0000)(U32*)[0] = 1 << 26;  // soft reset
  i = 0; while (i < 500000) { i++; }
  (g_agent_bar0 + 0x0000)(U32*)[0] = 0x241;

  // TX ring base
  raw = &g_agent_txring[0]; tda = (raw + 15) & ~15;
  g_agent_txbase = tda;

  // RX ring base
  raw = &g_agent_rxring[0]; rda = (raw + 15) & ~15;
  g_agent_rxbase = rda;

  // Pointer table
  g_agent_rxptrs[0]=&g_agent_rx0[0]; g_agent_rxptrs[1]=&g_agent_rx1[0];
  g_agent_rxptrs[2]=&g_agent_rx2[0]; g_agent_rxptrs[3]=&g_agent_rx3[0];
  g_agent_rxptrs[4]=&g_agent_rx4[0]; g_agent_rxptrs[5]=&g_agent_rx5[0];
  g_agent_rxptrs[6]=&g_agent_rx6[0]; g_agent_rxptrs[7]=&g_agent_rx7[0];

  // ── ARP ────────────────────────────────────────────────────────────────────
  CatPrint(g_agent_dbg, "NIC BAR0=%X\n", g_agent_bar0);
  Print("AgentLoop: NIC init done\n");
  AgARP;
  CatPrint(g_agent_dbg, "ARP %02X%02X%02X%02X%02X%02X\n",
    g_agent_gw_mac[0], g_agent_gw_mac[1], g_agent_gw_mac[2],
    g_agent_gw_mac[3], g_agent_gw_mac[4], g_agent_gw_mac[5]);
  Print("AgentLoop: gw %02X:%02X:%02X:%02X:%02X:%02X  ready\n",
    g_agent_gw_mac[0], g_agent_gw_mac[1], g_agent_gw_mac[2],
    g_agent_gw_mac[3], g_agent_gw_mac[4], g_agent_gw_mac[5]);

  DirMk("C:/AI");

  StrPrint(get_req, "GET /cmd HTTP/1.0\r\nHost: 10.0.2.2\r\n\r\n");

  running = 1;
  attempt = 0;
  while (running) {
    attempt++;

    // ── GET /cmd ─────────────────────────────────────────────────────────────
    g_agent_cmd[0] = 0;
    CatPrint(g_agent_dbg, "GET#%d...\n", attempt);
    http_ok = AgHTTP(get_req, StrLen(get_req), g_agent_cmd, 2048);
    CatPrint(g_agent_dbg, "GET#%d ok=%d cmd0=%d\n", attempt, http_ok, g_agent_cmd[0]);

    if (!g_agent_cmd[0]) {
      // No command queued — idle
      Sleep(500);
    } else if (g_agent_cmd[0]=='E' && g_agent_cmd[1]=='X' &&
               g_agent_cmd[2]=='I' && g_agent_cmd[3]=='T') {
      Print("AgentLoop: EXIT\n");
      running = 0;
    } else {
      // ── Execute command ───────────────────────────────────────────────────
      g_agent_out[0] = 0;
      FileWrite("C:/AI/_cmd.HC", g_agent_cmd, StrLen(g_agent_cmd));
      CatPrint(g_agent_dbg, "CMD:%s|\n", g_agent_cmd);
      try {
        ExeFile("C:/AI/_cmd.HC");
      } catch {
        CatPrint(g_agent_out, "EXCEPT\n");
        Fs->catch_except = TRUE;
      }
      Del("C:/AI/_cmd.HC");
      CatPrint(g_agent_dbg, "OUT[%d]:%s|\n", StrLen(g_agent_out), g_agent_out);

      // ── POST /result ──────────────────────────────────────────────────────
      body_len = StrLen(g_agent_out);
      StrPrint(g_agent_post_hdr,
        "POST /result HTTP/1.0\r\nHost: 10.0.2.2\r\nContent-Length: %d\r\n\r\n",
        body_len);
      hdr_len  = StrLen(g_agent_post_hdr);
      post_len = hdr_len + body_len;
      for (i = 0; i < hdr_len;  i++) g_agent_post_req[i]          = g_agent_post_hdr[i];
      for (i = 0; i < body_len; i++) g_agent_post_req[hdr_len + i] = g_agent_out[i];

      AgHTTP(g_agent_post_req, post_len, g_agent_cmd, 64);
    }
  }

  CatPrint(g_agent_dbg, "EXIT_LOOP run=%d att=%d\n", running, attempt);
  FileWrite("C:/AI/debug.txt", g_agent_dbg, StrLen(g_agent_dbg));
  Print("AgentLoop: done\n");
}

AgentLoop;
