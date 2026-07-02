#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PYTHON="python3"

if [ -d "venv" ]; then
    echo "[*] Activating virtual environment..."
    source venv/bin/activate
    PYTHON="$PWD/venv/bin/python"
fi

echo "[*] Installing dependencies..."
"$PYTHON" -m pip install -r requirements.txt

echo "[*] Starting StyleTone AI backend on http://0.0.0.0:8000"
exec "$PYTHON" -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload