#!/data/data/com.termux/files/usr/bin/bash
# antifreeze-install.sh — установка/обновление/запуск системы antifreeze
# Использование:
#   antifreeze-install.sh            — полная установка (сейчас + boot + jobs)
#   antifreeze-install.sh --restart  — перезапустить только демона
#   antifreeze-install.sh --remove   — полное удаление (демон, boot, jobs)
set -u
d="$(cd "$(dirname "$0")" && pwd)"
. "$d/lib.sh"

case "${1:-}" in
  --restart)
    old=$(af_daemon_alive || true)
    [ -n "$old" ] && kill "$old" 2>/dev/null
    pkill -f "antifreeze-job.sh" 2>/dev/null
    pkill -f "mpv.*silence\.flac" 2>/dev/null
    termux-media-player stop 2>/dev/null
    sleep 2
    setsid "$d/antifreeze-daemon.sh" >/dev/null 2>&1 &
    sleep 3
    if af_daemon_alive >/dev/null; then
      echo "OK: демон запущен (pid $(af_daemon_alive))"
    else
      echo "FAIL: демон не стартовал, смотри $AF_LOG"; exit 1
    fi
    # перепланируем job — он должен указывать на antifreeze-job.sh
    af_job_schedule 990
    echo "OK: Job 990 перепланирован на antifreeze-job.sh"
    exit 0
    ;;
  --remove)
    old=$(af_daemon_alive || true)
    [ -n "$old" ] && kill "$old" 2>/dev/null
    pkill -f "mpv.*silence\.flac" 2>/dev/null
    termux-media-player stop 2>/dev/null
    termux-job-scheduler --cancel-all >/dev/null 2>&1
    rm -f ~/.termux/boot/15-antifreeze
    echo "Удалено: демон, boot-скрипт, job 990/991 (cancel-all также убрал jobs от probe)"
    exit 0
    ;;
esac

# ---------- полная установка ----------
echo "== antifreeze: установка =="

# 1. аудиофайл
if [ ! -s "$AF_AUDIO_FILE" ]; then
  echo "-- генерирую беззвучный FLAC..."
  bash "$d/make-silence.sh" || { echo "FAIL: ffmpeg?"; exit 1; }
else
  echo "-- аудиофайл уже есть: $AF_AUDIO_FILE"
fi

# 2. демон
old=$(af_daemon_alive || true)
[ -n "$old" ] && { echo "-- демон уже работает (pid $old), перезапуск"; kill "$old" 2>/dev/null; sleep 2; }
setsid "$d/antifreeze-daemon.sh" >/dev/null 2>&1 &
sleep 5
af_daemon_alive >/dev/null && echo "OK: демон работает (pid $(af_daemon_alive))" || { echo "FAIL демон"; tail -5 "$AF_LOG"; exit 1; }

# 3. JobScheduler (Job 990 — дефибриллятор; 991 на всякий случай дублирую)
termux-job-scheduler --cancel 990 >/dev/null 2>&1
termux-job-scheduler --job-id 990 --period-ms 900000 --persisted true --battery-not-low false -s "$d/antifreeze-job.sh" >/dev/null
echo "OK: Job 990 (15 мин, persisted) установлен"

# 4. boot
chmod +x "$d"/*.sh
ln -sf "$d/boot-antifreeze.sh" ~/.termux/boot/15-antifreeze
echo "OK: boot-скрипт ~/.termux/boot/15-antifreeze -> boot-antifreeze.sh"

echo
echo "== Готово. Слои защиты: =="
echo "  1. wake-lock (каждый цикл)"
echo "  2. mpv-щит: играющий uid = perceptible => не кэшируется => не морозится"
echo "  3. Termux:API audio — дубль аудио-щита"
echo "  4. CPU-burst (openssl speed, ~${AF_CPU_MB}MiB/цикл)"
echo "  5. Job 990: JobScheduler размораживает Termux каждые 15 мин"
echo "  6. boot-скрипт: поднимает всё после перезагрузки"
echo
echo "Лог: ~/antifreeze/antifreeze.log"
echo "Проверка: antifreeze-install.sh --restart; статус: af-status"
