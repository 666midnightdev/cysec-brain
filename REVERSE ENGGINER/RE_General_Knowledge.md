# Reverse Engineering — Pengetahuan Umum
> Disusun oleh Claude Sonnet 4.6 | 2026-09-26

---

## 1. Filosofi & Mindset RE

- **Tujuan RE**: Memahami cara kerja sebuah sistem tanpa akses ke source code. Bisa untuk: keamanan, interoperabilitas, CTF, malware analysis, protokol proprietary, DRM bypass (legal/research).
- **Hukum besi**: Semua obfuscation adalah penundaan, bukan pencegahan. Cukup waktu dan motivasi → semua bisa di-RE.
- **Pendekatan**: Top-down (mulai dari behavior, turun ke detail) lebih efisien dari bottom-up (baca assembly dari bawah).
- **Dokumentasi saat jalan**: Beri nama ulang fungsi/variabel di IDA/Ghidra segera saat paham. Nama `sub_401234` → `decrypt_session_key` menghemat jam kerja.

---

## 2. Tools Utama

### Static Analysis
| Tool | Platform | Kegunaan |
|------|----------|----------|
| **IDA Pro** | Win/Linux/Mac | Disassembler + decompiler (Hex-Rays) terbaik, komersial |
| **Ghidra** | Cross-platform | NSA open-source, decompiler gratis, plugin ekosistem besar |
| **Binary Ninja** | Cross-platform | Decompiler komersial, API Python kuat |
| **radare2 / cutter** | Cross-platform | CLI powerful, gratis, cutter = GUI-nya |
| **strings** / **floss** | CLI | Ekstrak printable strings; FLOSS juga de-obfuscate stack strings |
| **binwalk** | CLI | Firmware analysis, cari embedded filesystems |
| **file / xxd / hexdump** | CLI | Identifikasi format, lihat raw bytes |

### Dynamic Analysis
| Tool | Platform | Kegunaan |
|------|----------|----------|
| **x64dbg / x32dbg** | Windows | Debugger user-mode terbaik untuk Windows PE |
| **WinDbg** | Windows | Kernel + user debug, crash dump analysis |
| **GDB + pwndbg/peda** | Linux | Debugger Linux, extension untuk pwn |
| **Frida** | Cross-platform | Dynamic instrumentation, hook fungsi di runtime (JS API) |
| **Objection** | Mobile | Frida wrapper untuk mobile RE, bypass SSL pinning |
| **LLDB** | Mac/iOS | Debugger Apple |
| **PIN / DynamoRIO** | Cross-platform | Binary instrumentation framework |

### Network / Protocol
| Tool | Kegunaan |
|------|----------|
| **Wireshark** | Packet capture + dissector custom |
| **mitmproxy** | HTTP/HTTPS MITM, scripting Python |
| **Burp Suite** | HTTP proxy, repeater, scanner |
| **scapy** | Python: bangun/kirim/parse paket custom |
| **Caido** | Modern Burp alternative |

### Mobile (Android/iOS)
| Tool | Kegunaan |
|------|----------|
| **jadx** | Decompile APK → Java/Kotlin |
| **apktool** | Unpack/repack APK, smali disassembly |
| **dex2jar + JD-GUI** | DEX → JAR → Java |
| **apksigner / jarsigner** | Re-sign APK setelah patch |
| **objection** | Runtime hook tanpa root (via Frida) |
| **MobSF** | Static + dynamic analysis framework |
| **Reflutter** | Patch Flutter app untuk enable observatory |
| **reFlutter / blutter** | Flutter-specific RE tools |

---

## 3. Teknik Static Analysis

### Identifikasi awal
```
file <binary>          # tipe file, arch, stripped/not
strings -a <binary>    # semua printable strings
readelf -h <elf>       # ELF header info
objdump -d <bin>       # disassembly
```

### Cari Entry Point
- PE: `AddressOfEntryPoint` di Optional Header
- ELF: `e_entry`
- Biasanya IDA/Ghidra auto-deteksi, tapi kalau packed → entry point = unpacker stub

### Identifikasi Packing / Obfuscation
- **Tanda packing**: entropy tinggi (> 7.0), section names aneh, import table minimal (hanya LoadLibrary + GetProcAddress)
- **Tools**: `PEiD`, `Detect-It-Easy (DIE)`, `ExeinfoPE`
- **Teknik unpack**: jalankan di debugger → tunggu OEP (Original Entry Point) → dump memory

### Pattern Recognition
- Library functions: IDA FLIRT signatures, Ghidra PDB import
- Crypto: cari konstanta magic — AES S-box (`0x63`...), SHA `0x67452301`, RC4 init loop
- String XOR: lihat `xor [reg], const` dalam loop dekat string load
- Anti-debug: `IsDebuggerPresent`, `CheckRemoteDebuggerPresent`, `NtQueryInformationProcess`

---

## 4. Teknik Dynamic Analysis

### Debugging Tips
- **Hardware breakpoints** (HW BP) tidak terdeteksi anti-debug via memory (hanya 4 slot: DR0-DR3)
- **Memory breakpoints** (guard page) lebih tersembunyi dari `0xCC` software BP
- **Conditional BP**: break hanya jika `EAX == 0` — hemat waktu untuk loop panjang
- **Trace / step-over** fungsi library yang sudah dikenal, step-into untuk fungsi custom

### Anti-Anti-Debug Umum
| Teknik Anti-Debug | Bypass |
|-------------------|--------|
| `IsDebuggerPresent` | Patch PEB.BeingDebugged = 0, atau hook |
| `NtQueryInformationProcess` | Hook → return false |
| Timing check (`RDTSC` delta) | Patch/NOP check, atau accelerate dengan fake RDTSC |
| Parent process check | Spoof parent PID via `UpdateProcThreadAttribute` |
| Exception-based (`UnhandledExceptionFilter`) | Set debugger to pass exceptions |
| Checksum self-integrity | Patch checksum routine, atau NOP |

### Frida Quick-Start
```javascript
// Attach ke proses
frida -U -n com.example.app -l script.js

// Hook fungsi Java di Android
Java.perform(function() {
    var Cls = Java.use("com.example.Crypto");
    Cls.decrypt.implementation = function(data, key) {
        console.log("decrypt called, key=" + key);
        var result = this.decrypt(data, key);
        console.log("result=" + result);
        return result;
    };
});

// Hook native function
Interceptor.attach(Module.findExportByName("libc.so", "strlen"), {
    onEnter: function(args) { console.log("strlen: " + args[0].readUtf8String()); }
});

// Read memory
var addr = ptr("0x12345678");
console.log(hexdump(addr, { length: 64 }));
```

---

## 5. Crypto RE

### Identifikasi Algoritma Crypto
- **Magic constants** di binary:
  - AES S-box: `0x63, 0x7c, 0x77, 0x7b...` (lookup table 256 bytes)
  - SHA-256: `0x6a09e667, 0xbb67ae85, 0x3c6ef372...`
  - MD5: `0x67452301, 0xEFCDAB89, 0x98BADCFE...`
  - RC4: linear array init `0,1,2,...,255`
  - ChaCha20: `"expa"`, `"nd 3"`, `"2-by"`, `"te k"` (magic dwords)
- **Tools**: `findcrypt` (IDA plugin), `Capa` (malware capabilities), `yara` rules

### AES CBC Reverse
```
Ciphertext = AES_CBC_Encrypt(Plaintext, Key, IV)
Plaintext  = AES_CBC_Decrypt(Ciphertext, Key, IV)
```
- Cari: key schedule (key expansion), MixColumns (matrix multiply in GF(2^8))
- Zero-pad vs PKCS7: cek padding byte terakhir (`\x10\x10...` = PKCS7, `\x00\x00...` = zero-pad)
- IV sering hardcoded di binary atau dikirim bersama ciphertext (biasanya 16 byte pertama)

### Custom XOR / Substitution
```python
# Brute force single-byte XOR key
for key in range(256):
    plain = bytes(b ^ key for b in cipher)
    if is_ascii(plain): print(hex(key), plain)

# Cari repeating XOR key length (Kasiski / IC)
from scipy.spatial.distance import hamming
def find_keylen(ct, maxlen=40):
    scores = {}
    for kl in range(2, maxlen):
        chunks = [ct[i:i+kl] for i in range(0, min(len(ct), kl*4), kl)]
        dists = [bin(int.from_bytes(a,'big')^int.from_bytes(b,'big'),'bin').count('1')
                 for a,b in zip(chunks, chunks[1:])]
        scores[kl] = sum(dists) / len(dists) / kl
    return min(scores, key=scores.get)
```

### RSA Quick Notes
- Kunci publik di binary = `e` (biasanya `0x10001 = 65537`) + `n`
- Kalau `n` kecil (< 1024 bit) → factordb.com bisa faktorkan
- Cek `openssl rsa -in key.pem -text -noout` untuk lihat komponen

---

## 6. Android APK RE

### Workflow Dasar
```bash
# Unpack APK
apktool d app.apk -o output/

# Struktur penting:
# output/smali/           → bytecode Dalvik dalam format smali
# output/res/             → resources
# output/AndroidManifest.xml → permissions, activities, services
# output/lib/             → native .so files

# Decompile ke Java (lebih readable)
jadx -d jadx_out/ app.apk

# Re-pack + sign
apktool b output/ -o patched.apk
apksigner sign --ks debug.keystore patched.apk
```

### Bypass SSL Pinning
```javascript
// Frida script bypass certificate pinning
Java.perform(function() {
    // Method 1: TrustManager override
    var TrustManager = Java.registerClass({
        name: 'com.custom.TM',
        implements: [Java.use('javax.net.ssl.X509TrustManager')],
        methods: {
            checkClientTrusted: function(chain, authType) {},
            checkServerTrusted: function(chain, authType) {},
            getAcceptedIssuers: function() { return []; }
        }
    });
    // Method 2: OkHttp CertificatePinner bypass
    var CertificatePinner = Java.use('okhttp3.CertificatePinner');
    CertificatePinner.check.overload('java.lang.String', 'java.util.List').implementation = function() {
        return;
    };
});
```

### Flutter App RE
- Flutter mengcompile Dart ke native code (tidak bisa di-decompile langsung ke Dart)
- **blutter**: tools khusus untuk extract symbols dari Flutter app `libapp.so`
- **Reflutter**: patch `libflutter.so` untuk enable observatory (debug mode)
- Traffic MITM: Flutter punya custom SSL stack, butuh patch binary atau frida hook ke `ssl_crypto_x509_session_verify_cert_chain`

---

## 7. Protocol RE (Binary / Proprietary)

### Pendekatan
1. **Collect samples**: tangkap banyak request/response untuk pola berbeda
2. **Find delimiters**: cari byte sequence yang selalu muncul sebagai separator (length field, magic bytes)
3. **Vary one input at a time**: ubah satu field → lihat apa yang berubah di packet
4. **Correlation**: field mana yang berkorelasi dengan input user?
5. **Crypto detection**: kalau output berubah drastis untuk input mirip → mungkin ada enkripsi/hash

### Format Analysis Tools
```python
# Hitung entropy per-byte untuk deteksi enkripsi
import math
def entropy(data):
    freq = [data.count(b)/len(data) for b in set(data)]
    return -sum(p * math.log2(p) for p in freq)

# Entropy > 7.5 → kemungkinan encrypted/compressed
# Entropy 3-5 → kemungkinan plaintext/structured
```

### HTTP API RE (seperti OkeLink)
- Cari field yang panjangnya kelipatan 16/32 → kemungkinan AES block
- Field panjang tetap → kemungkinan fixed-size encrypt atau hash
- Coba kirim nilai diketahui → decrypt → petakan field
- Perhatikan urutan field (order dalam form-encoded kadang penting)
- Cek User-Agent, header custom yang mungkin ada validasi di server

---

## 8. Windows PE / Malware Analysis

### PE Structure
```
DOS Header (MZ) → PE Header (PE\0\0) → Optional Header
  → Section Table → Sections (.text .data .rsrc .pdata etc)
Import Table: DLL + function yang dipanggil
Export Table: fungsi yang diekspos
Resources: icon, string, dialog, version info
```

### Tools Analisis Malware
- **PEStudio**: one-stop PE analysis (imports, strings, entropy, indicators)
- **Capa**: deteksi capabilities malware otomatis
- **CAPE / Any.run / Hybrid Analysis**: sandbox online
- **Volatility**: memory forensics dari dump
- **YARA**: tulis rule untuk signature detection

### Common Malware Patterns
| Pattern | Indikator |
|---------|-----------|
| Process injection | `VirtualAllocEx`, `WriteProcessMemory`, `CreateRemoteThread` |
| DLL injection | `LoadLibrary` + temp path |
| Hollowing | `NtUnmapViewOfSection`, `ZwMapViewOfSection` |
| Keylogger | `SetWindowsHookEx(WH_KEYBOARD)` |
| Screenshot | `BitBlt`, `GetDC(NULL)` |
| Persistence | registry `Run` keys, scheduled tasks, services |
| C2 | `WinHttpOpen`, `InternetOpen`, Base64 strings |

---

## 9. CTF RE Tips

### Binary Exploitation Entry
```bash
# Cek proteksi binary
checksec --file=binary
# NX (no-exec stack), PIE (ASLR), Stack Canary, RELRO

# Quick wins
strings binary | grep -i flag
ltrace ./binary   # library call trace
strace ./binary   # syscall trace
gdb binary -ex 'run' -ex 'bt'  # lihat crash point
```

### Angr (Symbolic Execution)
```python
import angr
proj = angr.Project('./crackme', auto_load_libs=False)
state = proj.factory.entry_state(args=['./crackme', 'AAAA'])
sm = proj.factory.simulation_manager(state)
# Cari state yang mencapai "win" function, hindari "fail"
sm.explore(find=0x401234, avoid=0x401567)
print(sm.found[0].posix.dumps(0))  # stdin yang mencapai "win"
```

### Z3 (SMT Solver untuk Constraint Solving)
```python
from z3 import *
x = BitVec('x', 32)
s = Solver()
s.add(x * 0x1337 == 0xDEADBEEF)  # constraint dari binary
if s.check() == sat:
    print(s.model())
```

---

## 10. Frida Cheatsheet

```javascript
// List loaded modules
Process.enumerateModules().forEach(m => console.log(m.name, m.base));

// Find function by name
var addr = Module.findExportByName("libssl.so", "SSL_read");

// Read/write memory
Memory.readByteArray(ptr("0x1234"), 16);
Memory.writeByteArray(ptr("0x1234"), [0x90, 0x90]);  // NOP

// Stalk (code coverage)
Stalker.follow(Process.getCurrentThreadId(), {
    events: { call: true, ret: false },
    onReceive: function(events) { /* ... */ }
});

// Intercept syscall (Linux)
Interceptor.attach(Module.findExportByName(null, "open"), {
    onEnter: function(args) { console.log("open:", args[0].readUtf8String()); }
});

// Java class enumeration
Java.enumerateLoadedClasses({ onMatch: function(name) { console.log(name); } });

// Find instance of class
Java.choose("com.example.SecretManager", {
    onMatch: function(inst) { console.log("key:", inst.getKey()); }
});
```

---

## 11. Referensi & Sumber Belajar

### Online
- **https://crackmes.one** — latihan crackme
- **https://reversing.kr** — RE challenges
- **https://pwn.college** — binary exploitation + RE
- **https://book.rada.re** — radare2 book
- **https://hex-rays.com/tutorials** — IDA tutorial resmi

### Buku
- *The IDA Pro Book* — Chris Eagle
- *Practical Malware Analysis* — Sikorski & Honig
- *Hacking: The Art of Exploitation* — Jon Erickson
- *The Art of Software Security Assessment* — Dowd, McDonald, Schuh

### YouTube / Course
- LiveOverflow (binary exploitation + RE)
- OALabs (malware analysis)
- **pwn.college** (structured curriculum)
- Malware Unicorn workshops (free)

---

*File ini adalah referensi cepat. Untuk topik spesifik, tanya Claude langsung.*
