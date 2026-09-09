#!/data/data/com.termux/files/usr/bin/bash
# antifreeze — общая библиотека
AF_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$AF_PREFIX/bin:$PATH"
AF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AF_STATE="$AF_DIR/state"
AF_LOG="$AF_DIR/antifreeze.log"
AF_CONF="$AF_DIR/antifreeze.conf"

# --- дефолты (переопределяются в antifreeze.conf) ---
AF_LOOP_SEC=60
AF_CPU_MB=150
AF_USE_MPV=1
AF_USE_API_AUDIO=1
AF_WAKELOCK=1
AF_MPV_AO=opensles
AF_AUDIO_FILE="$AF_DIR/audio/silence.flac"
[ -r "$AF_CONF" ] && . "$AF_CONF"

mkdir -p "$AF_STATE" 2>/dev/null

af_log() {
  echo "$(date '+%F %T') $*" >> "$AF_LOG"
  # логротейт
  if [ -f "$AF_LOG" ]; then
    local s; s=$(stat -c%s "$AF_LOG" 2>/dev/null || echo 0)
    if [ "$s" -gt 200000 ]; then
      tail -n 1000 "$AF_LOG" > "$AF_LOG.1" 2>/dev/null
      : > "$AF_LOG"
    fi
  fi
}

# pid живого демона (проверка /proc + cmdline), иначе пусто
af_daemon_alive() {
  local p c
  [ -f "$AF_STATE/daemon.pid" ] || return 1
  p=$(cat "$AF_STATE/daemon.pid" 2>/dev/null)
  [ -n "$p" ] && [ -d "/proc/$p" ] || return 1
  c=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
  case "$c" in
    *antifreeze-daemon.sh*) echo "$p"; return 0 ;;
    *) return 1 ;;
  esac
}

# pid процесса mpv (аудио-щит).
af_mpv_alive() {
  local p
  p=$(pgrep -f "mpv.*silence[.]flac" 2>/dev/null | head -n1)
  [ -n "$p" ] || return 1
  echo "$p"
}

# играет ли Termux:API плеер
af_api_audio_ok() {
  termux-media-player info 2>/dev/null | grep -qi 'playing'
}

af_jobs_count() {
  termux-job-scheduler --pending 2>/dev/null | grep -c '^Pending Job 99[01]' || true
}

af_job_schedule() { # $1 = job-id
  termux-job-scheduler --job-id "$1" --period-ms 900000 --persisted true \
    --battery-not-low false -s "$AF_DIR/antifreeze-job.sh" >/dev/null 2>&1
}
