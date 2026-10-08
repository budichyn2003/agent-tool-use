# PRD 3: AI Agent dengan Tool Use

Bagian dari portofolio AI Engineer (5 proyek). Python 3.10, tampilan web Streamlit, seluruh data di cloud.


## 3.1 Ringkasan
Asisten yang bisa memutuskan sendiri kapan memanggil alat (tool), seperti cek cuaca, query database, mencari di web, dan menghitung, lalu menyusun jawaban dari hasilnya lewat alur multi-langkah.

## 3.2 Tujuan
- Menguasai function calling, loop agent, dan penanganan error tool.
- Membangun agent yang aman, terlacak, dan tidak berputar tanpa henti.

## 3.3 Target pengguna
Pengguna yang ingin asisten yang benar-benar "mengerjakan sesuatu", misalnya catatan keuangan pribadi atau riset cepat.

## 3.4 Ruang lingkup
**P0**
- Loop agent: LLM memilih tool, sistem menjalankan, hasil dikembalikan ke LLM, ulangi sampai selesai
- Minimal 4 tool: pencarian web, kalkulator, query data keuangan pribadi (read-only), cuaca atau kurs
- Batas maksimum langkah (mis. 8) dan batas waktu per permintaan
- Jejak eksekusi (trace) ditampilkan di UI: tool apa, input, output
- Validasi argumen tool dengan Pydantic

**P1**
- Tool yang mengubah data (mis. catat pengeluaran) dengan **konfirmasi pengguna** sebelum dieksekusi
- Retry dan penanganan error tool dengan pesan yang bisa dipahami LLM
- Eksekusi tool paralel bila independen

**P2**
- Perencanaan eksplisit (plan-then-execute)
- Integrasi MCP server

**Di luar lingkup:** eksekusi kode bebas di server tanpa sandbox.

## 3.5 Persyaratan fungsional
| ID | Persyaratan |
|----|-------------|
| F1 | Setiap tool punya skema input/output dan deskripsi yang jelas |
| F2 | Agent berhenti dan melapor jika melebihi batas langkah atau waktu |
| F3 | Tool bersifat mengubah data wajib memicu konfirmasi di UI |
| F4 | Seluruh panggilan tool dicatat (nama, argumen, hasil, durasi, error) |
| F5 | Input dari hasil web diperlakukan sebagai data, bukan instruksi (mitigasi prompt injection) |

## 3.6 Persyaratan non-fungsional
- Keamanan: allowlist domain untuk tool web, query database hanya read-only dengan user DB terpisah
- Observabilitas: trace lengkap tersimpan di Neon
- Biaya: batas token total per sesi agent

## 3.7 Arsitektur
Streamlit → FastAPI (orchestrator agent) → registry tool → (API eksternal, Neon, pencarian web). Orchestrator memanggil LLM dengan daftar tool, menjalankan pilihan tool, dan mengulang.

## 3.8 Model data
- `agent_runs(id, user_id, prompt, status, steps, tokens, created_at)`
- `tool_calls(id, run_id, step, tool_name, arguments_json, result_json, duration_ms, error)`
- `expenses(id, user_id, amount, category, note, date)` (untuk tool contoh)

## 3.9 Endpoint utama
`POST /agent/run` (stream langkah), `POST /agent/confirm/{call_id}`, `GET /agent/runs/{id}`

## 3.10 Halaman UI
Chat dengan panel trace langkah demi langkah, dialog konfirmasi aksi, riwayat eksekusi.

## 3.11 Metrik sukses
- Tingkat keberhasilan tugas minimal 80% pada 20 skenario uji
- Rata-rata langkah per tugas di bawah 5
- Tidak ada loop tak terbatas dan tidak ada aksi mengubah data tanpa konfirmasi

## 3.12 Milestone
- Minggu 1: registry tool, loop agent, 2 tool pertama
- Minggu 2: tool tambahan, trace, UI
- Minggu 3: konfirmasi, batas keamanan, test skenario, deploy

## 3.13 Risiko
| Risiko | Mitigasi |
|--------|----------|
| Prompt injection lewat hasil web | Pisahkan data dari instruksi, allowlist, konfirmasi aksi |
| Agent berputar | Batas langkah dan waktu |
| Salah pilih tool | Deskripsi tool jelas, contoh, evaluasi berkala |


---

## Stack & Aturan Umum

**Stack**
- Bahasa: Python 3.10 (versi stabil), environment dengan `venv` atau `uv` (`uv venv --python 3.10`)
- Backend/mesin AI: FastAPI + SDK LLM resmi (Anthropic/OpenAI), async
- Tampilan web: **Streamlit** (alternatif: Gradio atau NiceGUI), semua Python
- Database: **Neon PostgreSQL** (gratis) + ekstensi **pgvector**
- Penyimpanan file: **Cloudflare R2** atau **Supabase Storage** (PDF, gambar, ekspor)
- ORM/migrasi: SQLAlchemy 2 + Alembic
- Testing: pytest; lint: ruff
- Deploy: FastAPI di Render, Streamlit di Streamlit Community Cloud (atau Render)
- Secret: environment variable di platform deploy, jangan commit `.env`

**Aturan penyimpanan (agar lokal tidak penuh)**
- Tidak ada file upload yang disimpan permanen di disk lokal atau server. Upload langsung di-stream ke bucket cloud.
- File sementara memakai `tempfile` dan dihapus setelah diproses.
- Embedding, riwayat chat, log, dan hasil evaluasi disimpan di Neon.
- Tetapkan kebijakan retensi (mis. log lebih dari 90 hari dihapus otomatis) supaya kuota gratis tidak habis.

**Struktur repo (monorepo per proyek)**
```
app/
  api/        # route FastAPI
  core/       # config, logging, keamanan
  services/   # logika LLM, RAG, agent
  db/         # model, sesi, migrasi
  ui/         # aplikasi Streamlit
tests/
pyproject.toml
README.md
```

**Urutan pengerjaan yang disarankan:** PRD 1 → 2 → 3 → 4 → 5. Setiap proyek memakai ulang kode dari sebelumnya (auth, sesi DB, klien LLM).

**Hal yang perlu diperhatikan:** kuota gratis (Neon, Render, R2) dan harga API LLM berubah dari waktu ke waktu, jadi cek halaman pricing sebelum mulai.


**Catatan Python 3.10**
- Semua library di stack ini (FastAPI, SQLAlchemy 2, Pydantic 2, Streamlit, pytest) mendukung 3.10.
- Gunakan sintaks modern yang sudah ada di 3.10: `str | None`, `match`, dan type hint bawaan seperti `list[str]`.
- Buat file `.python-version` berisi `3.10` dan pin `requires-python = ">=3.10,<3.11"` di `pyproject.toml`.
- Di Render, set env var `PYTHON_VERSION=3.10.x` agar sama dengan lokal.
- Python 3.10 mendekati akhir dukungan pembaruan keamanan (Oktober 2026). Untuk portofolio tidak masalah, tapi kalau nanti dipakai di produksi sungguhan, pertimbangkan naik ke 3.11 atau 3.12 (kode tidak perlu diubah).
