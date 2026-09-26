# cysec-brain

Cybersecurity pentesting **brain** — metodologi & arsenal lengkap untuk engagement berotorisasi:
deep recon, web/API, network, Active Directory, cloud, post-exploitation, reverse engineering,
kripto, TLS, plus tooling Windows & Linux dan pelaporan CVSS level internasional.

Dipakai sebagai **skill** untuk Claude (Cowork / Claude Code). Skill = *otak* (metodologi + command);
eksekusi tool dilakukan di lingkungan ber-shell (lihat `references/environment-setup.md`).

## Struktur

```
SKILL.md                 # otak utama: prinsip, alur 6 fase, format temuan, CVSS quick ref
cysec-brain.skill        # paket skill siap-import (zip berisi seluruh struktur di bawah)
references/
  recon.md               # recon pasif -> aktif, subdomain, OSINT, content discovery
  web-api.md             # IDOR/BOLA, injection, SSRF, XSS, JWT/OAuth, GraphQL, CORS
  network.md             # port/service enum, SMB/LDAP/SNMP/NFS/DB, TLS, password attacks
  active-directory.md    # Kerberos, BloodHound, cred dump, relay, ADCS, DCSync
  cloud.md               # AWS/Azure/GCP, IMDS, storage, containers & Kubernetes
  linux.md               # privesc, GTFOBins, cred hunting, container escape, pivoting
  windows.md             # token privesc, service misconfig, LOLBAS, post-ex
  tools-arsenal.md       # daftar tool per-kategori + cara install (Win/Linux/cross)
  reporting.md           # struktur laporan, CVSS 3.1 scoring, business impact
  cheatsheets.md         # oneliner revshell, transfer, TTY, encoding
  environment-setup.md   # model eksekusi + cara menyambungkan ke Claude Code
scripts/
  install-linux.sh       # pasang arsenal di Linux (Kali/Parrot/Ubuntu)
  install-windows.ps1    # pasang arsenal di Windows (+ opsi WSL)
  verify-tools.sh        # cek tool mana yang sudah/belum terpasang
```

## Scope & etika

Skill ini untuk pekerjaan yang diperintahkan user pada target yang sudah memiliki scope & izin.
OPSEC dijaga: minim noise, jangan rusak data, dokumentasikan semua bukti.

> Konten teknis = materi standar publik (HackTricks, PayloadsAllTheThings, PTES, OWASP WSTG,
> GTFOBins, LOLBAS).
