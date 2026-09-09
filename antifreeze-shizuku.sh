#!/data/data/com.termux/files/usr/bin/bash
# antifreeze-shizuku.sh — запусти ДОМА после старта Shizuku (через беспроводную отладку).
# Отключает механизмы ОС, которые морозят/усыпляют Termux, средствами shell-uid (через rish).
# Использование: bash ~/antifreeze/antifreeze-shizuku.sh
set -u
export RISH_APPLICATION_ID=com.termux
RISH="$HOME/rish"

[ -x "$RISH" ] || { echo "FAIL: $RISH не найден"; exit 1; }

r() { echo "\$ $*"; "$RISH" "$@" 2>&1; echo; }

echo "== antifreeze-shizuku: применение системных твиков (shell-uid) =="

# 1. Doze whitelist для Termux (глобальный, переживает перезагрузку)
r cmd deviceidle whitelist +com.termux

# 2. Полное отключение Deep Doze (переживает перезагрузку; вернуть: cmd deviceidle enable)
r cmd deviceidle disable

# 3. Отключение cached_apps_freezer (cgroup-заморозка кэшированных приложений; переживает перезагрузку;
#    вернуть: settings put global cached_apps_freezer default)
r settings put global cached_apps_freezer disabled

# 4. Termux в EXEMPT standby-бакете (не подлежит App Standby; сбрасывается ребутом/режимом —
#    поэтому скрипт можно повторять, безвредно)
r am set-standby-bucket com.termux exempt

echo "== Диагностика =="
r dumpsys deviceidle whitelist | grep -i termux
r settings get global cached_apps_freezer
r am get-standby-bucket com.termux
r dumpsys deviceidle \| head -n 15

echo "== Готово. Проверь вывод выше: whitelist=**termux**, freezer=disabled, bucket=EXEMPT(5) =="
echo "== После перезагрузки телефона перезапусти Shizuku и этот скрипт =="
