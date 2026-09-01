<#
==============================================================================
 CYSEC-BRAIN — Arsenal Installer (Windows 10/11)
------------------------------------------------------------------------------
 Memasang toolkit pentest DI MESIN WINDOWS KAMU SENDIRI untuk pekerjaan
 BEROTORISASI (kontrak, bug bounty in-scope, lab/CTF, aset sendiri).

 Jalankan di PowerShell sebagai Administrator:
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\install-windows.ps1                 # semua
   .\install-windows.ps1 -Core           # inti saja
   .\install-windows.ps1 -WSL            # sekalian pasang Kali di WSL2

 CATATAN: Banyak tool red-team (mimikatz, Rubeus, potato) AKAN ditandai oleh
 Microsoft Defender — itu wajar. Hanya buat exclusion di LAB TERISOLASI yang
 kamu miliki & sesuai RoE. Jangan matikan AV di mesin produksi.
==============================================================================
#>
param([switch]$Core, [switch]$WSL)

$ErrorActionPreference = "Continue"
$Tools = "C:\Tools"
function Info($m){ Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "[+] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "[!] $m" -ForegroundColor Yellow }
function Have($c){ $null -ne (Get-Command $c -ErrorAction SilentlyContinue) }

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Warn "Butuh Administrator. Jalankan ulang PowerShell 'Run as administrator'."; exit 1
}
New-Item -ItemType Directory -Force -Path $Tools | Out-Null

# --- 1. Package manager (winget/choco) -------------------------------------
if (-not (Have winget) -and -not (Have choco)) {
  Info "Install Chocolatey…"
  Set-ExecutionPolicy Bypass -Scope Process -Force
  iex ((New-Object Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

$pkgsCore = @("Git.Git","Python.Python.3.12","Nmap.Nmap","7zip.7zip","WiresharkFoundation.Wireshark")
$pkgsFull = @("GoLang.Go","OpenJS.NodeJS","Microsoft.VisualStudioCode","Insecure.Nmap")
function InstallPkg($id){
  if (Have winget){ winget install --id $id -e --silent --accept-source-agreements --accept-package-agreements 2>$null; Ok "winget: $id" }
  elseif (Have choco){ choco install ($id.Split('.')[-1]) -y 2>$null; Ok "choco: $id" }
}
Info "Pasang paket native…"
$pkgsCore | ForEach-Object { InstallPkg $_ }
if (-not $Core){ $pkgsFull | ForEach-Object { InstallPkg $_ } }

# --- 2. Sysinternals (wajib) -----------------------------------------------
Info "Download Sysinternals Suite…"
try {
  Invoke-WebRequest "https://download.sysinternals.com/files/SysinternalsSuite.zip" -OutFile "$Tools\Sysinternals.zip"
  Expand-Archive "$Tools\Sysinternals.zip" -DestinationPath "$Tools\Sysinternals" -Force
  Ok "Sysinternals → $Tools\Sysinternals (accesschk, procmon, procexp, autoruns, psexec)"
} catch { Warn "Sysinternals gagal: $_" }

# --- 3. Compiled red-team binaries (dibawa ke target saat engagement) ------
if (-not $Core) {
  Info "Clone SharpCollection (Rubeus/Seatbelt/SharpUp/Certify - precompiled)…"
  if (Have git){ git clone --depth 1 https://github.com/Flangvik/SharpCollection "$Tools\SharpCollection" 2>$null; Ok "SharpCollection" }

  # PEASS-ng (winPEAS), potato binaries, dsb — repo publik standar red-team
  $dl = @{
    "winPEASx64.exe" = "https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASx64.exe"
    "PrintSpoofer64.exe" = "https://github.com/itm4n/PrintSpoofer/releases/latest/download/PrintSpoofer64.exe"
  }
  New-Item -ItemType Directory -Force -Path "$Tools\privesc" | Out-Null
  foreach($k in $dl.Keys){
    try { Invoke-WebRequest $dl[$k] -OutFile "$Tools\privesc\$k"; Ok "privesc: $k" }
    catch { Warn "gagal $k (mungkin diblok Defender) — download manual dari GitHub." }
  }
  Warn "GodPotato / mimikatz / Rubeus: ambil dari rilis GitHub resmi (Defender sering hapus otomatis)."
}

# --- 4. Go / pip tools (kalau ada) -----------------------------------------
if (Have go){
  Info "Go tools…"
  $env:Path += ";$(go env GOPATH)\bin"
  @("github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest",
    "github.com/projectdiscovery/httpx/cmd/httpx@latest",
    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest") |
    ForEach-Object { go install $_ 2>$null; Ok "go: $_" }
}
if (Have python){
  Info "Python tools (pip)…"
  python -m pip install --upgrade pip 2>$null
  @("impacket","netexec","name-that-hash") | ForEach-Object { pip install $_ 2>$null; Ok "pip: $_" }
}

# --- 5. WSL2 Kali (toolkit Linux penuh) ------------------------------------
if ($WSL){
  Info "Pasang WSL2 + Kali (butuh reboot)…"
  wsl --install -d kali-linux
  Warn "Setelah reboot, di Kali jalankan: sudo apt update && install-linux.sh"
}

# --- 6. ringkasan ----------------------------------------------------------
Write-Host ""; Info "==== RINGKASAN ===="
foreach($t in @("git","python","go","nmap","nuclei")){ if(Have $t){Ok $t}else{Warn "belum: $t"} }
Ok "Tools di $Tools . Tambah ke PATH sesuai kebutuhan."
Info "Rekomendasi setup Windows offensive lengkap: Commando VM (github.com/mandiant/commando-vm)."
Ok "Selesai. Ingat: hanya untuk target berotorisasi."
