---
name: ip-rotate-anti-ban
description: "Teknik rotasi IP dan anti-ban — Tor circuit rotation, proxy chains, residential proxy, header spoofing. Gunakan saat target melakukan rate-limiting, IP ban, atau WAF yang mendeteksi burst requests."
---

# IP Rotate & Anti-Ban Reference

## 1. TOR CIRCUIT ROTATION

### Setup Tor di WSL/Linux
```bash
# Install
apt install -y tor

# Start Tor
tor --RunAsDaemon 1 --CookieAuthentication 1 \
    --CookieAuthFile /tmp/tor-control.authcookie \
    --ControlPort 9051 --SocksPort 9050

# Verify
curl --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip
```

### Circuit Rotation via Control Port
```python
import socket, time

def rotate_tor(authcookie_path='/tmp/tor-control.authcookie',
               control_port=9051, delay=14):
    """Rotate Tor circuit (NEWNYM signal)"""
    try:
        # Baca authcookie
        authcookie = open(authcookie_path, 'rb').read()
        
        # Connect ke control port
        c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        c.settimeout(5)
        c.connect('/run/tor/control')  # atau TCP: socket.connect(('127.0.0.1', 9051))
        
        # Authenticate dan kirim NEWNYM
        c.send(f'AUTHENTICATE {authcookie.hex()}\r\nSIGNAL NEWNYM\r\nQUIT\r\n'.encode())
        response = c.recv(200)
        c.close()
        
        time.sleep(delay)  # Tunggu circuit baru ready (minimal 10-14 detik)
        return True
    except Exception as e:
        print(f"Tor rotation error: {e}")
        return False

# Alternatif: via TCP control port
def rotate_tor_tcp(host='127.0.0.1', port=9051, password=None):
    c = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    c.connect((host, port))
    if password:
        c.send(f'AUTHENTICATE "{password}"\r\n'.encode())
    else:
        c.send(b'AUTHENTICATE\r\n')
    c.send(b'SIGNAL NEWNYM\r\nQUIT\r\n')
    c.recv(200)
    c.close()
    time.sleep(14)
```

### Python Requests via Tor
```python
import requests

TOR_PROXIES = {
    "http": "socks5h://127.0.0.1:9050",
    "https": "socks5h://127.0.0.1:9050"
}
# socks5h = resolve DNS via Tor (anti-DNS leak)
# socks5  = resolve DNS locally

session = requests.Session()
session.proxies = TOR_PROXIES

r = session.get('https://target.com', verify=False, timeout=30)
print(r.status_code)
```

### Masalah Umum Tor
| Masalah | Solusi |
|---------|--------|
| Timeout tinggi (>30s) | Tor relay lambat; rotate circuit |
| 429 Too Many Requests | Tunggu lebih lama atau rotate lebih sering |
| TARPIT (WAF hold) | Global rule, bukan IP-specific — rotate tidak membantu |
| Exit node banned | Rotate circuit, atau gunakan bridge |
| Koneksi gagal | Restart Tor: `service tor restart` |

### Tor Rate Limiting
```python
# SafeLine Global Tarpit → TIDAK bisa dihindari dengan rotate
# SafeLine Rate Limit 429 → BISA dihindari dengan rotate

ROTATE_AFTER_N = 5   # rotate setiap N request
DELAY_BETWEEN  = 3   # detik antar request
ROTATE_DELAY   = 14  # detik setelah NEWNYM

def smart_rotate(request_count, n=ROTATE_AFTER_N):
    if request_count % n == 0:
        rotate_tor()
```

---

## 2. PROXY CHAINS

### ProxyChains4 (Linux)
```bash
# Install
apt install -y proxychains4

# Config /etc/proxychains4.conf
[ProxyList]
socks5 127.0.0.1 9050   # Tor
# atau tambah chain:
# socks4 proxy1_ip 1080
# socks5 proxy2_ip 1080

# Usage
proxychains4 curl https://target.com
proxychains4 sqlmap -u "https://target.com/login"
proxychains4 nmap -sT -Pn target.com
```

### Rotating Proxy List
```python
import itertools

PROXIES = [
    "socks5://user:pass@proxy1:1080",
    "socks5://user:pass@proxy2:1080",
    "http://user:pass@proxy3:8080",
]
proxy_cycle = itertools.cycle(PROXIES)

def next_proxy():
    return next(proxy_cycle)

# Dalam requests:
r = session.get(url, proxies={"https": next_proxy()})
```

---

## 3. RESIDENTIAL PROXY (Anti-Bot)

Lebih mahal tapi lebih efektif untuk target dengan bot detection canggih.

```python
# Contoh provider: Brightdata, Oxylabs, Smartproxy
RESIDENTIAL_PROXY = "http://username:password@gate.brightdata.com:22225"

proxies = {"https": RESIDENTIAL_PROXY}
r = requests.get(url, proxies=proxies)
```

---

## 4. HEADER SPOOFING (Anti-Bot Detection)

```python
import random

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
]

BROWSER_HEADERS = {
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language": "id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding": "gzip, deflate, br",
    "DNT": "1",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Sec-Ch-Ua": '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
    "Sec-Ch-Ua-Mobile": "?0",
    "Sec-Ch-Ua-Platform": '"Windows"',
}

def random_headers():
    h = BROWSER_HEADERS.copy()
    h["User-Agent"] = random.choice(USER_AGENTS)
    return h
```

---

## 5. RATE LIMITING BYPASS PATTERNS

```python
import time, random

class AdaptiveRequester:
    def __init__(self, base_delay=2, jitter=1):
        self.base_delay  = base_delay
        self.jitter      = jitter
        self.req_count   = 0
        self.last_status = None
    
    def request(self, session, method, url, **kwargs):
        # Jitter delay
        time.sleep(self.base_delay + random.uniform(0, self.jitter))
        
        r = getattr(session, method)(url, **kwargs)
        self.req_count += 1
        self.last_status = r.status_code
        
        # Adaptasi berdasarkan response
        if r.status_code == 429:
            print(f"[!] Rate limited! Backing off 60s...")
            time.sleep(60)
            rotate_tor()
        elif r.status_code in [403, 468]:
            print(f"[!] WAF block (sc={r.status_code}), rotating...")
            rotate_tor()
        
        return r
```

---

## 6. SESSION MANAGEMENT

```python
# Setelah rotate Tor, butuh:
# 1. Circuit baru (IP baru)
# 2. Buat session baru (cookies baru)
# 3. Re-solve WAF challenge jika ada

def fresh_session(BASE, waf_solver=None):
    rotate_tor()
    s = requests.Session()
    s.proxies = TOR_PROXIES
    s.headers.update(random_headers())
    
    if waf_solver:
        s = waf_solver(BASE, s)
    
    return s
```

---

## CHECKLIST ANTI-BAN

1. ☐ Gunakan Tor atau residential proxy
2. ☐ Rotate circuit setiap N request (bukan setiap request)
3. ☐ Tambah delay realistis antar request (1-5 detik)
4. ☐ Gunakan User-Agent browser yang valid
5. ☐ Buat session baru setelah rotate
6. ☐ Re-solve WAF challenge setelah session baru
7. ☐ Monitor respons: 429 = rotate/slow down, 403 = cek payload
8. ☐ JANGAN burst request — WAF adaptive belajar dari pola
9. ☐ TARPIT global = tidak bisa dihindari dengan rotate — ubah payload
