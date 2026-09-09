#!/data/data/com.termux/files/usr/bin/bash
# antifreeze-job.sh — запускается JobScheduler'ом В ПРОЦЕССЕ TERMUX.
# Задача: если демона нет — поднять (fail-safe после форс-останова Termux),
# если есть — ничего не делать (не создавать вторую копию).
set -u
. "$(dirname "$0")/lib.sh"
exec >> "$AF_LOG" 2>&1
echo "$(date '+%F %T') JOB: сработал (uid=$(id -u), cg=$(sed -n 's/^0:://p' /proc/self/cgroup))"
if af_daemon_alive >/dev/null; then
  echo "$(date '+%F %T') JOB: демон жив (pid $(af_daemon_alive)), выходим"
  exit 0
fi
echo "$(date '+%F %T') JOB: демон мёртв -> реанимация"
setsid "$AF_DIR/antifreeze-daemon.sh" >/dev/null 2>&1 &
echo "$(date '+%F %T') JOB: демон перезапущен"
