# =====================================================================
# Setup kerangka proyek: PRD 3 - AI Agent dengan Tool Use
# Python 3.10 (dikunci), manajer paket: uv
# Cara pakai (PowerShell):
#   .\setup-agent-project.ps1
#   .\setup-agent-project.ps1 -ProjectName "ai-agent" -SkipInstall
# Jika muncul error execution policy, jalankan sekali:
#   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
# =====================================================================
param(
    [string]$ProjectName = "agent-tool-use",
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"

# ---------- Helper ----------
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function New-File {
    param([string]$Path, [string]$Content = "")
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $Path) {
        Write-Host "  [lewati] $Path (sudah ada)" -ForegroundColor DarkYellow
        return
    }
    $full = Join-Path (Get-Location) $Path
    [System.IO.File]::WriteAllText($full, $Content, $utf8NoBom)
    Write-Host "  [buat]   $Path" -ForegroundColor Green
}

# ---------- Cek uv ----------
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "uv belum terpasang. Pasang dulu: winget install --id=astral-sh.uv -e" -ForegroundColor Red
    exit 1
}

# ---------- Folder proyek ----------
if (-not (Test-Path $ProjectName)) { New-Item -ItemType Directory -Path $ProjectName | Out-Null }
Set-Location $ProjectName
Write-Host "`nProyek: $(Get-Location)`n" -ForegroundColor Cyan

# ---------- Folder ----------
$folders = @(
    "app",
    "app/api",
    "app/core",
    "app/services",
    "app/services/tools",
    "app/db",
    "app/db/migrations",
    "app/ui",
    "app/ui/pages",
    "tests",
    "tests/scenarios",
    "scripts"
)
foreach ($f in $folders) { New-Item -ItemType Directory -Path $f -Force | Out-Null }

# ---------- File konfigurasi root ----------
New-File ".python-version" "3.10`n"

New-File "pyproject.toml" @'
[project]
name = "agent-tool-use"
version = "0.1.0"
description = "AI Agent dengan Tool Use (PRD 3)"
readme = "README.md"
requires-python = ">=3.10,<3.11"
dependencies = []

[tool.uv]
package = false

[tool.ruff]
line-length = 100
target-version = "py310"

[tool.ruff.lint]
select = ["E", "F", "I", "UP", "B"]

[tool.pytest.ini_options]
asyncio_mode = "auto"
pythonpath = ["."]
testpaths = ["tests"]
'@

New-File ".gitignore" @'
.venv/
__pycache__/
*.pyc
.env
.pytest_cache/
.ruff_cache/
*.log
.DS_Store
'@

New-File ".env.example" @'
# Salin ke .env (jangan commit .env)
ANTHROPIC_API_KEY=
LLM_MODEL=

# Neon PostgreSQL - user utama (baca/tulis, untuk agent_runs & tool_calls)
DATABASE_URL=postgresql+asyncpg://user:pass@host/dbname

# Neon PostgreSQL - user terpisah READ-ONLY (khusus tool query keuangan)
READONLY_DATABASE_URL=postgresql+asyncpg://readonly_user:pass@host/dbname

# Batas keamanan agent
AGENT_MAX_STEPS=8
AGENT_TIMEOUT_SECONDS=60
AGENT_MAX_TOKENS_PER_SESSION=50000

# Tool web: domain yang diizinkan (pisahkan koma)
WEB_ALLOWED_DOMAINS=wikipedia.org,reuters.com

# API eksternal (cuaca / kurs)
WEATHER_API_BASE=https://api.open-meteo.com
FX_API_BASE=https://api.frankfurter.app

# Retensi log (hari)
LOG_RETENTION_DAYS=90

# URL backend untuk Streamlit
API_BASE_URL=http://localhost:8000
'@

New-File "README.md" @'
# AI Agent dengan Tool Use

Asisten yang memutuskan sendiri kapan memanggil tool (web, kalkulator, data keuangan, cuaca/kurs).
Stack: Python 3.10, FastAPI, Streamlit, Neon PostgreSQL, SQLAlchemy 2, Alembic.

## Setup
```powershell
uv venv --python 3.10
.\.venv\Scripts\Activate.ps1
uv sync
Copy-Item .env.example .env   # lalu isi nilainya
```

## Menjalankan
```powershell
uv run uvicorn app.api.main:app --reload
uv run streamlit run app/ui/streamlit_app.py
```

## Tes dan lint
```powershell
uv run pytest
uv run ruff check .
```
'@

# ---------- app/ ----------
foreach ($pkg in @("app", "app/api", "app/core", "app/services", "app/services/tools", "app/db", "app/ui", "tests")) {
    New-File "$pkg/__init__.py" ""
}

# core
New-File "app/core/config.py" "`"`"`"Pengaturan aplikasi dari environment variable (pydantic-settings).`"`"`"`n"
New-File "app/core/logging.py" "`"`"`"Konfigurasi logging terstruktur.`"`"`"`n"
New-File "app/core/security.py" "`"`"`"Allowlist domain, sanitasi hasil web (F5), helper keamanan.`"`"`"`n"

# db
New-File "app/db/session.py" "`"`"`"Engine dan sesi async SQLAlchemy (user utama + user read-only).`"`"`"`n"
New-File "app/db/models.py" "`"`"`"Model: AgentRun, ToolCall, Expense.`"`"`"`n"
New-File "app/db/retention.py" "`"`"`"Pembersihan log lama sesuai LOG_RETENTION_DAYS.`"`"`"`n"
New-File "app/db/migrations/.gitkeep" ""

# services
New-File "app/services/llm_client.py" "`"`"`"Klien LLM (SDK resmi, async) dengan dukungan function calling.`"`"`"`n"
New-File "app/services/agent.py" "`"`"`"Orchestrator: loop LLM -> pilih tool -> jalankan -> kembalikan hasil.`"`"`"`n"
New-File "app/services/limits.py" "`"`"`"Batas langkah, waktu, dan token per sesi (F2).`"`"`"`n"
New-File "app/services/tracing.py" "`"`"`"Pencatatan trace tool_calls ke Neon (F4).`"`"`"`n"
New-File "app/services/confirmation.py" "`"`"`"Alur konfirmasi untuk tool yang mengubah data (F3, P1).`"`"`"`n"

# tools
New-File "app/services/tools/base.py" "`"`"`"Kelas dasar Tool: nama, deskripsi, skema Pydantic input/output (F1).`"`"`"`n"
New-File "app/services/tools/registry.py" "`"`"`"Registry tool dan konversi ke skema function calling LLM.`"`"`"`n"
New-File "app/services/tools/calculator.py" "`"`"`"Tool kalkulator (evaluasi ekspresi aman, tanpa eval bebas).`"`"`"`n"
New-File "app/services/tools/web_search.py" "`"`"`"Tool pencarian web dengan allowlist domain.`"`"`"`n"
New-File "app/services/tools/finance_query.py" "`"`"`"Tool query data keuangan pribadi (read-only, user DB terpisah).`"`"`"`n"
New-File "app/services/tools/weather_fx.py" "`"`"`"Tool cuaca dan kurs.`"`"`"`n"
New-File "app/services/tools/record_expense.py" "`"`"`"Tool catat pengeluaran (mengubah data, wajib konfirmasi) - P1.`"`"`"`n"

# api
New-File "app/api/main.py" "`"`"`"Aplikasi FastAPI: mendaftarkan router.`"`"`"`n"
New-File "app/api/agent_routes.py" "`"`"`"POST /agent/run (stream), POST /agent/confirm/{call_id}, GET /agent/runs/{id}.`"`"`"`n"
New-File "app/api/schemas.py" "`"`"`"Skema request/response API.`"`"`"`n"
New-File "app/api/deps.py" "`"`"`"Dependency: sesi DB, user saat ini.`"`"`"`n"

# ui
New-File "app/ui/streamlit_app.py" "`"`"`"Chat dengan panel trace, dialog konfirmasi aksi.`"`"`"`n"
New-File "app/ui/pages/1_Riwayat.py" "`"`"`"Halaman riwayat eksekusi agent.`"`"`"`n"
New-File "app/ui/api_client.py" "`"`"`"Klien HTTP ke FastAPI (streaming langkah).`"`"`"`n"

# tests
New-File "tests/test_calculator.py" ""
New-File "tests/test_limits.py" ""
New-File "tests/test_registry.py" ""
New-File "tests/test_confirmation.py" ""
New-File "tests/scenarios/scenarios.json" "[]`n"
New-File "tests/scenarios/run_eval.py" "`"`"`"Menjalankan 20 skenario uji dan menghitung success rate (target >= 80%).`"`"`"`n"

# scripts
New-File "scripts/seed_expenses.py" "`"`"`"Mengisi data contoh tabel expenses di Neon.`"`"`"`n"

# ---------- Lingkungan Python 3.10 + dependensi ----------
if (-not $SkipInstall) {
    Write-Host "`nMembuat venv Python 3.10 dengan uv..." -ForegroundColor Cyan
    uv venv --python 3.10
    if ($LASTEXITCODE -ne 0) { Write-Host "Gagal membuat venv. Cek: uv python list" -ForegroundColor Red; exit 1 }

    Write-Host "Memasang dependensi..." -ForegroundColor Cyan
    uv add fastapi "uvicorn[standard]" "sqlalchemy[asyncio]" asyncpg alembic pydantic pydantic-settings anthropic httpx streamlit python-dotenv
    uv add --dev pytest pytest-asyncio ruff
}

Write-Host "`nSelesai." -ForegroundColor Green
Write-Host "Langkah berikutnya:" -ForegroundColor Cyan
Write-Host "  cd $ProjectName"
Write-Host "  .\.venv\Scripts\Activate.ps1"
Write-Host "  python --version   # harus 3.10.x"
Write-Host "  Copy-Item .env.example .env"
