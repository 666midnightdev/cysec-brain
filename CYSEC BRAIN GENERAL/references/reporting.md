# REPORTING — CVSS, Template & Business Impact

> Temuan tanpa laporan bagus = tidak bernilai. Laporan menerjemahkan bukti teknis → risiko bisnis yang
> dipahami manajemen. Format konsisten, CVSS beralasan, remediasi konkret.

## Daftar Isi
1. [Struktur laporan](#struktur)
2. [CVSS 3.1 — cara scoring](#cvss)
3. [Template temuan](#template)
4. [Business impact & narasi](#impact)
5. [Executive summary](#exec)
6. [Crypto/TLS notes untuk laporan](#crypto)

---

<a name="struktur"></a>
## 1. Struktur Laporan Lengkap

```
1. Executive Summary        — untuk manajemen (non-teknis, risiko + angka)
2. Scope & Methodology      — apa yang diuji, standar (PTES/OWASP), tanggal, batasan
3. Risk Overview            — grafik severity, jumlah temuan per kategori
4. Findings (detail)        — satu per temuan, format di §3
5. Attack Narrative         — cerita chain: dari 0 → domain admin/data (opsional, powerful)
6. Remediation Roadmap      — prioritas perbaikan (quick win vs strategis)
7. Appendices               — bukti mentah, tool output, scope detail
```

---

<a name="cvss"></a>
## 2. CVSS 3.1 — Cara Scoring

Vector string: `CVSS:3.1/AV:_/AC:_/PR:_/UI:_/S:_/C:_/I:_/A:_`

| Metrik | Opsi | Kapan |
|---|---|---|
| **AV** Attack Vector | N(etwork)/A(djacent)/L(ocal)/P(hysical) | N = remote via internet |
| **AC** Attack Complexity | L(ow)/H(igh) | L = tidak butуh kondisi khusus |
| **PR** Privileges Required | N(one)/L(ow)/H(igh) | N = tanpa akun |
| **UI** User Interaction | N(one)/R(equired) | R = butuh korban klik (mis. XSS) |
| **S** Scope | U(nchanged)/C(hanged) | C = dampak keluar komponen (mis. SSRF→cloud) |
| **C/I/A** | N(one)/L(ow)/H(igh) | dampak Confidentiality/Integrity/Availability |

**Contoh vector siap pakai:**
```
RCE unauth:        CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H          = 9.8 Critical
SQLi authed:       CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:H/A:H          = 8.8 High
IDOR baca PII:     CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N          = 6.5 Medium*
SSRF→metadata:     CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:C/I:H/C:H/A:N          = ~9.1 Critical
Stored XSS:        CVSS:3.1/AV:N/AC:L/PR:L/UI:R/S:C/C:H/I:L/A:N          = ~7.6 High
Reflected XSS:     CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N          = 6.1 Medium
CORS+cred leak:    CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:H/I:N/A:N          = ~7.4 High
No rate-limit OTP: CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:H/A:N          = 7.5 High
```
*IDOR bisa naik jadi High (7.5) kalau unauth (PR:N) atau data sangat sensitif massal.

> Gunakan kalkulator resmi FIRST (first.org/cvss/calculator/3.1) untuk verifikasi skor akhir.
> **Justifikasi tiap metrik** di laporan — jangan cuma tempel angka.

---

<a name="template"></a>
## 3. Template Temuan (per finding)

```markdown
## [HIGH-01]: IDOR pada endpoint /api/orders memungkinkan akses order pengguna lain

**Severity:** High (CVSS 7.5 — CVSS:3.1/AV:N/AC:L/PR:L/UI:N/S:U/C:H/I:N/A:N)
**Type:** OWASP API1:2023 Broken Object Level Authorization (CWE-639)
**Asset:** https://api.target.com/v1/orders/{id}
**Status:** Confirmed (reproduced 2x)

### Ringkasan
Endpoint order tidak memverifikasi kepemilikan objek terhadap token pemanggil. Pengguna terautentikasi
mana pun dapat membaca data order (nama, alamat, item, total) milik pengguna lain hanya dengan mengubah
parameter numerik `id`. Karena ID berurutan, seluruh basis data order (±120.000 record berisi PII) dapat
di-enumerasi otomatis.

### Langkah Reproduksi
1. Login sebagai user standar, ambil token.
2. Catat order milik sendiri: `GET /v1/orders/50231` → 200 (data sendiri).
3. Ubah ID ke milik user lain:
   ```
   curl -s -H "Authorization: Bearer $TOKEN" https://api.target.com/v1/orders/1001
   ```
4. Response 200 mengembalikan PII order user lain → kontrol akses gagal.

### Bukti
`evidence/idor-orders-1001.txt` (request+response), screenshot `evidence/idor-orders.png`.

### Dampak & Chaining
Enumerasi massal PII (pelanggaran privasi/PDP). Dapat dirangkai dengan [MED-04] no-rate-limit untuk scraping
otomatis, dan [HIGH-03] IDOR write → account/order takeover.

### Remediasi
Terapkan otorisasi tingkat objek: verifikasi `order.owner_id == token.user_id` di server sebelum
mengembalikan data. Gunakan UUID acak, bukan ID berurutan. Terapkan rate limiting. Referensi: OWASP API1.
```

---

<a name="impact"></a>
## 4. Business Impact & Narasi

Terjemahkan teknis → bahasa risiko:
- **Bukan:** "SQLi di parameter id." → **Tapi:** "Penyerang tanpa akun dapat mengunduh seluruh database
  pelanggan (X juta record termasuk hash password & PII), berpotensi denda regulasi dan kerugian reputasi."
- Kaitkan ke: data pelanggan, uang/transaksi, ketersediaan layanan, kepatuhan (GDPR/PCI-DSS/UU PDP),
  reputasi, kelangsungan bisnis.
- **Attack narrative** (chain) sangat kuat: ceritakan langkah dari akses awal sampai dampak terparah —
  ini yang bikin manajemen paham urgensi. Contoh: "Recon → subdomain staging lupa dimatikan → default
  cred → SSRF → cloud metadata → IAM creds → akses S3 backup produksi."

---

<a name="exec"></a>
## 5. Executive Summary (untuk manajemen)

- 3–5 paragraf, **tanpa jargon**.
- Ringkas: berapa temuan, severity tertinggi, risiko bisnis utama, apakah tujuan tercapai (mis. "berhasil
  mendapatkan akses Domain Admin dan data pelanggan dari posisi tanpa kredensial").
- Sertakan **positive notes** (kontrol yang sudah baik) — laporan seimbang lebih dipercaya.
- Rekomendasi prioritas: 3 hal teratas yang harus diperbaiki minggu ini.

---

<a name="crypto"></a>
## 6. Crypto / TLS Notes (untuk laporan)

Temuan kripto umum & severity indikatif:
```
TLS 1.0/1.1 aktif / cipher lemah (RC4/3DES/EXPORT)   → Medium (downgrade/decrypt)
Sertifikat expired / self-signed di produksi          → Low-Medium
Password disimpan MD5/SHA1 tanpa salt                 → High (jika DB ter-dump)
Hardcoded key/secret di kode/JS                        → High-Critical (tergantung akses)
Weak JWT secret / alg:none                             → High-Critical (auth bypass)
Reused IV / ECB mode / predictable token               → Medium-High
Missing HSTS                                            → Low
```
Selalu jelaskan **dampak praktis**, bukan cuma "cipher lemah" — mis. "memungkinkan MITM men-decrypt sesi
pada jaringan tidak tepercaya."

---

## Checklist Kualitas Laporan
- [ ] Setiap temuan: severity + CVSS vector + tipe (OWASP/CWE) + status confirmed.
- [ ] Reproduksi step-by-step yang bisa diikuti tim lain.
- [ ] Bukti tersimpan & direferensikan (path evidence).
- [ ] Remediasi konkret + referensi standar.
- [ ] Chaining antar temuan disebutkan.
- [ ] Business impact dalam bahasa manajemen.
- [ ] Executive summary bebas jargon + positive notes.
- [ ] Tidak ada data sensitif klien yang tidak perlu (redaksi PII di lampiran).
