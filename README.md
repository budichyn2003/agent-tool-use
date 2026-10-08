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