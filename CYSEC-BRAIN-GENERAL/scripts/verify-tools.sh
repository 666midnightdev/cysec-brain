#!/usr/bin/env bash
# CYSEC-BRAIN — cek tool mana yang sudah terpasang & mana yang belum.
# Pakai: ./verify-tools.sh
export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin:$HOME/.local/bin"

declare -A CAT=(
  [RECON]="subfinder amass assetfinder dnsx httpx katana waybackurls gau puredns wafw00f"
  [SCAN]="nmap masscan naabu rustscan nuclei whatweb nikto"
  [WEB]="sqlmap ffuf feroxbuster gobuster arjun dalfox"
  [NETWORK]="netexec crackmapexec smbmap enum4linux-ng onesixtyone snmpwalk hydra medusa redis-cli"
  [AD]="kerbrute bloodhound-python certipy impacket-secretsdump impacket-psexec ldapdomaindump evil-winrm"
  [CLOUD]="scout pacu cloud_enum s3scanner roadrecon prowler trivy"
  [PASS]="hashcat john nth name-that-hash"
  [PIVOT]="chisel proxychains4 sshuttle ligolo"
  [CORE]="git curl wget jq go python3 pipx"
)

pass=0; fail=0
for cat in CORE RECON SCAN WEB NETWORK AD CLOUD PASS PIVOT; do
  printf '\n\033[1;36m== %s ==\033[0m\n' "$cat"
  for t in ${CAT[$cat]}; do
    if command -v "$t" >/dev/null 2>&1; then
      printf '  \033[1;32m✓ %-24s\033[0m %s\n' "$t" "$(command -v "$t")"; ((pass++))
    else
      printf '  \033[1;31m✗ %-24s\033[0m belum terpasang\n' "$t"; ((fail++))
    fi
  done
done
printf '\n\033[1mTerpasang: %d   Belum: %d\033[0m\n' "$pass" "$fail"
[ "$fail" -gt 0 ] && echo "Jalankan install-linux.sh (atau lihat references/tools-arsenal.md untuk yang belum)."
