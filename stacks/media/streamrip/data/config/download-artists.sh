#!/bin/bash
CONFIG="/config/config.toml"
ARTISTS_FILE="/config/artists.txt"
LOG="/config/download.log"
DONE_FILE="/config/downloaded.txt"

touch "$DONE_FILE"

while IFS= read -r artist; do
    [[ "$artist" =~ ^#.*$ || -z "$artist" ]] && continue

    if grep -qF "$artist" "$DONE_FILE"; then
        echo "[SKIP] $artist"
        continue
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Searching: $artist" | tee -a "$LOG"

    ARTIST_ID=$(python3 - << PYEOF
import urllib.request, urllib.parse, json
artist = """$artist""".replace("'", "")
url = "https://api.deezer.com/search/artist?q=" + urllib.parse.quote(artist) + "&limit=1"
try:
    with urllib.request.urlopen(url, timeout=10) as r:
        data = json.load(r)
    if data.get("data"):
        print(data["data"][0]["id"])
except:
    pass
PYEOF
)

    if [ -z "$ARTIST_ID" ]; then
        echo "[NOT FOUND] $artist" | tee -a "$LOG"
        continue
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading: $artist (ID: $ARTIST_ID)" | tee -a "$LOG"
    rip --config-path "$CONFIG" url "https://www.deezer.com/artist/$ARTIST_ID" >> "$LOG" 2>&1

    if [ $? -eq 0 ]; then
        echo "$artist" >> "$DONE_FILE"
        echo "[DONE] $artist" | tee -a "$LOG"
    else
        echo "[ERROR] $artist" | tee -a "$LOG"
    fi

    sleep 2

done < "$ARTISTS_FILE"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All done!" | tee -a "$LOG"
