# File Ban List

Files excluded from serial transfer. These files cause timeouts because TempleOS decompresses them on-the-fly via `FileRead`, producing multi-megabyte payloads that exceed transfer limits.

## Banned Files

| File | Reason |
|------|--------|
| `C:/Adam/AutoComplete/ACDefs.DATA` | Autocomplete definition database — decompresses to 2MB+ |
| `C:/Adam/AutoComplete/ACWords.DATA.Z` | Autocomplete word list — decompresses to multi-MB English dictionary |
| `C:/Kernel/Kernel.PRJ.Z` | Project file — transfer timeout |
| `C:/Misc/Bible.TXT.Z` | King James Bible full text — decompresses to multi-MB |
