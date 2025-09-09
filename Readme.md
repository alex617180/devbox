# PHP Devbox: локальная среда для Laravel/Node

Универсальная Docker‑среда для разработки сразу нескольких PHP/Laravel проектов с единым MySQL и удобными шорткатами для `artisan`, `vite`, `composer`, `npm`. Работает на Linux/macOS/WSL.

— services: `workspace` (PHP + Node + Composer + Xdebug) и `mysql`
— монтируется корневая папка с вашими проектами (по умолчанию `../`)
— автоподбор свободных портов для `artisan serve` и Vite

## Требования
- Docker и Docker Compose
- Папка с проектами, расположенная рядом с devbox (по умолчанию монтируется `../`)

## Быстрый старт
1) Поднимите окружение из папки devbox:

   `docker compose up -d --build`

2) Зайдите в любой проект (из смонтированной папки `../`, в контейнере он будет как `/var/www/<project>`):

   `workon my-project`

   Внутри контейнера выполните типовую инициализацию Laravel:
   - `composer install`
   - `cp .env.example .env`
   - `php artisan key:generate`
   - (опционально) настройте `.env` проекта на MySQL из devbox: `DB_HOST=mysql`, `DB_PORT=3306`, `DB_USERNAME=laravel`, `DB_PASSWORD=secret`, `DB_DATABASE=<имя_бд>`

3) Запустите Laravel и Vite одной командой:

   `dev my-project`

   Или по отдельности:
   - `serve my-project 8001`
   - `vite  my-project 5175`

Ссылки будут в выводе: `http://localhost:<порт>`.

## Состав окружения
- workspace: PHP `${PHP_TAG:-8.3-cli}`, Node `${NODE_MAJOR:-20}`, Composer, Xdebug; рабочая директория `/var/www`
- mysql: образ `mysql:8.4`, проброшен порт `${MYSQL_PORT:-3306}`
- volumes: `mysql_data`, `composer_cache`, `node_cache`
- порты для приложений: `${APP_PORT}`; для Vite: `${VITE_PORT}` (фиксированные значения из .env)

Файлы:
- `docker-compose.yml` — описание сервисов
- `workspace/Dockerfile` — PHP/Node/Composer/Xdebug
- `workspace/xdebug.ini` — конфиг Xdebug
- `.env.example` — пример настроек devbox
- `bin/*` — утилиты для повседневной работы

## Переменные окружения (devbox/.env)
- `HOST_PROJECTS_DIR` — что монтировать в `/var/www` (по умолчанию `../`)
- `PHP_TAG` — версия PHP для workspace (например, `8.2-cli`, `8.3-cli`)
- `NODE_MAJOR` — мажорная версия Node (например, `18`, `20`, `22`)
- `MYSQL_PORT` — внешний порт MySQL
- `APP_PORT` — фиксированный порт публикации для PHP‑приложения (Compose)
- `VITE_PORT` — фиксированный порт публикации для Vite (Compose)
- `APP_PORT_RANGE` — диапазон портов для автоподбора, используется скриптами если `APP_PORT` не задан
- `VITE_PORT_RANGE` — диапазон портов для автоподбора, используется скриптами если `VITE_PORT` не задан
- `XDEBUG_MODE` — режим Xdebug (`debug`, `off`, …)

Все значения имеют дефолты; можно не создавать `.env`, но рекомендуется скопировать `.env.example` и при необходимости подредактировать.

## База данных MySQL
- Хост/порт для проектов: `DB_HOST=mysql`, `DB_PORT=3306`
- Пользователь/пароль по умолчанию: `laravel`/`secret` (меняется через `.env` devbox)
- Рут‑доступ для утилит: `root`/`$DB_ROOT_PASSWORD` (по умолчанию `root`)

Создать БД для проекта:
`db-ensure my-project [имя_бд] [db_user] [db_password]`

Если имя БД не передано, используется безопасное имя на основе имени папки проекта. По умолчанию логин/пароль берутся из devbox/.env (`DB_USERNAME`/`DB_PASSWORD`) или `laravel`/`secret`. Можно явно указать пользователя и пароль третьим и четвертым аргументами. Команда создаст БД, пользователя (если нет) и выдаст права.

Примеры:
- `db-ensure my-app` — БД `my_app`, пользователь из `.env` или `laravel/secret`
- `db-ensure my-app shop_db` — БД `shop_db`, пользователь по умолчанию
- `db-ensure my-app shop_db shop_user s3cr3t` — БД `shop_db`, пользователь `shop_user` с паролем `s3cr3t`

Открыть консоль MySQL:
`dbsh`

Можно управлять логином/паролем и базой через переменные `DB_USERNAME`, `DB_PASSWORD`, `DB_DATABASE` в devbox/.env.

## Повседневные команды (`bin/*`)
- `workon <project>`: интерактивная оболочка в `/var/www/<project>` контейнера workspace
- `dev <project>`: запустить сразу `artisan serve` и `vite` на свободных портах, показать ссылки
- `serve <project> [port]`: только Laravel (`php artisan serve --host=0.0.0.0 --port=<port>`)
- `vite <project> [port]`: только Vite (`npm run dev -- --host --strictPort --port <port>`)
- `stop <project>`: остановить процессы `serve` и `vite` проекта, очистить логи
- `ps <project>`: показать процессы `serve`/`vite` внутри workspace для проекта
- `logs <project> [all|serve|vite]`: вывести хвосты логов `/tmp/*-<project>-*.log`
- `composer <project> …`: выполнить `composer …` в папке проекта
- `npm <project> …`: выполнить `npm …` в папке проекта
- `use-php <8.2-cli|8.3-cli|…>`: сменить версию PHP (пересоберёт workspace)
- `use-node <18|20|22>`: сменить мажорную версию Node (пересоберёт workspace)

Под капотом все команды используют `docker compose exec` с рабочей директорией проекта и UID/GID текущего пользователя, чтобы не ломать права на файлах.

## Xdebug
- Конфиг в `workspace/xdebug.ini`; по умолчанию включён `xdebug.mode=${XDEBUG_MODE:-debug}`
- Клиент: `host.docker.internal:9003` (добавлен `extra_hosts` для Linux)
- Для IDE (PhpStorm/VSC): настройте путь‑маппинг проекта на `/var/www/<project>`; `PHP_IDE_CONFIG=serverName=php-devbox`

Чтобы временно отключить Xdebug: установите `XDEBUG_MODE=off` в devbox/.env и перезапустите workspace (`docker compose up -d workspace`).

## Типичные сценарии
— Новый проект Laravel в папке `../my-api`:
1. `docker compose up -d --build`
2. `workon my-api`
3. `composer create-project laravel/laravel .`
4. `db-ensure my-api my_api`
5. Настройте `.env` проекта: `DB_HOST=mysql`, `DB_PORT=3306`, `DB_DATABASE=my_api`, `DB_USERNAME=laravel`, `DB_PASSWORD=secret`
6. `dev my-api`

— Существующий проект:
1. `docker compose up -d --build`
2. `workon existing-app`
3. `composer install && php artisan key:generate`
4. `db-ensure existing-app` (или укажите своё имя БД)
5. `dev existing-app`

## Обслуживание и управление
- Построить/обновить workspace: `docker compose build workspace`
- Перезапустить сервисы: `docker compose up -d`
- Остановить всё: `docker compose down` (данные БД сохранятся в `mysql_data`)

## Тонкости и советы
- Порты: если в диапазоне не осталось свободных, команды сообщат об ошибке — расширьте `APP_PORT_RANGE`/`VITE_PORT_RANGE` в devbox/.env
- Порты: Docker может «занимать» опубликованные порты через `docker-proxy`. Скрипты учитывают это и считают такие порты пригодными. Если реально порт занят сторонним процессом — измените диапазон `APP_PORT_RANGE`/`VITE_PORT_RANGE` или освободите порт.
 - Порты: если `ss -p`/`lsof` не показывают имена процессов без sudo и кажется, что порты заняты, но devbox уже поднят — скрипты всё равно выберут порт из опубликованного диапазона, т.к. его слушает `docker-proxy` и он пригоден для проксирования в контейнер.
- Права на файлы: контейнер запускается под вашим UID/GID (`user: "${UID:-1000}:${GID:-1000}"`), чтобы избежать `root`‑файлов
 - Права npm‑кэша: если видите `npm ERR! EACCES` про `/home/dev/.npm`, скрипты `npm`/`vite` автоматически чинят права (`chown` кэш‑тома). При крайней необходимости можно вручную: `docker compose exec -u 0 workspace chown -R 1000:1000 /home/dev/.npm`
- Несколько проектов: devbox поддерживает параллельный запуск, у каждого — свой порт из диапазона
- Бэкенд без Vite: используйте только `serve`, либо запускайте свой сервер самостоятельно в `workon`

## Решение проблем
- «Сначала подними devbox…»: выполните в корне devbox `docker compose up -d --build`
- Порты заняты: расширьте диапазоны или укажите порт вручную: `serve app 8010`, `vite app 5178`
- Нет доступа к БД: проверьте `.env` проекта (`DB_HOST=mysql`, порт 3306) и что `db-ensure` создавал пользователя/права
- Xdebug не подключается: проверьте, что IDE слушает 9003, а `host.docker.internal` доступен; на Linux это настроено через `extra_hosts`
- Node/PHP версия: используйте `use-node`/`use-php`, затем перезапустите workspace
- Laravel не открывается на `artisan serve`:
  - Проверьте путь проекта: `bin/workon <project>` должен открыть оболочку в `/var/www/<project>`.
  - Убедитесь, что есть `artisan` в корне проекта и установлены зависимости: `composer install`, затем `php artisan key:generate`.
  - Если команда `artisan serve` отсутствует в вашем проекте, devbox автоматически запускает fallback `php -S 0.0.0.0:<port> -t public public/index.php`.
  - Логи: `bin/logs <project> serve`. Перезапуск: `bin/stop <project> && bin/dev <project>`.

## Где что лежит в контейнере
- Проекты: `/var/www/<project>` (монтируется из `HOST_PROJECTS_DIR`)
- Кэш Composer: `/tmp/composer`
- Кэш npm: `/home/dev/.npm`
- Логи локальных процессов: `/tmp/serve-*.log`, `/tmp/vite-*.log`
 - Логи локальных процессов: на хосте в `./logs`, в контейнере — `/var/log/devbox` (`serve-*.log`, `vite-*.log`)

Приятной разработки! 🚀
