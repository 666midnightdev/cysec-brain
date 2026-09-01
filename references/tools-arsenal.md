# TOOLS ARSENAL — Instalasi & Sumber (Windows / Linux / Cross-platform)

> Daftar tool per-kategori + cara install + sumber resmi. Semua open-source / gratis. Untuk Windows,
> banyak tool jalan native atau via WSL2. Kali/Parrot sudah bundle sebagian besar.

## Daftar Isi
1. [Setup cepat platform](#setup)
2. [Recon & OSINT](#recon)
3. [Scanning & fingerprint](#scan)
4. [Web & API](#web)
5. [Network & service](#net)
6. [Active Directory](#ad)
7. [Cloud](#cloud)
8. [Post-exploitation & privesc](#postex)
9. [Password & crypto](#pass)
10. [Pivoting & C2](#c2)
11. [Reversing & mobile](#rev)
12. [Wordlists & resources](#wordlists)

---

<a name="setup"></a>
## 1. Setup Cepat Platform

**Linux (Debian/Kali/Ubuntu):**
```bash
sudo apt update && sudo apt install -y nmap masscan hydra john hashcat sqlmap gobuster \
  ffuf feroxbuster nikto whatweb dnsrecon smbclient enum4linux ldap-utils snmp seclists \
  proxychains4 chisel netcat-openbsd jq git golang pipx
pipx ensurepath
# Go tools (ProjectDiscovery dll):
go install -v github.com/projectdiscovery/{subfinder,httpx,nuclei,dnsx,katana,naabu}/cmd/...@latest
```

**Windows:**
```powershell
# Native tools via package manager
winget install Nmap.Nmap Wireshark.Wireshark Insecure.Nmap 7zip.7zip Git.Git Python.Python.3.12
# atau chocolatey: choco install nmap wireshark python git
# WSL2 untuk toolkit Linux penuh:
wsl --install -d kali-linux
# Sysinternals (native, wajib):
#   download.sysinternals.com → procmon, procexp, accesschk, autoruns, psexec
# GhostPack/SharpCollection binaries (compiled) → github.com/Flangvik/SharpCollection
```

**Recommended distro:** Kali Linux / Parrot OS (offensive), atau Commando VM (Windows offensive
setup dari Mandiant → github.com/mandiant/commando-vm).

---

<a name="recon"></a>
## 2. Recon & OSINT

| Tool | Fungsi | Install |
|---|---|---|
| subfinder | subdomain pasif | `go install .../subfinder@latest` |
| amass | recon aset (OWASP) | `go install github.com/owasp-amass/amass/v4/...@master` |
| assetfinder | subdomain | `go install github.com/tomnomnom/assetfinder@latest` |
| dnsx | DNS resolve/probe | ProjectDiscovery |
| puredns | brute subdomain | `go install github.com/d3mondev/puredns/v2@latest` |
| httpx | probe web hidup | ProjectDiscovery |
| katana | crawler | ProjectDiscovery |
| waybackurls / gau | URL arsip | `go install github.com/tomnomnom/waybackurls@latest` |
| subjs / LinkFinder | ekstrak JS endpoint | pip / go |
| gitleaks / trufflehog | secret di git | `brew/go install` / `pip install trufflehog` |
| theHarvester | email/host OSINT | `apt install theharvester` |
| Shodan CLI | internet-wide recon | `pip install shodan` |
| wafw00f | deteksi WAF | `pip install wafw00f` |

---

<a name="scan"></a>
## 3. Scanning & Fingerprint

| Tool | Fungsi | Install |
|---|---|---|
| nmap | port/service/script | `apt install nmap` / winget |
| rustscan | port scan cepat | `cargo install rustscan` / docker |
| masscan | scan range besar | `apt install masscan` |
| naabu | port scan (PD) | ProjectDiscovery |
| nuclei | template vuln scan | ProjectDiscovery + `nuclei -update-templates` |
| whatweb / wappalyzer | tech fingerprint | `apt install whatweb` |
| nikto | web server scan | `apt install nikto` |
| testssl.sh | audit TLS | `git clone drwetter/testssl.sh` |

---

<a name="web"></a>
## 4. Web & API

| Tool | Fungsi | Install |
|---|---|---|
| Burp Suite | proxy web (utama) | portswigger.net (Community gratis) |
| Caido | proxy modern (Rust) | caido.io |
| sqlmap | SQLi otomatis | `apt install sqlmap` |
| ffuf | fuzzing cepat | `go install github.com/ffuf/ffuf/v2@latest` |
| feroxbuster | content discovery | `apt install feroxbuster` |
| gobuster | dir/dns/vhost brute | `apt install gobuster` |
| arjun | param discovery | `pipx install arjun` |
| dalfox | XSS scanner | `go install github.com/hahwul/dalfox/v2@latest` |
| jwt_tool | serangan JWT | `git clone ticarpi/jwt_tool` |
| tplmap | SSTI | `git clone epinna/tplmap` |
| graphw00f / InQL | GraphQL | `pip install graphw00f` |
| ysoserial / .NET / phpggc | deserialization | github masing-masing |

---

<a name="net"></a>
## 5. Network & Service

| Tool | Fungsi | Install |
|---|---|---|
| netexec (CME successor) | SMB/WinRM/LDAP/etc swiss-army | `pipx install netexec` |
| enum4linux-ng | enum SMB/LDAP | `pipx install enum4linux-ng` |
| smbmap | permission share | `pipx install smbmap` |
| impacket suite | psexec/wmiexec/secretsdump/dll | `pipx install impacket` |
| onesixtyone / snmpwalk | SNMP | `apt install onesixtyone snmp` |
| redis-cli / mongosh | DB unauth | `apt install redis-tools` |
| hydra / medusa | brute service | `apt install hydra` |

---

<a name="ad"></a>
## 6. Active Directory

| Tool | Fungsi | Install |
|---|---|---|
| BloodHound + collectors | peta serangan AD | `pipx install bloodhound` / bloodhound.py; SharpHound.exe |
| kerbrute | user enum/spray Kerberos | `go install github.com/ropnop/kerbrute@latest` |
| Rubeus | Kerberos (Windows) | SharpCollection (compiled) |
| mimikatz | dump creds (Windows) | github.com/gentilkiwi/mimikatz |
| certipy | ADCS abuse | `pipx install certipy-ad` |
| Certify / Coercer | ADCS / coerce | github; `pipx install coercer` |
| ntlmrelayx (impacket) | NTLM relay | impacket |
| ldapdomaindump | dump LDAP | `pipx install ldapdomaindump` |
| evil-winrm | shell WinRM | `gem install evil-winrm` |
| adPEAS / PingCastle | audit AD | github |

---

<a name="cloud"></a>
## 7. Cloud

| Tool | Fungsi | Install |
|---|---|---|
| ScoutSuite | audit multi-cloud | `pipx install scoutsuite` |
| Pacu | AWS exploitation framework | `pipx install pacu` |
| cloud_enum | enum bucket multi-cloud | `pipx install cloud-enum` |
| s3scanner | S3 bucket | `pipx install s3scanner` |
| roadrecon | Azure AD dump | `pipx install roadrecon` |
| AzureHound / AWSPX | BloodHound cloud | github |
| MicroBurst | Azure toolkit (PS) | github.com/NetSPI/MicroBurst |
| kube-hunter / peirates | Kubernetes | `pipx install kube-hunter` |
| trivy | scan image/IaC | `apt install trivy` |
| prowler | audit AWS/Azure/GCP | `pipx install prowler` |

---

<a name="postex"></a>
## 8. Post-Exploitation & PrivEsc

| Tool | Platform | Sumber |
|---|---|---|
| linpeas / winPEAS | Linux/Win | github.com/carlospolop/PEASS-ng |
| pspy | Linux (proc monitor) | github.com/DominicBreuker/pspy |
| PowerUp / PrivescCheck / Seatbelt | Windows | PowerSploit / itm4n / GhostPack |
| GodPotato / PrintSpoofer / JuicyPotatoNG | Windows (SeImpersonate) | github |
| GTFOBins / LOLBAS | referensi | gtfobins.github.io / lolbas-project.github.io |
| WES-NG | Windows exploit suggester | `pip install wesng` |
| linux-exploit-suggester | Linux kernel | github |
| LaZagne | creds recovery | github.com/AlessandroZ/LaZagne |
| Sysinternals | Windows (accesschk dll) | download.sysinternals.com |

---

<a name="pass"></a>
## 9. Password & Crypto

| Tool | Fungsi | Install |
|---|---|---|
| hashcat | GPU hash cracking | `apt install hashcat` / hashcat.net |
| john (JtR) | CPU cracking + tools (*2john) | `apt install john` |
| hashid / name-that-hash | identifikasi hash | `pipx install name-that-hash` |
| CyberChef | encode/decode/crypto (web) | gchq.github.io/CyberChef |
| openssl | operasi kripto manual | built-in |
| RsaCtfTool | serangan RSA | github |

**Mode hashcat penting:** 0=MD5 100=SHA1 1000=NTLM 1800=sha512crypt 3200=bcrypt 13100=Kerberoast
18200=AS-REP 2100=DCC2 16500=JWT 22000=WPA.

---

<a name="c2"></a>
## 10. Pivoting & C2 (open-source, red-team sah)

| Tool | Fungsi | Install |
|---|---|---|
| ligolo-ng | pivot via tun interface (terbaik) | github.com/nicocha30/ligolo-ng |
| chisel | SOCKS tunnel | `go install github.com/jpillora/chisel@latest` |
| proxychains-ng | route tool via SOCKS | `apt install proxychains4` |
| sshuttle | VPN-over-SSH | `pipx install sshuttle` |
| Sliver | C2 modern (open-source) | github.com/BishopFox/sliver |
| Havoc | C2 framework | github.com/HavocFramework/Havoc |
| Metasploit | exploit + C2 | `apt install metasploit-framework` |
| msfvenom | payload generator | (bagian metasploit) |

> Sliver/Havoc/Metasploit untuk engagement berotorisasi & lab. Selalu dalam RoE.

---

<a name="rev"></a>
## 11. Reversing & Mobile

| Tool | Fungsi | Install |
|---|---|---|
| Ghidra | disassembler/decompiler (NSA) | ghidra-sre.org |
| radare2 / rizin / cutter | RE | `apt install radare2` |
| gdb + pwndbg / GEF | debug + exploit dev | github |
| pwntools | exploit dev Python | `pipx install pwntools` |
| Frida | dynamic instrumentation | `pip install frida-tools` |
| objection | mobile runtime (Frida) | `pipx install objection` |
| apktool / jadx | decompile APK | `apt install apktool`; jadx github |
| MobSF | mobile static/dynamic | docker `opensecurity/mobile-security-framework-mobsf` |
| ropgadget / one_gadget | binary exploit | pip / gem |

---

<a name="wordlists"></a>
## 12. Wordlists & Resources

```bash
# SecLists (wajib — koleksi wordlist terlengkap)
sudo apt install seclists          # → /usr/share/seclists
# atau: git clone github.com/danielmiessler/SecLists

# Wordlist populer:
#   Passwords: rockyou.txt (/usr/share/wordlists/rockyou.txt.gz → gunzip)
#   Dir/files: raft-*-directories.txt, directory-list-2.3-medium.txt
#   Subdomains: subdomains-top1million-*.txt
#   Params: burp-parameter-names.txt
# Rules hashcat: /usr/share/hashcat/rules/ (best64.rule, dive.rule, OneRuleToRuleThemAll)
```

**Referensi wajib bookmark:**
- HackTricks — book.hacktricks.xyz (metodologi per-service, terlengkap)
- PayloadsAllTheThings — github.com/swisskyrepo/PayloadsAllTheThings
- GTFOBins / LOLBAS — escape & living-off-the-land
- OWASP WSTG / API Security Top 10 — metodologi web/API
- exploit-db + searchsploit — `searchsploit <keyword>`
- MITRE ATT&CK — attack.mitre.org (mapping teknik → laporan)
- revshells.com — generator reverse shell semua bahasa
