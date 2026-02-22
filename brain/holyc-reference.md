# HolyC Built-in Functions — API Reference

Extracted from TempleOS kernel headers (KernelA/B/C.HH.Z, StrPrint.HC.Z, StrA.HC.Z, KMisc.HC.Z, KMathA.HC.Z, KDate.HC.Z).
Available in the SerReplExe REPL context.

---

## String Manipulation

### Comparison
- `I64 StrCmp(U8 *st1, U8 *st2)` — compare two strings
- `I64 StrICmp(U8 *st1, U8 *st2)` — compare, ignoring case
- `I64 StrNCmp(U8 *st1, U8 *st2, I64 n)` — compare N bytes
- `I64 StrNICmp(U8 *st1, U8 *st2, I64 n)` — compare N bytes, ignoring case
- `U8 *StrMatch(U8 *needle, U8 *haystack)` — scan for string in string
- `U8 *StrIMatch(U8 *needle, U8 *haystack)` — scan for string, ignoring case
- `Bool WildMatch(U8 *test_str, U8 *wild_str)` — wildcard match with `*` and `?`

### Search & Extract
- `U8 *StrFind(U8 *needle, U8 *haystack, I64 flags=0)` — find with options
- `U8 *StrFirstOcc(U8 *src, U8 *marker)` — pointer to 1st occurrence of marker set
- `U8 *StrLastOcc(U8 *src, U8 *marker)` — pointer to last occurrence
- `U8 *StrFirstRem(U8 *src, U8 *marker, U8 *dst=NULL)` — remove first segment
- `U8 *StrLastRem(U8 *src, U8 *marker, U8 *dst=NULL)` — remove last segment
- `I64 StrOcc(U8 *src, I64 ch)` — count occurrences of char

### Formatting & Printing
- `U8 *StrPrint(U8 *dst, U8 *fmt, ...)` — sprintf to buffer
  - **`%f` has no decimal places by default** — use `%.Nf` for N decimals (e.g. `%.2f` → `"3.14"`, `%.6f` → `"3.141593"`)
  - `%e` / `%g` produce scientific notation (e.g. `"3.14000000e0"`)
  - `%d` int, `%X` hex uppercase, `%s` string all work as expected
- `U8 *CatPrint(U8 *dst, U8 *fmt, ...)` — concatenation print
- `U8 *MStrPrint(U8 *fmt, ...)` — malloc'd StrPrint
- `U0 Print(U8 *fmt, ...)` — print to console (screen, not serial)
- `U0 PrintErr(U8 *fmt, ...)` — print "Err:" in blinking red
- `U0 PrintWarn(U8 *fmt, ...)` — print "Warn:" in blinking red

### Conversion
- `I64 Str2I64(U8 *st, I64 radix=10, U8 **_end_ptr=NULL)` — string to I64
- `F64 Str2F64(U8 *src, U8 **_end_ptr=NULL)` — string to F64
- `U8 *StrScan(U8 *src, U8 *fmt, ...)` — scanf from string

### Utilities
- `U0 StrCpy(U8 *dst, U8 *src)` — copy string
- `I64 StrLen(U8 *st)` — string length
- `U8 *StrNew(U8 *buf, CTask *mem_task=NULL)` — allocate new string
- `U8 *MStrUtil(U8 *src, I64 flags, F64 indent_scale_factor=0)` — malloc'd string transform
- `I64 LstMatch(U8 *needle, U8 *haystack_lst, I64 flags=0)` — match in list (-1 not found, -2 ambiguous)
- `U8 *LstSub(I64 sub, U8 *lst)` — pointer to list entry N

---

## Math

### Basic
- `F64 Abs(F64 d)` / `I64 AbsI64(I64 i)` — absolute value
- `I64 MaxI64(I64 n1, I64 n2)` / `I64 MinI64(I64 n1, I64 n2)` — min/max
- `U64 MaxU64(U64 n1, U64 n2)` / `U64 MinU64(U64 n1, U64 n2)` — unsigned min/max
- `I64 SignI64(I64 i)` / `F64 Sign(F64 d)` — sign: -1, 0, 1
- `I64 ClampI64(I64 num, I64 lo, I64 hi)` — clamp to range

### Rounding
- `F64 Round(F64 d)` / `F64 Floor(F64 d)` / `F64 Ceil(F64 d)` / `F64 Trunc(F64 d)`

### Trig
- `F64 Sin(F64 d)` / `F64 Cos(F64 d)` / `F64 Tan(F64 d)` / `F64 ATan(F64 d)`
- `F64 Arg(F64 x, F64 y)` — polar angle

### Exponential / Logarithmic
- `F64 Exp(F64 d)` / `F64 Ln(F64 d)` / `F64 Log2(F64 d)` / `F64 Log10(F64 d)`
- `F64 Pow(F64 base, F64 power)` / `F64 Sqrt(F64 d)`

### Type Conversion
- `F64 ToF64(I64 i)` / `I64 ToI64(F64 d)`

### Bit Operations
- `I64 Bsf(I64 val)` — bit scan forward (lowest set bit, -1 if none)
- `I64 Bsr(I64 val)` — bit scan reverse (highest set bit)
- `Bool Bt(U8 *field, I64 bit)` — test bit
- `Bool Bts(U8 *field, I64 bit)` — test and set
- `Bool Btr(U8 *field, I64 bit)` — test and reset
- `Bool Btc(U8 *field, I64 bit)` — test and complement
- `Bool LBts/LBtr/LBtc(...)` — locked (atomic) variants
- `I64 BCnt(I64 d)` — count set bits

### 3D Vector
- `CD3 *D3Add/D3Sub/D3Mul/D3Div/D3Cross/D3Dot/D3Norm/D3Unit(...)` — full 3D vector library

### Constants
- `pi`, `exp_1` (e), `inf`, `sqrt2`, `log2_10`, `log2_e`, `log10_2`, `loge_2`

---

## Memory

- `U8 *MemCpy(U8 *dst, U8 *src, I64 cnt)` — copy memory
- `I64 MemCmp(U8 *ptr1, U8 *ptr2, I64 cnt)` — compare memory
- `U8 *MemSet(U8 *dst, I64 val, I64 cnt)` — set bytes
- `I64 *MemSetI64(I64 *dst, I64 val, I64 cnt)` — set I64s
- `U16 EndianU16(U16 d)` / `U32 EndianU32(U32 d)` / `I64 EndianI64(I64 d)` — endian swap

---

## Date/Time

- `CDate Now()` — current datetime
- `U0 NowDateTimeStruct(CDateStruct *_ds)` — current date/time as struct
- `F64 tS()` — seconds since boot (float)
- `Bool Blink(F64 Hz=2.5)` — alternates TRUE/FALSE at given frequency
- `U0 Sleep(I64 mS)` — sleep milliseconds
- `U0 Busy(I64 µS)` — busy-wait microseconds
- `I64 GetTSC()` — read timestamp counter
- `I64 SysTimerRead()` — system timer with overflow handling
- `I64 DayOfWeek(I64 i)` — day of week from 32-bit day since AD 0
- `I64 FirstDayOfMon(I64 i)` / `I64 LastDayOfMon(I64 i)`
- `I64 YearStartDate(I64 year)`

---

## File I/O

- `U8 *FileRead(U8 *filename, I64 *_size=NULL, I64 *_attr=NULL)` — read whole file (decompresses .Z)
- `I64 FileWrite(U8 *filename, U8 *fbuf, I64 size, ...)` — write whole file
- `Bool FileFind(U8 *filename, CDirEntry *_de=NULL, I64 flags=0)` — find file
- `CDirEntry *FilesFind(U8 *mask, I64 flags=0)` — find files matching mask
- `CFile *FOpen(U8 *filename, U8 *flags, I64 cnt=0)` — open file handle
- `U0 FClose(CFile *f)` — close file handle
- `I64 FSize(CFile *f)` — get file size
- `Bool FBlkRead(CFile *f, U8 *buf, I64 blk=FFB_NEXT_BLK, I64 cnt=1)` — read blocks
- `Bool FBlkWrite(CFile *f, U8 *buf, I64 blk=FFB_NEXT_BLK, I64 cnt=1)` — write blocks
- `U8 *FileNameAbs(U8 *filename, I64 flags=0)` — absolute path
- `U8 *FileExtRem(U8 *src, U8 *dst=NULL)` — remove extension
- `U8 *ExtChg(U8 *filename, U8 *extension)` — change extension

---

## Directory

- `Bool Cd(U8 *dirname=NULL, Bool make_dirs=FALSE)` — change directory
- `U8 *DirCur(CTask *task=NULL, ...)` — get current directory
- `Bool DirMk(U8 *filename, I64 entry_cnt=0)` — make directory
- `Bool IsDir(U8 *dir_name)` — check if path is directory
- `I64 Del(U8 *mask, Bool make_mask=FALSE, I64 flags=0)` — delete files/dirs
- `I64 Dir(U8 *mask="*", Bool full=FALSE)` — list directory (to screen)
- `U8 *DirNameAbs(U8 *dirname)` — absolute directory path
- `CDirContext *DirContextNew(U8 *mask, Bool make_abs=TRUE, ...)` — directory context

---

## Sound

- `U0 Snd(I8 ona=ONA_REST)` — play sound (piano key number, 60=A440)
- `U0 SndRst()` — stop stuck sound
- `U0 Beep(I8 ona=62, Bool busy=FALSE)` — beep
- `Bool Mute(Bool val)` — mute/unmute
- `U8 Ona2Freq(I8 ona)` — piano key to frequency
- `I8 Freq2Ona(F64 freq)` — frequency to piano key

---

## Compression

- `CArcCompress *CompressBuf(U8 *src, I64 size, ...)` — compress buffer
- `U8 *ExpandBuf(CArcCompress *arc, ...)` — decompress buffer

---

## Queue / Data Structures

- `U0 QueInit(CQue *head)` — initialize queue
- `U0 QueIns(CQue *entry, CQue *pred)` — insert after predecessor
- `U0 QueRem(CQue *entry)` — remove from queue
- `I64 QueCnt(CQue *head)` — count items
- `CFifoI64 *FifoI64New(I64 size, ...)` / `Bool FifoI64Ins/Rem/Peek(...)` — I64 FIFO
- `CFifoU8 *FifoU8New(I64 size, ...)` / `Bool FifoU8Ins/Rem/Peek(...)` — U8 FIFO

---

## CPU / Hardware

### I/O Ports
- `U8 InU8(I64 port)` / `U16 InU16(I64 port)` / `U32 InU32(I64 port)` — read port
- `U0 OutU8(I64 port, I64 val)` / `U16 OutU16(...)` / `U32 OutU32(...)` — write port
- `U0 RepInU8/RepInU16/RepInU32(U8 *buf, I64 cnt, I64 port)` — repeated read
- `U0 RepOutU8/RepOutU16/RepOutU32(U8 *buf, I64 cnt, I64 port)` — repeated write

### Atomic / Locking
- `I64 LXchgI64(I64 *dst, I64 d)` — locked exchange
- `Bool LBts/LBtr/LBtc(U8 *field, I64 bit)` — locked bit ops

### Info
- `CCPU *Gs()` — current CPU struct (via GS register)
- `CTask *Fs()` — current task struct (via FS register)
- `I64 mp_cnt` — number of CPU cores
- `U0 CPUId(U32 rax, CRAXRBCRCXRDX *res)` — CPUID instruction

### Registers
- `I64 GetRAX()` / `U0 SetRAX(I64 d)`
- `U8 *GetRBP()` / `U8 *GetRSP()`
- `I64 GetRFlags()` / `U0 SetRFlags(I64 d)`
- `I64 Pop()` / `U0 Push(I64 d)`

---

## Debugging

- `U0 D(U8 *addr, I64 cnt=0x80)` — disassemble
- `U0 Dm(U8 *addr, I64 cnt=0x80)` — dump memory
- `U0 Dr(CTask *task=NULL)` — display registers
- `U0 StkRep(CTask *task=NULL)` — stack report
- `Bool B(U8 *addr, ...)` — toggle breakpoint
- `U0 Break()` — break into debugger
- `U8 *Caller(I64 num=1)` — get caller function name
- `Bool ChkPtr(U8 *ptr)` — check pointer validity
- `U0 Panic(U8 *msg=NULL, ...)` — panic/halt
- `I64 UnusedStk(CTask *task=NULL)` — unused stack space

---

## System

- `U0 Reboot()` — reboot
- `U0 SysHlt()` — halt (HLT loop)
- `Bool Silent(Bool val=ON)` — suppress stdout
- `Bool DbgMode(Bool val)` — debug mode
- `U0 AdamLog(U8 *fmt, ...)` — log to Adam task
- `U0 throw(I64 ch=0, Bool no_log=FALSE)` — throw exception
- `U8 *Define(U8 *dname)` — look up define value
- `U8 *Load(U8 *filename, I64 flags=0, ...)` — load/execute program file
- `CDate sys_compile_time` — when kernel was compiled
- `U32 sys_run_level` — system run level

---

## Important Constants

```
NULL = 0        TRUE = 1        FALSE = 0
ON = 1          OFF = 0         INVALID_PTR = I64_MAX

I64_MIN = -0x8000000000000000   I64_MAX = 0x7FFFFFFFFFFFFFFF
U64_MAX = 0xFFFFFFFFFFFFFFFF    U32_MAX = 0xFFFFFFFF
I32_MIN = -0x80000000           I32_MAX = 0x7FFFFFFF
U8_MAX  = 0xFF                  I8_MIN  = -0x80

pi    = 3.14159...    exp_1 = 2.71828...    inf = infinity
sqrt2 = 1.41421...    eps   = machine epsilon
```

---

## Notes

- `U0` = void, `I64` = 64-bit signed, `U64` = 64-bit unsigned, `U8 *` = string pointer, `Bool` = 0/1, `F64` = double
- `Print()` goes to TempleOS screen — use `GStrAdd()`/`StrPrint(g_str,...)` + `SerSendStr()` for serial output
- `FileRead()` auto-decompresses `.HC.Z` files — output is readable HolyC source
- All memory is in a single flat address space — pointer arithmetic works everywhere
- `StrLen`, `StrCmp`, `StrCpy` are confirmed available in REPL context (used by SerReplExe)
