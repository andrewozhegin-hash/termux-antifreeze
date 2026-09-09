# termux-antifreeze

Многослойный щит, не дающий Android (TECNO HiOS 15 / Android 15) замораживать
Termux при погашенном экране. Без root.

Проблема: при гашении экрана HiOS15 применяет `cached_apps_freezer` (cgroup v2
freezer) и App Standby — процессы Termux замораживаются, SSH/демоны/агенты
умирают. Банальные решения (wake-lock, отключение оптимизации батареи в
настройках, `termux-wake-lock`) не помогают — морозит сама ОС на уровне cgroups.

Решение использует архитектурные особенности Android, которые ОС не может
игнорировать: не прося разрешения, а занимая ресурсы, которые система обязана
оберегать.

## Слои защиты

| # | Слой | Механизм |
|---|------|----------|
| 1 | **Аудио-щит (mpv)** | Беззвучный FLAC-луп играется mpv **в процессе Termux**. Audioserver (AOSP, HiOS его не трогает) обязан считать uid «perceptible» → приложение не может стать cached → cgroup-freezer его не замораживает |
| 2 | **Дефибриллятор (JobScheduler)** | Persisted-job каждые 15 мин выполняется **внутри процесса Termux** (JobScheduler сам размораживает приложение для запуска job). Если демон убит — job его воскрешает |
| 3 | Wake-lock | Переустановка `termux-wake-lock` каждый цикл — CPU не уходит в deep-sleep |
| 4 | CPU-burst | 1-секундный sha256-burst каждую минуту — сбивает эвристику «idle» |
| 5 | Boot | `~/.termux/boot/` + persisted-job переживают перезагрузку телефона |

Опциональный слой 6 — **Shizuku** (`antifreeze-shizuku.sh`, shell-uid):
Doze-whitelist для Termux, отключение Deep Doze и `cached_apps_freezer`
прямо в системных настройках (переживает перезагрузку), standby-бакет EXEMPT.

## Установка

Требования: Termux + приложения **Termux:Boot** и **Termux:API** (из F-Droid),
внутри Termux пакеты:

```bash
pkg install mpv ffmpeg openssl termux-api openssh
git clone https://github.com/andrewozhegin-hash/termux-antifreeze.git ~/antifreeze
bash ~/antifreeze/antifreeze-install.sh
```

Установщик: генерирует беззвучный FLAC, стартует демон, планирует Job 990,
вешает boot-скрипт. Job 991 — резервный.

## Использование

```bash
bash ~/antifreeze/af-status                  # статус всех слоёв
bash ~/antifreeze/antifreeze-install.sh --restart   # перезапуск (после правки конфига)
bash ~/antifreeze/antifreeze-install.sh --remove   # полное удаление
bash ~/antifreeze/antifreeze-shizuku.sh      # системные тврики (нужен запущенный Shizuku)
```

Настройки — `antifreeze.conf` (период цикла, объём CPU-burst, вкл/выкл слоёв,
аудиовыход). После правки — `--restart`.

## Проверка, что не замораживается

```bash
bash ~/antifreeze/af-status
```

- `DAEMON: жив`, `MPV-щит: играет`, `возраст heartbeat` ≤ 2 периодов цикла — всё работает
- В `antifreeze.log` таймстампы циклов идут непрерывно, без провалов — заморозок не было
- Провал в час-два, потом `JOB: демон мёртв -> реанимация` — систему всё же морозила,
  но defibrillator оживил; подключай Shizuku-слой

## Батарея

Аудио-щит и JobScheduler почти не расходуют заряд (беззвучный FLAC ~35 КБ в
памяти, wakelock-плеер). Основной потребитель — CPU-burst: если батарея тает
быстрее комфортного, уменьшите `AF_CPU_MB` (50–150) в `antifreeze.conf`.

## Совместимость

Разработано и проверено на TECNO (HiOS 15, Android 15, API 35). Слои опираются
на AOSP-механизмы (Audioserver, JobScheduler, cached_apps_freezer) — должно
работать на любом Android 11–15 с агрессивным энергосбережением (HiOS,
XOS, itel OS и прочие Transsion-оболочки — целевая аудитория).

## Отказ от ответственности

Система удерживает приложение активным вопреки политике энергосбережения ОС.
Это осознанный трейд: батарея против живых процессов. MIT.
