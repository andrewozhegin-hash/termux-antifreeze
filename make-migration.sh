#!/data/data/com.termux/files/usr/bin/bash
# make-migration.sh — полный миграционный комплект для переезда на новый телефон.
# Результат: /storage/emulated/0/TermuxMigration/
#   termux-prefix.tar.zst     — весь $PREFIX (дистрибутив + пакеты + pip)
#   home-essentials.tar.zst   — $HOME без регенерируемых кэшей/билд-артефактов
#   SHA256SUMS                — контрольные суммы для проверки на новом устройстве
#   MIGRATION.md              — инструкция по восстановлению
#
# НЕ включает: shared-storage (фото/музыка) — переезжает отдельно как файлы.
# Повторный запуск: --prefix-only / --home-only / полный (по умолчанию).
set -euo pipefail
DEST="/storage/emulated/0/TermuxMigration"
MODE="${1:-all}"

# ---------- exclude-лист для HOME (regenerable) ----------
AF_HOME_EXCLUDES=(
  --exclude='./omp-termux-src/target'
  --exclude='./omp2-src/target'
  --exclude='./omp-termux-binary'
  --exclude='./.npm'
  --exclude='./.cache'
  --exclude='./nightly'
  --exclude='./probe-*'
  --exclude='./storage'   # симлинки на shared-storage — на новом телефоне создаются заново
)

do_prefix() {
  echo "== Бэкап \$PREFIX (termux-backup) =="
  termux-backup "$DEST/termux-prefix.tar.zst" --ignore-read-failure
}

do_home() {
  echo "== Бэкап \$HOME без регенерируемого =="
  cd "$HOME"
  tar --numeric-owner --owner=0 --group=0 "${AF_HOME_EXCLUDES[@]}" -cf - . \
    | zstd -T0 -3 -o "$DEST/home-essentials.tar.zst" -f
}

do_sums() {
  echo "== Контрольные суммы =="
  ( cd "$DEST" && sha256sum termux-prefix.tar.zst home-essentials.tar.zst > SHA256SUMS && cat SHA256SUMS )
}

case "$MODE" in
  all)         do_prefix; do_home; do_sums ;;
  --prefix-only) do_prefix; do_sums ;;
  --home-only)   do_home; do_sums ;;
  --sums-only)   do_sums ;;
  *) echo "Использование: make-migration.sh [all|--prefix-only|--home-only|--sums-only]"; exit 1 ;;
esac

echo "== Итог =="
ls -lh "$DEST"
echo "Готово. Папку TermuxMigration скопируй на новый телефон (или облако)."
