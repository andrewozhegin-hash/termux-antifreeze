#!/data/data/com.termux/files/usr/bin/bash
# boot-antifreeze.sh — стартует при загрузке телефона (Termux:Boot)
# Ждёт 45 сек (система довключает всё), поднимает демон.
# Job 990 persisted, восстановится сам. Boot-скрипт также читает state/heartbeat
# и если демон был жив незадолго до загрузки — был живой сервис, который нужно продолжить.
sleep 45
d="$(cd "$(dirname "$0")" && pwd)"
. "$d/lib.sh"
# был ли живой сервис перед выключением (heartbeat моложе 10 минут)
last=$(cut -d' ' -f1 "$AF_STATE/heartbeat" 2>/dev/null || echo 0)
now=$(date +%s)
if [ $((now - last)) -lt 600 ]; then
  af_log "BOOT: heartbeat свежий ($((now-last))с назад) — поднимаю демон"
  setsid "$d/antifreeze-daemon.sh" >/dev/null 2>&1 &
else
  af_log "BOOT: heartbeat несвежий ($((now-last))с назад) — демона не было, ждём Job 990"
fi
