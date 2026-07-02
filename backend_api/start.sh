#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -d "venv" ]; then
    echo "[*] Activating virtual environment..."
    source venv/bin/activate
fi

echo "[*] Installing dependencies..."
pip install -r requirements.txt --quiet

echo "[*] Starting StyleTone AI backend on http://0.0.0.0:8000"
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
