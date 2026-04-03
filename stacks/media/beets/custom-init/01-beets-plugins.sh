#!/bin/bash
if ! python3 -c "import acoustid" 2>/dev/null; then
    echo "[beets-init] Installing plugins..."
    pip install --quiet pyacoustid requests mutagen
    apt-get install -y -q --no-install-recommends libchromaprint-tools
fi
