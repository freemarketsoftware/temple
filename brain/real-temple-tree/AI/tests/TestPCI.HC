// TestPCI.HC — PCI bus enumeration via PCIReadU8/U16/U32 and PCIClassFind
// Detects e1000 NIC (Intel 82540EM, 8086:100E) at bus=0, dev=3, func=0
// Tier 4 — run standalone, NOT included in TestRunner (read-only, low panic risk)
// Results written to C:/AI/results/TestPCI.txt

U0 TestPCI() {
  U8 buf[4096];
  U8 line[256];
  U8 *s;
  U16 vid, did;
  I64 bclass, sclass, v32, found, d, dev_count;

  StrCpy(buf, "suite\tname\tstatus\tdetail\n");

  // --- 1. Host bridge vendor (bus=0, dev=0, func=0, reg=0 = Vendor ID) ---
  vid = PCIReadU16(0, 0, 0, 0);
  if (vid == 0x8086) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestPCI\thostbridge_vendor\t%s\t%X\n", s, vid);
  CatPrint(buf, "%s", line);

  // --- 2. Host bridge device ID (reg=2) ---
  did = PCIReadU16(0, 0, 0, 2);
  if (did == 0x1237) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestPCI\thostbridge_device\t%s\t%X\n", s, did);
  CatPrint(buf, "%s", line);

  // --- 3. e1000 vendor (bus=0, dev=3, func=0, reg=0) ---
  vid = PCIReadU16(0, 3, 0, 0);
  if (vid == 0x8086) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestPCI\te1000_vendor\t%s\t%X\n", s, vid);
  CatPrint(buf, "%s", line);

  // --- 4. e1000 device ID (reg=2) ---
  did = PCIReadU16(0, 3, 0, 2);
  if (did == 0x100E) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestPCI\te1000_device\t%s\t%X\n", s, did);
  CatPrint(buf, "%s", line);

  // --- 5. e1000 base class code (reg=0xB: 0x02 = Network Controller) ---
  bclass = PCIReadU8(0, 3, 0, 0xB);
  if (bclass == 0x02) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestPCI\te1000_baseclass\t%s\t%X\n", s, bclass);
  CatPrint(buf, "%s", line);

  // --- 6. e1000 sub-class code (reg=0xA: 0x00 = Ethernet) ---
  sclass = PCIReadU8(0, 3, 0, 0xA);
  if (sclass == 0x00) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestPCI\te1000_subclass\t%s\t%X\n", s, sclass);
  CatPrint(buf, "%s", line);

  // --- 7. PCIReadU32: combined vendor+device (low16=vendor, high16=device) ---
  v32 = PCIReadU32(0, 3, 0, 0);
  if ((v32 & 0xFFFF) == 0x8086 && ((v32 >> 16) & 0xFFFF) == 0x100E)
    s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestPCI\te1000_u32read\t%s\t%X\n", s, v32);
  CatPrint(buf, "%s", line);

  // --- 8. PCIClassFind: find first network ethernet controller (class=0x020000) ---
  // Returns bus<<16 | dev<<8 | func; expect 0x000300 (bus=0, dev=3, func=0)
  found = PCIClassFind(0x020000, 0);
  if (((found >> 8) & 0xFF) == 3) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestPCI\tclassfind_nic\t%s\t%X\n", s, found);
  CatPrint(buf, "%s", line);

  // --- 9. Bus 0 device count: expect 4 valid slots (0,1,2,3) ---
  dev_count = 0;
  for (d = 0; d < 32; d++) {
    if (PCIReadU16(0, d, 0, 0) != 0xFFFF)
      dev_count++;
  }
  if (dev_count == 4) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestPCI\tbus0_devcount\t%s\t%d\n", s, dev_count);
  CatPrint(buf, "%s", line);

  // --- 10. Empty slot returns 0xFFFF ---
  vid = PCIReadU16(0, 31, 0, 0);
  if (vid == 0xFFFF) s = "PASS"; else s = "FAIL";
  StrPrint(line, "TestPCI\tslot31_empty\t%s\t%X\n", s, vid);
  CatPrint(buf, "%s", line);

  FileWrite("C:/AI/results/TestPCI.txt", buf, StrLen(buf));
  Print("TestPCI done — results in C:/AI/results/TestPCI.txt\n");
}

TestPCI;
