#!/usr/bin/env python3
# fix-youtube-tags.py
import subprocess
import re
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, TIT2, TPE1, TALB

# Patrones a limpiar del título
CLEAN_PATTERNS = [
    r'\s*[\(\[](Official Music Video|Official Video|Official Audio|Official HD Video|Official Lyric Video|Official Animated Video|Official 4K Video|Lyric Video|Audio|Music Video|HD Video|Video Oficial|Vídeo Oficial|Video Oficial HD|Visualizer|Remastered.*?)\s*[\)\]]',
    r'\s*[\(\[](feat\.|ft\.).*?[\)\]]',  # NO — queremos conservar features
    r'\s*\|\s*\d+Hz.*$',                  # quita | 432Hz al final
    r'\s*-\s*(Remastered.*?)$',
    r'\s*\(4K.*?\)$',
    r'\s*\[4K.*?\]$',
]

def clean_title(s):
    for p in CLEAN_PATTERNS:
        s = re.sub(p, '', s, flags=re.IGNORECASE)
    return s.strip()

def extract_artist_title(title_tag):
    """
    'Adele - Hello (Official Music Video)' -> ('Adele', 'Hello')
    'Abraham Mateo, Ana Mena - Quiero Decirte (Official Video)' -> ('Abraham Mateo, Ana Mena', 'Quiero Decirte')
    """
    if ' - ' in title_tag:
        parts = title_tag.split(' - ', 1)
        artist = parts[0].strip()
        title  = clean_title(parts[1].strip())
        return artist, title
    else:
        return None, clean_title(title_tag)

# Obtener todas las pistas sin álbum
result = subprocess.run(
    ['beet', 'ls', '-f', '$artist|$title|$path', 'album::^$'],
    capture_output=True, text=True
)

fixed = 0
skipped = 0

for line in result.stdout.strip().split('\n'):
    if not line:
        continue
    parts = line.split('|', 2)
    if len(parts) != 3:
        continue

    yt_channel, yt_title, path = parts

    if not path.endswith('.mp3'):
        skipped += 1
        continue

    artist, title = extract_artist_title(yt_title)

    if not artist or not title:
        print(f"SKIP (no pattern): {yt_title}")
        skipped += 1
        continue

    try:
        audio = MP3(path, ID3=ID3)
        audio.tags['TIT2'] = TIT2(encoding=3, text=title)
        audio.tags['TPE1'] = TPE1(encoding=3, text=artist)
        audio.tags['TALB'] = TALB(encoding=3, text=title)  # álbum = título (single)
        audio.save()
        print(f"FIXED: {artist} - {title}")
        fixed += 1
    except Exception as e:
        print(f"ERROR {path}: {e}")
        skipped += 1

print(f"\nDone: {fixed} fixed, {skipped} skipped")
