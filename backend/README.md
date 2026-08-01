# Legacy FastAPI exercise

This service is not used by the production Flutter app. It remains in the
repository to demonstrate a small parameterized SQLite API.

From `backend/`:

```bash
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn app:app --reload
```

The schema is created automatically in `database/lobos.db`. To add the
fictional rows once:

```bash
python - <<'PY'
from pathlib import Path
import sqlite3

database = sqlite3.connect('database/lobos.db')
database.executescript(Path('database/sample_data.sql').read_text())
database.commit()
PY
```

This demo has no authentication. Keep it on localhost and do not place real
client data in it.
