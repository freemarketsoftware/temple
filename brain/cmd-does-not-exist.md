# TempleOS Commands / Functions That Do NOT Exist

Confirmed undefined in TempleOS — do not use these.

## String Execution
| Name | What we tried | Error |
|------|--------------|-------|
| `Eval(str)` | Execute arbitrary HolyC string | `Undefined identifier` |
| `ExeStr(str)` | Execute arbitrary HolyC string | `Undefined identifier` |

## Directory / File
| Name | What we tried | Correct alternative |
|------|--------------|---------------------|
| `MkDir(path)` | Create directory | Use `DirMk(path)` |
| `MakeDir(path)` | Create directory | Use `DirMk(path)` |
| `DirFirst(pattern)` | Iterate directory entries | Unknown — see `brain/serdir.md` |
| `DirNext(entry)` | Get next directory entry | Unknown — see `brain/serdir.md` |
| `FilesNext(entry)` | Get next FilesFind entry | Unknown — see `brain/serdir.md` |

## I/O
| Name | What we tried | Error |
|------|--------------|-------|
| `FOpen(path)` | Open file handle | `Undefined identifier` |
| `FPrint(handle, fmt)` | Print to file | `Undefined identifier` |
| `Cls` | Clear terminal | Use `DocClear(DocPut)` |

## Syntax / Operators
| Name | What we tried | Correct alternative |
|------|--------------|---------------------|
| `(Type)value` | C-style typecast | Use TempleOS postfix: `value(Type)` |
| `!expr` | Logical NOT | Use `\!expr` |
| `!=` | Not-equal | Use `\!=` |
| `\"` in REPL strings | Escaped quote in FileWrite | Build string byte-by-byte or use `Ed` |
