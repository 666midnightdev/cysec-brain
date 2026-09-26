---
name: agent-to-agent
description: "Strategi Agent-to-Agent — cara spawn sub-agent untuk tugas paralel, manajemen context, hasil agregasi. Gunakan untuk tugas kompleks multi-step yang bisa di-parallelkan: recon + exploit simultaneously, multiple target scanning, iterative research + testing."
---

# Agent-to-Agent Strategy

## KAPAN GUNAKAN MULTI-AGENT

| Situasi | Gunakan Multi-Agent? |
|---------|---------------------|
| Tugas paralel independen | ✅ YA |
| Recon + exploit bersamaan | ✅ YA |
| Multiple target scanning | ✅ YA |
| Context window hampir penuh | ✅ YA (delegasi ke sub-agent) |
| Tugas sequential dependency | ❌ Gunakan single agent |
| Tugas sederhana 1-2 langkah | ❌ Berlebihan |

## POLA DASAR

### 1. Parallel Exploration
```
Main Agent
├── Sub-Agent A: Recon target (nmap, headers, tech stack)
├── Sub-Agent B: OSINT (shodan, google, github leaks)
└── Sub-Agent C: Endpoint discovery (gobuster, JS analysis)
         ↓
Main Agent: Agregasi hasil → planning exploit
```

### 2. Specialization Split
```
Main Agent: Planning + koordinasi
├── Bypass-Specialist Agent: Fokus WAF bypass techniques
├── Extraction Agent: Fokus SQL extraction logic
└── OSINT Agent: Fokus mencari credentials/usernames dari public data
```

### 3. Pipeline dengan Feedback
```
Research Agent → temukan teknik → kirim ke Main Agent
Main Agent → implement → kirim hasil ke Verification Agent
Verification Agent → konfirmasi valid → kirim ke Reporting Agent
```

## IMPLEMENTASI DI CLAUDE CODE

### Spawn Sub-Agent (Agent Tool)
```
# Deskripsi harus mencakup SEMUA konteks yang dibutuhkan:
# - Target URL/IP
# - Apa yang sudah diketahui
# - Apa yang perlu dicari/dilakukan
# - Batasan/hambatan yang diketahui
# - Format output yang diinginkan
```

### Komunikasi Antar Agent
```
# Agent tidak bisa berkomunikasi langsung
# Semua komunikasi lewat Main Agent
# Main Agent membaca hasil sub-agent dan mengirim ke yang lain

# Pattern: Main reads A result → passes context to B
SendMessage({to: "sub-agent-name", message: "Found X, now do Y with context Z"})
```

## TEMPLATE PROMPT SUB-AGENT

### Security Research Agent
```
Target: [URL/IP]
Context: Kami sedang mentest [SYSTEM] yang teridentifikasi memiliki [VULNERABILITY TYPE].
Sudah diketahui:
- [FINDING 1]
- [FINDING 2]
WAF/Security: [SAFELINE/CLOUDFLARE/dll dengan detail]
Hambatan: [APA YANG SUDAH GAGAL]

Tugasmu: [SPESIFIK TASK]
Output yang diinginkan: [FORMAT HASIL]
Jangan: [BATASAN]
```

### OSINT Agent
```
Target: [ORGANIZATION]
Cari: NIP/username/email untuk sistem [SYSTEM NAME]
Public sources: website resmi, PPID, laporan keuangan, foto publik, sosmed resmi
Format output: List [username]:[source_url]
```

### Exploitation Agent
```
Endpoint: POST [URL]/auth
Vulnerability: Time-based blind SQLi (dikonfirmasi via SLEEP timing)
WAF: SafeLine (bypass: line comment '-- -)
Blocked: SLEEP, SELECT, LIMIT, semua SQL functions
PASSING: AND -1-- -, AND NOT 0-- -
Auth check: num_rows()==1 (butuh TEPAT 1 row)
Known username: [USERNAME JIKA ADA]
Task: Gunakan boolean injection via [SPECIFIC METHOD]
```

## MANAJEMEN CONTEXT

### Saat Context Hampir Penuh
```
1. Simpan KEY FINDINGS ke file sebelum context dicompact
2. File berisi: target, confirmed vulns, working payloads, passwords found
3. Path: /home/midnight/engagements/[target]/evidence/SUMMARY.md
4. Sub-agent baca file ini sebagai konteks
```

### State Management Pattern
```python
# Simpan state ke file agar bisa dilanjutkan
import json, os

STATE_FILE = '/tmp/pentest_state.json'

def save_state(state_dict):
    with open(STATE_FILE, 'w') as f:
        json.dump(state_dict, f, indent=2)

def load_state():
    if os.path.exists(STATE_FILE):
        return json.load(open(STATE_FILE))
    return {}

# State mencakup:
state = {
    'target': 'https://simpeg2-vvip.cirebonkota.go.id',
    'confirmed_sqli': True,
    'working_bypass': "'-- -",
    'blocked_functions': ['SLEEP','BENCHMARK','SELECT','LIMIT'],
    'found_users': [],
    'extracted_hashes': [],
    'current_step': 'username_enum',
    'session_count': 0
}
```

## MULTI-AGENT STRATEGI UNTUK PENTEST

### Fase 1: Parallel Recon
```
Agent-Recon-1: nmap + service fingerprint
Agent-Recon-2: subdomain enum + vhost discovery  
Agent-OSINT:   shodan + censys + github + PPID
Agent-Tech:    Wappalyzer + JS analysis + header analysis
```

### Fase 2: Parallel Vuln Finding
```
Agent-SQLi:  Test injection points
Agent-XSS:   Test XSS vectors
Agent-Auth:  Test auth bypass
Agent-API:   Test API endpoints
```

### Fase 3: Extraction (Sequential dengan Checkpoints)
```
Agent-Extract-DB:    Extract database name + tables
Agent-Extract-Users: Extract first 10 usernames
Agent-Extract-Hash:  Extract password hashes
[Main Agent agregasi dan dokumentasi]
```

## BEST PRACTICES

1. **Prompt harus self-contained** — sub-agent tidak punya memory conversation
2. **Delegasi riset, bukan eksekusi** — untuk tugas berbahaya, main agent yang eksekusi
3. **Checkpoint setiap fase** — simpan hasil ke file sebelum lanjut
4. **Jangan duplikasi** — jika sub-agent sudah riset X, jangan riset lagi di main
5. **Background untuk I/O heavy** — extraction yang lama = run in background
6. **Foreground untuk decision-critical** — hasil yang menentukan langkah berikutnya = foreground

## PATTERN: RESEARCH → VERIFY → EXECUTE

```
1. Research Agent: "Cari teknik bypass SafeLine untuk time-based SQLi"
   → Hasil: List teknik dari public research

2. Main Agent: Filter teknik yang aplikabel berdasarkan constraint

3. Test Agent: Test masing-masing teknik secara aman
   → Hasil: Teknik A blocked, Teknik B works!

4. Exploit Agent: Gunakan Teknik B untuk full extraction
   → Hasil: Credentials dumped

5. Reporting Agent: Dokumentasi findings dengan CVSS
```
