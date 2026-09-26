---
name: reverse-engineer
description: "Reverse engineering — binary analysis, APK/IPA decompile, deobfuscation, protocol analysis, license bypass, firmware extraction. Tools: Ghidra, IDA, jadx, apktool, strings, ltrace/strace."
---

# Reverse Engineering Reference

## 1. ANDROID APK

```bash
# Decompile APK ke smali
apktool d app.apk -o app_decompiled/

# Recompile
apktool b app_decompiled/ -o app_modified.apk

# Decompile ke Java source (lebih readable)
jadx -d output_dir/ app.apk

# Extract APK contents
unzip app.apk -d app_contents/

# Grep untuk sensitive data
grep -r "password\|passwd\|secret\|api_key\|token" app_contents/
strings app_contents/classes.dex | grep -i "http\|api\|key\|pass"
```

## 2. IOS IPA

```bash
# Extract IPA
unzip app.ipa -d app_contents/

# Dump binary
otool -L Payload/App.app/App    # Dependencies
strings Payload/App.app/App     # Strings
nm Payload/App.app/App          # Symbols
```

## 3. BINARY ANALYSIS

```bash
# Static analysis tools
strings binary          # Semua strings
file binary             # Tipe file
readelf -a binary       # ELF info (Linux)
objdump -d binary       # Disassembly
nm -a binary            # Symbols

# Ghidra (GUI disassembler/decompiler)
ghidra &

# IDA Pro (commercial)
ida binary

# Radare2 (command-line)
r2 binary
> aaaa          # Analyze
> afl           # List functions
> pdf @ main    # Disassemble main
> VV            # Visual mode
```

## 4. DYNAMIC ANALYSIS

```bash
# Linux
strace ./binary     # System calls
ltrace ./binary     # Library calls
gdb ./binary        # Debugger

# GDB commands
gdb ./binary
(gdb) break main
(gdb) run
(gdb) info registers
(gdb) x/20x $rsp    # Memory dump
(gdb) step / next

# pwndbg (enhanced GDB)
git clone https://github.com/pwndbg/pwndbg
source /path/to/pwndbg/gdbinit.py
```

## 5. OBFUSCATION BYPASS

### Java/Android
```java
// Proguard obfuscated: a.b.c() → real function
// jadx biasanya bisa deobfuscate sebagian

// Jika ada custom obfuscator, trace di Frida:
Java.perform(function() {
    // Hook semua method calls
    var Class = Java.use('java.lang.Class');
    Class.forName.implementation = function(name) {
        console.log('[*] Class.forName: ' + name);
        return this.forName(name);
    };
});
```

### PHP Encoded/Obfuscated
```bash
# ionCube decode: online decoder tools
# Zend Guard: commercial decoder

# Manual: find eval/base64_decode chains
grep -r "base64_decode\|eval\|gzinflate\|str_rot13" src/
php -r "echo base64_decode('...');"  # Quick decode
```

## 6. LICENSE BYPASS PATTERNS

```bash
# Cari validasi license di binary
strings binary | grep -i "license\|expir\|trial\|register\|serial"

# Patch binary: NOP (0x90 di x86) instruksi validasi
# Atau patch jump: JNZ (0x75) → JZ (0x74) untuk flip logic

# Dengan Ghidra: 
# 1. Find license check function
# 2. Patch conditional jump
# 3. Export patched binary
```

## 7. NETWORK PROTOCOL ANALYSIS

```bash
# Wireshark capture
tcpdump -i any -w capture.pcap
wireshark capture.pcap

# Decode custom protocols
# 1. Capture traffic
# 2. Identify pattern (magic bytes, length fields)
# 3. Implement parser
# 4. Fuzz protocol fields

# Scapy untuk custom protocol testing
from scapy.all import *
```

## 8. FIRMWARE EXTRACTION

```bash
# Binwalk: extract komponen dari firmware
binwalk firmware.bin          # Identify
binwalk -e firmware.bin       # Extract
binwalk -M -e firmware.bin    # Recursive extract

# Setelah extract:
ls _firmware.bin.extracted/
# Biasanya ada: squashfs, jffs2, cramfs filesystem
unsquashfs squashfs.img

# Cari credentials di filesystem
grep -r "password\|passwd\|admin" squashfs-root/etc/
cat squashfs-root/etc/passwd
cat squashfs-root/etc/shadow
```

## 9. TOOLS REFERENSI

| Tool | Fungsi |
|------|--------|
| jadx | APK → Java decompile |
| apktool | APK smali decompile/recompile |
| Ghidra | NSA disassembler/decompiler (free) |
| IDA Pro | Industry standard RE tool |
| Radare2 | CLI-based RE framework |
| Binary Ninja | Modern RE platform |
| x64dbg | Windows debugger |
| OllyDbg | Windows debugger (old) |
| binwalk | Firmware analysis |
| strings | Extract strings from binary |
| pwndbg | Enhanced GDB |
