#!/usr/bin/env bash
set -euo pipefail

DEVBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_env() {
  local f="$DEVBOX_DIR/.env"
  [[ -f "$f" ]] && { set -a; source "$f"; set +a; }
  APP_PORT_RANGE="${APP_PORT_RANGE:-8000-8015}"
  VITE_PORT_RANGE="${VITE_PORT_RANGE:-5173-5199}"
}

ensure_up() {
  # Проверяем, что контейнеры devbox существуют и запущены
  if ! docker compose -f "$DEVBOX_DIR/docker-compose.yml" ps >/dev/null 2>&1; then
    echo "❌ Сначала подними devbox: (cd $DEVBOX_DIR && docker compose up -d --build)"; exit 1;
  fi
  # Проверяем, что workspace доступен (контейнер присутствует и не остановлен)
  if ! docker compose -f "$DEVBOX_DIR/docker-compose.yml" ps -q workspace | grep -q .; then
    echo "❌ Workspace не запущен. Выполни: (cd $DEVBOX_DIR && docker compose up -d --build)"; exit 1;
  fi
}

freeport() {
  local range="$1"; local start="${range%-*}" end="${range#*-}"
  local has_ss=0 has_lsof=0
  command -v ss >/dev/null && has_ss=1
  command -v lsof >/dev/null && has_lsof=1
  # Определяем, запущен ли workspace (значит, диапазоны портов уже опубликованы Docker)
  local workspace_up=0
  if docker compose -f "$DEVBOX_DIR/docker-compose.yml" ps -q workspace >/dev/null 2>&1; then
    if [[ -n "$(docker compose -f "$DEVBOX_DIR/docker-compose.yml" ps -q workspace 2>/dev/null)" ]]; then
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

dex()  { local wd="$1"; shift; docker compose -f "$DEVBOX_DIR/docker-compose.yml" exec  -w "$wd" workspace "$@"; }
dexd() { local wd="$1"; shift; docker compose -f "$DEVBOX_DIR/docker-compose.yml" exec -d -w "$wd" workspace "$@"; }
