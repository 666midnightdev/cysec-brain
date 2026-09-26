#!/usr/bin/env bash
# =============================================================================
# CYSEC-BRAIN — Arsenal Installer (Linux: Debian / Kali / Ubuntu / Parrot)
# -----------------------------------------------------------------------------
# Memasang toolkit pentest lengkap DI MESIN KAMU SENDIRI untuk pekerjaan
# BEROTORISASI (kontrak, bug bounty in-scope, lab/CTF, aset sendiri).
#
# Pakai:
#   chmod +x install-linux.sh
#   ./install-linux.sh              # install semua
#   ./install-linux.sh --core       # cuma tool inti (recon+scan+web)
#   ./install-linux.sh --no-clone   # skip git-clone tools ke /opt
#
# Aman dijalankan ulang (idempoten-ish). Kegagalan satu item tidak menghentikan
# yang lain. Jalankan sbg user biasa; script minta sudo saat perlu.
# =============================================================================
set -uo pipefail

CORE_ONLY=false; DO_CLONE=true
for a in "$@"; do
  case "$a" in
    --core) CORE_ONLY=true ;;
    --no-clone) DO_CLONE=false ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac
done

OPT=/opt/tools
LOG=/tmp/cysec-install.log
c(){ printf '\033[1;36m[*] %s\033[0m\n' "$*"; }
ok(){ printf '\033[1;32m[+] %s\033[0m\n' "$*"; }
warn(){ printf '\033[1;33m[!] %s\033[0m\n' "$*"; }
have(){ command -v "$1" >/dev/null 2>&1; }
try(){ "$@" >>"$LOG" 2>&1 && ok "done: $*" || warn "gagal (lanjut): $*"; }

: > "$LOG"
c "Log detail: $LOG"

# --- 0. sanity -------------------------------------------------------------
if ! have apt-get; then
  warn "Bukan sistem berbasis apt. Pakai package manager distromu / lihat tools-arsenal.md."
  warn "Bagian Go/pipx di bawah tetap jalan kalau go & pipx ada."
fi
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

# --- 1. apt packages -------------------------------------------------------
if have apt-get; then
  c "Update apt & pasang paket dasar…"
  try $SUDO apt-get update -y
  APT_CORE=(git curl wget jq unzip build-essential python3 python3-pip python3-venv pipx \
            golang-go nmap netcat-openbsd dnsutils whois)
  APT_FULL=(masscan hydra john hashcat sqlmap gobuster ffuf feroxbuster nikto whatweb \
            dnsrecon smbclient ldap-utils snmp onesixtyone redis-tools seclists \
            proxychains4 socat tcpdump wireshark-common openssl medusa)
  try $SUDO apt-get install -y "${APT_CORE[@]}"
  $CORE_ONLY || try $SUDO apt-get install -y "${APT_FULL[@]}"
  have pipx && pipx ensurepath >>"$LOG" 2>&1 || true
fi

# --- 2. Go tools (ProjectDiscovery dkk) -----------------------------------
if have go; then
  export PATH="$PATH:$(go env GOPATH)/bin"
  c "Pasang Go tools…"
  GO_CORE=(
    github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
    github.com/projectdiscovery/httpx/cmd/httpx@latest
    github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
    github.com/projectdiscovery/dnsx/cmd/dnsx@latest
    github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
    github.com/projectdiscovery/katana/cmd/katana@latest
    github.com/tomnomnom/assetfinder@latest
    github.com/tomnomnom/waybackurls@latest
  )
  GO_FULL=(
    github.com/ffuf/ffuf/v2@latest
    github.com/hahwul/dalfox/v2@latest
    github.com/ropnop/kerbrute@latest
    github.com/jpillora/chisel@latest
    github.com/d3mondev/puredns/v2@latest
    github.com/lc/gau/v2/cmd/gau@latest
    github.com/owasp-amass/amass/v4/...@master
  )
  for t in "${GO_CORE[@]}"; do try go install -v "$t"; done
  $CORE_ONLY || for t in "${GO_FULL[@]}"; do try go install -v "$t"; done
  have nuclei && try nuclei -update-templates
else
  warn "go tidak ada — lewati Go tools. Install: apt install golang-go"
fi

# --- 3. pipx / python tools ------------------------------------------------
if have pipx; then
  c "Pasang python tools via pipx…"
  PIPX_CORE=(impacket netexec arjun)
  PIPX_FULL=(name-that-hash enum4linux-ng smbmap ldapdomaindump certipy-ad coercer \
             scoutsuite pacu cloud-enum s3scanner roadrecon sshuttle wafw00f shodan \
             sqlmap wesng trufflehog objection frida-tools)
  for p in "${PIPX_CORE[@]}"; do try pipx install "$p"; done
  $CORE_ONLY || for p in "${PIPX_FULL[@]}"; do try pipx install "$p"; done
else
  warn "pipx tidak ada — install: apt install pipx"
fi

# --- 4. git-clone tools ke /opt -------------------------------------------
if $DO_CLONE && ! $CORE_ONLY; then
  c "Clone tools ke $OPT…"
  $SUDO mkdir -p "$OPT" && $SUDO chown "$(id -u):$(id -g)" "$OPT"
  clone(){ [ -d "$OPT/$2" ] && { ok "ada: $2"; return; }; try git clone --depth 1 "$1" "$OPT/$2"; }
  clone https://github.com/carlospolop/PEASS-ng                 PEASS-ng        # linpeas/winpeas
  clone https://github.com/DominicBreuker/pspy                  pspy
  clone https://github.com/swisskyrepo/PayloadsAllTheThings     PayloadsAllTheThings
  clone https://github.com/danielmiessler/SecLists              SecLists        # kalau apt seclists gagal
  clone https://github.com/ticarpi/jwt_tool                     jwt_tool
  clone https://github.com/drwetter/testssl.sh                  testssl.sh
  clone https://github.com/nicocha30/ligolo-ng                  ligolo-ng
  clone https://github.com/internetwache/GitTools               GitTools        # dump .git terbuka
  clone https://github.com/GerbenJavado/LinkFinder              LinkFinder
  # Windows-side binaries (compiled) untuk dibawa ke target Windows:
  clone https://github.com/Flangvik/SharpCollection             SharpCollection # Rubeus/Seatbelt/dll
  ok "Tools di $OPT (baca README masing-masing untuk build/pakai)."
fi

# --- 5. wordlists ----------------------------------------------------------
if [ -f /usr/share/wordlists/rockyou.txt.gz ] && [ ! -f /usr/share/wordlists/rockyou.txt ]; then
  try $SUDO gunzip -k /usr/share/wordlists/rockyou.txt.gz
fi

# --- 6. ringkasan ----------------------------------------------------------
echo; c "==== RINGKASAN ===="
for t in nmap masscan nuclei subfinder httpx ffuf feroxbuster sqlmap gobuster hydra \
         hashcat john netexec impacket-secretsdump kerbrute chisel proxychains4 amass; do
  if have "$t"; then ok "$t"; else warn "BELUM ada: $t"; fi
done
echo
c "Tambahkan ke ~/.bashrc bila belum:  export PATH=\"\$PATH:\$(go env GOPATH)/bin\""
c "Tools clone: $OPT   |   Wordlists: /usr/share/seclists , /usr/share/wordlists"
c "Verifikasi lengkap:  ./verify-tools.sh"
ok "Selesai. Ingat: hanya untuk target berotorisasi."
