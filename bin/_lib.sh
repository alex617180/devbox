#!/usr/bin/env bash
set -euo pipefail

DEVBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WS_SERVICE=""  # workspace83|workspace74 (определяется в load_env)

load_env() {
  local f="$DEVBOX_DIR/.env"
  [[ -f "$f" ]] && { set -a; source "$f"; set +a; }

  # Выбор workspace по приоритету: DEVBOX_PHP env → DEFAULT_PHP из .env → 83
  local php_sel="${DEVBOX_PHP:-${DEFAULT_PHP:-83}}"
  case "$php_sel" in
    83|8.3|8.3-cli) WS_SERVICE="workspace83" ;;
    74|7.4|7.4-cli) WS_SERVICE="workspace74" ;;
    *) WS_SERVICE="workspace83" ;;
  esac

  # Подставим workspace-специфичные порты/диапазоны в общие переменные,
  # чтобы существующие скрипты могли их использовать без изменений.
  if [[ "$WS_SERVICE" == "workspace83" ]]; then
    APP_PORT="${APP_PORT_83:-${APP_PORT:-}}"
    VITE_PORT="${VITE_PORT_83:-${VITE_PORT:-}}"
    APP_PORT_RANGE="${APP_PORT_RANGE_83:-${APP_PORT_RANGE:-28080-28120}}"
    VITE_PORT_RANGE="${VITE_PORT_RANGE_83:-${VITE_PORT_RANGE:-28130-28180}}"
  else
    APP_PORT="${APP_PORT_74:-${APP_PORT:-}}"
    VITE_PORT="${VITE_PORT_74:-${VITE_PORT:-}}"
    APP_PORT_RANGE="${APP_PORT_RANGE_74:-${APP_PORT_RANGE:-28200-28240}}"
    VITE_PORT_RANGE="${VITE_PORT_RANGE_74:-${VITE_PORT_RANGE:-28250-28290}}"
  fi
}

ensure_up() {
  # Проверяем, что контейнеры devbox существуют и запущены
  if ! docker compose -f "$DEVBOX_DIR/docker-compose.yml" ps >/dev/null 2>&1; then
    echo "❌ Сначала подними devbox: (cd $DEVBOX_DIR && docker compose up -d --build)"; exit 1;
  fi
  # Проверяем, что workspace доступен (контейнер присутствует и не остановлен)
  local ws="${WS_SERVICE:-workspace83}"
  if ! docker compose -f "$DEVBOX_DIR/docker-compose.yml" ps -q "$ws" | grep -q .; then
    echo "❌ ${ws} не запущен. Выполни: (cd $DEVBOX_DIR && docker compose up -d --build)"; exit 1;
  fi
}

freeport() {
  local range="$1"; local start="${range%-*}" end="${range#*-}"
  local has_ss=0 has_lsof=0
  command -v ss >/dev/null && has_ss=1
  command -v lsof >/dev/null && has_lsof=1
  # Определяем, запущен ли workspace (значит, диапазоны портов уже опубликованы Docker)
  local workspace_up=0
  local ws="${WS_SERVICE:-workspace83}"
  if docker compose -f "$DEVBOX_DIR/docker-compose.yml" ps -q "$ws" >/dev/null 2>&1; then
    if [[ -n "$(docker compose -f "$DEVBOX_DIR/docker-compose.yml" ps -q "$ws" 2>/dev/null)" ]]; then
      workspace_up=1
    fi
  fi
  for ((p=start; p<=end; p++)); do
    if [[ $has_ss -eq 1 ]]; then
      # Смотрим слушателей с отображением процессов (-p). Если слушает только docker-proxy (публикация порта Docker), считаем порт пригодным.
      local out
      out=$(ss -lntp "( sport = :$p )" 2>/dev/null || true)
      if [[ -z "$out" ]]; then
        echo "$p"; return 0
      fi
      if echo "$out" | grep -q LISTEN; then
        if echo "$out" | grep -q docker-proxy; then
          # если кроме docker-proxy никто не слушает — порт ок
          if ! echo "$out" | grep -v docker-proxy | grep -q LISTEN; then
            echo "$p"; return 0
          fi
        else
          # Если процессы не видны (нет docker-proxy в выводе), но workspace запущен и
          # мы сканируем опубликованные диапазоны — считаем порт пригодным.
          if [[ $workspace_up -eq 1 && ( "$range" == "$APP_PORT_RANGE" || "$range" == "$VITE_PORT_RANGE" ) ]]; then
            echo "$p"; return 0
          fi
        fi
      else
        echo "$p"; return 0
      fi
    elif [[ $has_lsof -eq 1 ]]; then
      # Аналогично — игнорируем docker-proxy
      local out
      out=$(lsof -nP -iTCP:"$p" -sTCP:LISTEN 2>/dev/null || true)
      if [[ -z "$out" ]]; then
        echo "$p"; return 0
      fi
      # есть слушатели — если только docker-proxy, порт ок; иначе fallback как выше
      if ! echo "$out" | awk 'NR>1{print $1}' | grep -qv docker-proxy; then
        echo "$p"; return 0
      fi
      if [[ $workspace_up -eq 1 && ( "$range" == "$APP_PORT_RANGE" || "$range" == "$VITE_PORT_RANGE" ) ]]; then
        echo "$p"; return 0
      fi
    else
      nc -z 127.0.0.1 "$p" >/dev/null 2>&1 || { echo "$p"; return 0; }
    fi
  done
  return 1
}

dex()  { local wd="$1"; shift; local ws="${WS_SERVICE:-workspace83}"; docker compose -f "$DEVBOX_DIR/docker-compose.yml" exec  -w "$wd" "$ws" "$@"; }
dexd() { local wd="$1"; shift; local ws="${WS_SERVICE:-workspace83}"; docker compose -f "$DEVBOX_DIR/docker-compose.yml" exec -d -w "$wd" "$ws" "$@"; }
