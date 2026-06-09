# 9Router Personal Fork

Fork pribadi 9Router untuk routing AI endpoint lokal.

- Dashboard: `http://localhost:20128/dashboard`
- API OpenAI-compatible: `http://localhost:20128/v1`
- Repo: `https://github.com/levanza1358/9router`

## Fitur Utama

- Multi-provider AI router.
- Multi-account + round robin.
- Auto fallback akun/provider.
- Quota tracker.
- Codex JSON import / batch import.
- Local dashboard.

## Install dari GitHub

Tidak wajib clone manual. Bisa langsung one-line install dari GitHub.

### Windows One-Line Install

PowerShell:

```powershell
irm https://raw.githubusercontent.com/levanza1358/9router/master/install-remote.ps1 | iex
```

Default install ke:

```text
%USERPROFILE%\9router
```

Custom folder:

```powershell
$env:NINEROUTER_INSTALL_DIR="D:\Apps\9router"; irm https://raw.githubusercontent.com/levanza1358/9router/master/install-remote.ps1 | iex
```

### Linux / Ubuntu One-Line Install

Bash:

```bash
curl -sSL https://raw.githubusercontent.com/levanza1358/9router/master/install-remote.sh | bash
```

Default install ke:

```text
~/9router
```

Custom folder:

```bash
NINEROUTER_INSTALL_DIR="$HOME/apps/9router" curl -sSL https://raw.githubusercontent.com/levanza1358/9router/master/install-remote.sh | bash
```

Setelah install, buka terminal baru lalu:

```bash
9router start
9router status
```

### Install Manual

Kalau mau clone manual:

```bash
git clone https://github.com/levanza1358/9router.git
cd 9router
npm install
```

#### Windows Manual

Pakai PowerShell:

```powershell
.\install.ps1
```

`install.ps1` khusus Windows. Script ini akan membuat command lokal `9router` dan menambahkannya ke User PATH.

Tutup terminal, buka terminal baru, lalu cek:

```powershell
9router status
```

Alternatif Windows via `.bat`:

```powershell
.\install.bat
```

#### Linux / Ubuntu Manual

Pakai Bash:

```bash
bash install.sh
```

`install.sh` khusus Linux/Ubuntu. Script ini akan membuat command lokal di:

```text
~/.local/bin/9router
```

Pastikan `~/.local/bin` ada di `PATH`, lalu cek:

```bash
9router status
```

Install script membuat command global lokal: `9router`.

## Jalankan Mode Production

Untuk pemakaian harian, pakai production mode. Ini lebih ringan daripada `npm run dev` karena tidak compile/render ulang terus.

```powershell
9router start
```

Command ini akan:

1. set env lokal Windows,
2. build production kalau belum ada,
3. copy asset static standalone,
4. start server di port `20128`.

Buka:

```text
http://localhost:20128/dashboard
```

Command lain:

```powershell
9router status   # cek jalan/tidak
9router stop     # matikan server
9router restart  # restart server
9router rebuild  # hapus .next lalu build ulang
9router logs     # lihat log server
9router open     # buka dashboard
```

## Auto Run / Start Otomatis

Windows: jalan otomatis saat login user.

```powershell
9router autorun-on
9router autorun-status
```

Matikan autorun:

```powershell
9router autorun-off
```

Ubuntu/Linux: pakai `systemd --user`.

```bash
9router autorun-on
9router autorun-status
```

Matikan autorun:

```bash
9router autorun-off
```

Catatan Ubuntu server/headless: script otomatis coba `loginctl enable-linger $USER`, supaya service tetap hidup setelah reboot tanpa login. Kalau gagal, jalankan manual:

```bash
sudo loginctl enable-linger $USER
9router autorun-on
```

## Restart Server

Kalau server sudah jalan dan mau restart:

```powershell
9router restart
```

## Setelah Edit Kode

Kalau ada perubahan kode, hapus build lama lalu build ulang:

```powershell
9router rebuild
9router restart
```

## Mode Development

Pakai hanya saat perlu hot reload/debug UI.

```powershell
npm run dev
```

Catatan: dev mode lebih berat dan sering recompile.

## Environment Penting

Default di `9router start` / `run-prod.bat`:

```text
PORT=20128
HOSTNAME=0.0.0.0
BASE_URL=http://localhost:20128
NEXT_PUBLIC_BASE_URL=http://localhost:20128
DATA_DIR=.runtime-home\data
NODE_ENV=production
```

Data lokal tersimpan di:

```text
.runtime-home\data
```

## Catatan Git

Repo ini fork pribadi. Tidak pakai upstream PR flow.

Cek remote:

```powershell
git remote -v
```

Seharusnya:

```text
origin  https://github.com/levanza1358/9router.git
```

## Docker

Untuk pribadi lokal, disarankan `run-prod.bat`.

Docker tetap bisa dibuild manual:

```powershell
docker build -t 9router .
docker run -d --name 9router -p 20128:20128 -v "$HOME/.9router:/app/data" -e DATA_DIR=/app/data 9router
```

## Model Endpoint Example

```text
Base URL: http://localhost:20128/v1
API Key: ambil dari dashboard
Model: cx/gpt-5.5
```
