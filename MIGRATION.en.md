# Миграция Termux на новый телефон

Комплект: `TermuxMigration/` (папку скопируй на новый телефон в /storage/emulated/0)

- `termux-prefix.tar.zst` — весь $PREFIX: дистрибутив Termux, все пакеты, pip-пакеты
- `home-essentials.tar.zst` — домашний каталог без кэшей и билд-артефактов
- `SHA256SUMS` — контрольные суммы (проверь до распаковки!)

## Шаг 0. На новом телефоне (до запуска Termux)

Установи **из одного источника** (все F-Droid или все GitHub-релизы одной версии):
Termux, Termux:API, Termux:Boot, Termux:Widget, Termux:X11, Termux:Styling, Termux:Tasker
Важно: подписи приложений должны совпадать — из F-Droid все, или все с GitHub.

**Требование к железу нового телефона:** aarch64 (любой современный), Android 12+.
Рекомендация: с минимум 6 ГБ ОЗУ (лучше 8+), UFS-хранилище, батареей 5000+ мАч,
но выбор модели за тобой — миграция работает на любом совместимом.

## Шаг 1. Первичный запуск

Открой Termux один раз, чтобы он создал структуру каталогов, затем закрой.

## Шаг 2. Проверка сумм (обязательно!)

```bash
cd /storage/emulated/0/TermuxMigration
sha256sum -c SHA256SUMS   # должно быть OK для обоих файлов
```

# Шаг 3. Восстановление PREFIX (на новом телефоне)

```bash
# свежеустановленный Termux: остановить всё лишнее
sv down sshd 2>/dev/null; pkill -f mpv 2>/dev/null

# восстановить
zstd -dc termux-prefix.tar.zst | termux-restore -
```

## Шаг 4. Восстановление HOME

```bash
cd $HOME
zstd -dc /storage/emulated/0/TermuxMigration/home-essentials.tar.zst | tar -xf -
```

## Шаг 5. Антифриз на новом устройстве

```bash
bash ~/antifreeze/antifreeze-install.sh
bash ~/antifreeze/af-status
```

## Шаг 6. Гитхаб-ключи и прочее

Проверь: `gh auth status`, `git ls-remote` — ключи переезжают внутри PREFIX/HOME.
При смене устройства GitHub может попросить re-auth: `gh auth refresh`.

## Не переезжает (и не должно)

- `~/omp-*-src/target/` — Rust-билдартефакты, пересобери `cargo build --release` на новом
- `~/.npm`, `~/.cache` — кэши, восстанавливаются автоматически
- `~/nightly/` — rust-дистрибутивы; tar.xz есть внутри home-архива, распакуй при нужде
- shared-storage (фото/музыка) — копируй как обычные файлы (USB/облако)

## Если что-то пойдёт не так

PREFIX и HOME архивы независимы: можно восстановить только PREFIX (получишь рабочий
терминал с пакетами), а HOME донести позже. termux-restore не трогает shared-storage.
