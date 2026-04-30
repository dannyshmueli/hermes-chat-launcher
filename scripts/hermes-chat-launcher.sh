#!/usr/bin/env bash
set -Eeuo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

APP_NAME="Hermes Chat"
OPENWEBUI_URL="http://localhost:3000"
HERMES_HEALTH_URL="http://127.0.0.1:8642/health"
HERMES_MODELS_URL="http://127.0.0.1:8642/v1/models"
LOG_DIR="$HOME/.hermes/logs"
HERMES_LOG="$LOG_DIR/openwebui-hermes-api.log"
LAUNCHER_LOG="$LOG_DIR/hermes-chat-launcher.log"
OPENWEBUI_CONTAINER="open-webui"
OPENWEBUI_IMAGE="ghcr.io/open-webui/open-webui:main"
OPENWEBUI_VOLUME="open-webui"
HERMES_CMD="${HERMES_CMD:-hermes}"
DOCKER_CMD="${DOCKER_CMD:-docker}"

mkdir -p "$LOG_DIR" "$HOME/bin"
exec > >(tee -a "$LAUNCHER_LOG") 2>&1

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() { printf '[%s] %s\n' "$(ts)" "$*"; }
notify() {
  /usr/bin/osascript -e "display notification \"$1\" with title \"$APP_NAME\"" >/dev/null 2>&1 || true
}
alert() {
  /usr/bin/osascript -e "display alert \"$APP_NAME\" message \"$1\" as warning" >/dev/null 2>&1 || true
}
url_ok() {
  /usr/bin/curl -fsS --max-time "${2:-3}" "$1" >/dev/null 2>&1
}
wait_for_url() {
  local url="$1" name="$2" timeout="${3:-120}" start now
  start=$(date +%s)
  while true; do
    if url_ok "$url" 3; then
      log "$name is ready: $url"
      return 0
    fi
    now=$(date +%s)
    if (( now - start >= timeout )); then
      log "Timed out waiting for $name at $url"
      return 1
    fi
    sleep 2
  done
}
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    alert "Missing command: $1"
    exit 1
  fi
}

docker_ready() {
  "$DOCKER_CMD" info >/dev/null 2>&1
}
start_docker_desktop_if_needed() {
  require_cmd "$DOCKER_CMD"
  if docker_ready; then
    log "Docker is ready"
    return 0
  fi
  log "Docker is not ready; trying to open Docker Desktop"
  /usr/bin/open -a Docker >/dev/null 2>&1 || true
  notify "Starting Docker Desktop…"
  local start now
  start=$(date +%s)
  while ! docker_ready; do
    now=$(date +%s)
    if (( now - start >= 180 )); then
      alert "Docker did not become ready within 3 minutes. Start Docker Desktop, then open Hermes Chat again."
      exit 1
    fi
    sleep 3
  done
  log "Docker became ready"
}

start_hermes_api_if_needed() {
  require_cmd "$HERMES_CMD"
  if url_ok "$HERMES_HEALTH_URL" 3; then
    log "Hermes API server already running"
    return 0
  fi

  log "Starting Hermes API server"
  notify "Starting Hermes API server…"
  API_SERVER_ENABLED=true API_SERVER_HOST=127.0.0.1 API_SERVER_PORT=8642 API_SERVER_MODEL_NAME=hermes-agent \
    nohup "$HERMES_CMD" gateway run >> "$HERMES_LOG" 2>&1 &

  if ! wait_for_url "$HERMES_HEALTH_URL" "Hermes API server" 90; then
    alert "Hermes API server failed to start. Log: $HERMES_LOG"
    exit 1
  fi
  url_ok "$HERMES_MODELS_URL" 5 || true
}

ensure_openwebui_container() {
  start_docker_desktop_if_needed

  "$DOCKER_CMD" volume create "$OPENWEBUI_VOLUME" >/dev/null

  if "$DOCKER_CMD" ps --format '{{.Names}}' | grep -qx "$OPENWEBUI_CONTAINER"; then
    log "Open WebUI container already running"
    return 0
  fi

  if "$DOCKER_CMD" ps -a --format '{{.Names}}' | grep -qx "$OPENWEBUI_CONTAINER"; then
    log "Starting existing Open WebUI container"
    notify "Starting Open WebUI…"
    "$DOCKER_CMD" start "$OPENWEBUI_CONTAINER" >/dev/null
  else
    log "Creating Open WebUI container"
    notify "Installing Open WebUI container…"
    "$DOCKER_CMD" run -d \
      -p 3000:8080 \
      --add-host=host.docker.internal:host-gateway \
      -v "$OPENWEBUI_VOLUME:/app/backend/data" \
      -e ENABLE_OLLAMA_API=false \
      -e ENABLE_OPENAI_API=true \
      -e OPENAI_API_BASE_URLS=http://host.docker.internal:8642/v1 \
      -e OPENAI_API_KEYS=sk-local-hermes \
      -e WEBUI_SECRET_KEY=local-hermes-open-webui-secret \
      --name "$OPENWEBUI_CONTAINER" \
      --restart unless-stopped \
      "$OPENWEBUI_IMAGE" >/dev/null
  fi

  if ! wait_for_url "$OPENWEBUI_URL/api/config" "Open WebUI" 240; then
    alert "Open WebUI failed to start. Check: docker logs open-webui"
    exit 1
  fi
}

open_chat() {
  log "Opening $OPENWEBUI_URL"
  /usr/bin/open "$OPENWEBUI_URL"
  notify "Hermes Chat is ready"
}

main() {
  log "--- Launch requested ---"
  start_hermes_api_if_needed
  ensure_openwebui_container
  open_chat
  log "Done"
}

main "$@"
