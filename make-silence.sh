#!/data/data/com.termux/files/usr/bin/bash
# make-silence.sh — создаёт 4-секундный беззвучный FLAC (-loop=inf делает его бесконечным)
set -e
d="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$d/audio"
f="$d/audio/silence.flac"
# 4 сек, 44.1 кГц, моно, 16 бит — тихо-тишайте, размер ~35 КБ
ffmpeg -y -loglevel error -f lavfi -i "anullsrc=r=44100:cl=mono" -t 4 -c:a flac "$f"
ls -l "$f"
