#!/data/data/com.termux/files/usr/bin/bash
# antifreeze-daemon.sh — многослойный щит от заморозки Termux
# Слои (перечислены по механизму действия):
#   1. Wake-lock (переустановка каждый цикл) — препятствует CPU deep-sleep.
#   2. Аудио-щит mpv В ПРОЦЕССЕ TERMUX (audioserver считает uid «perceptible»
#      => LRU-кэширование невозможно => НЕ попадает в cached_apps_freezer).
#   3. Дублирующий плеер через Termux:API — CPU-wakelock через AudioFlinger.
#   4. CPU-burst (openssl speed) — держит ядро активным и сбивает эвристику «idle».
#   5. JobScheduler defibrillator (id 990) — JobScheduler сам размораживает
#      приложение для запуска job; запускается прямо в процессе Termux.
#   6. Job-failsafe (id 991) — стартует сервисы из холодного состояния (после
#      убийства Termux системой), выполняя RUN_COMMAND-запуск самого себя.
# Хранение состояния: state/ (доступно обоим слоям — основной процесс
# и процесс в cgroup главного приложения).
set -u
. "$(dirname "$0")/lib.sh"
umask 077

echo $$ > "$AF_STATE/daemon.pid"
af_log "DAEMON: старт, pid $$ (конфиг: loop=${AF_LOOP_SEC}s cpu=${AF_CPU_MB}MB mpv=$AF_USE_MPV api=$AF_USE_API_AUDIO wl=$AF_WAKELOCK)"

cycle=0
while :; do
  cycle=$((cycle+1))
  now=$(date +%s)

  # ---------- 1. wakelock ----------
  [ "$AF_WAKELOCK" = 1 ] && termux-wake-lock >/dev/null 2>&1

  # ---------- 2/3. аудио-щиты ----------
  if [ "$AF_USE_MPV" = 1 ] && command -v mpv >/dev/null 2>&1; then
    if ! af_mpv_alive >/dev/null; then
      # --no-terminal: без pty; setsid — отвязка от сессии Termux (иначе убивается при закрытии терминала)
      setsid mpv --no-terminal --no-video --no-cache -really-quiet \
          --ao="$AF_MPV_AO" --loop-file=inf \
          "$AF_AUDIO_FILE" >/dev/null 2>&1 < /dev/null &
      af_log "CYCLE $cycle: mpv-щит (re)start, pid $!"
    fi
  fi
  if [ "$AF_USE_API_AUDIO" = 1 ]; then
    if ! af_api_audio_ok; then
      # честный FLAC с 2 кадрами — не «диспетчер вакансий»
      termux-media-player play "$AF_AUDIO_FILE" >/dev/null 2>&1
      af_log "CYCLE $cycle: Termux:API audio (re)start"
    fi
  fi
  # ---------- 4. CPU-burst ----------
  if [ "${AF_CPU_MB:-0}" -gt 0 ] && command -v openssl >/dev/null 2>&1; then
    # ровно 1 сек SHA-256 — держит ядро активным, сбивает эвристику «idle»
    nohup openssl speed -seconds 1 sha256 >/dev/null 2>&1 &
  fi

  # ---------- 5/6. jobs ----------
  [ "$(af_jobs_count)" -ge 1 ] || { af_log "CYCLE $cycle: jobs потеряны, переустанавливаю"; af_job_schedule 990; }

  # ---------- 7. сервис-guard (sshd, tor, X11...) ----------
  af_services_guard

  # heartbeat-файл: job и boot-скрипты по нему видят жив ли демон
  echo "$now $$" > "$AF_STATE/heartbeat"

  # таймер сна, устойчивый к заморозке всего приложения (спим малыми порциями)
  end=$((now + AF_LOOP_SEC))
  while [ "$(date +%s)" -lt "$end" ]; do
    sleep 15
  done
done
