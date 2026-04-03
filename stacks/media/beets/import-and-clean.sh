#!/bin/bash
# =============================================================================
# import-and-clean.sh — Beets import from Deezer downloads + cleanup
# Usage: sudo bash /home/note/music_pipeline/import-and-clean.sh
# =============================================================================

set -euo pipefail

PIPELINE_DIR="/home/note/music_pipeline"
LOG_DIR="${PIPELINE_DIR}/logs"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="${LOG_DIR}/import_${DATE}.log"

DEEZER_DIR="/mnt/downloads/music/deezer"
BEET_LOG="/home/note/docker/data/beets/data/beet.log"
BEETS_CONTAINER="beets"

# Load ntfy credentials
# shellcheck source=/dev/null
source "${PIPELINE_DIR}/.env"

mkdir -p "${LOG_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
ok()   { echo "[$(date '+%H:%M:%S')] ✓ $*"; }
fail() { echo "[$(date '+%H:%M:%S')] ✗ $*"; }

notify() {
  local title="$1"
  local message="$2"
  local priority="${3:-default}"
  local tags="${4:-musical_note}"

  curl -s --max-time 10 \
    -u "${NTFY_USER}:${NTFY_PASSWORD}" \
    -H "Title: ${title}" \
    -H "Priority: ${priority}" \
    -H "Tags: ${tags}" \
    -d "${message}" \
    "${NTFY_URL}/${NTFY_TOPIC}" > /dev/null || true
}

IMPORT_FAILED=0
trap 'on_exit' EXIT

on_exit() {
  if [ "${IMPORT_FAILED}" -ne 0 ]; then
    notify "🔴 Import FAILED" "Beets import failed. Check: ${LOG_FILE}" "high" "rotating_light"
  fi
}

log "========================================"
log "Starting beets import: $(date)"
log "========================================"

# -----------------------------------------------------------------------------
# 1. Count pending albums
# -----------------------------------------------------------------------------
PENDING=$(ls "${DEEZER_DIR}" | wc -l)
log "Pending items in deezer dir: ${PENDING}"

if [ "${PENDING}" -eq 0 ]; then
  log "Nothing to import. Exiting."
  exit 0
fi

# -----------------------------------------------------------------------------
# 2. Snapshot beet.log before import (to detect newly imported paths)
# -----------------------------------------------------------------------------
LOG_LINES_BEFORE=0
if [ -f "${BEET_LOG}" ]; then
  LOG_LINES_BEFORE=$(wc -l < "${BEET_LOG}")
fi

# -----------------------------------------------------------------------------
# 3. Run beet import (non-interactive, quiet fallback = asis)
# -----------------------------------------------------------------------------
log "--- Running beet import ---"
docker exec "${BEETS_CONTAINER}" beet import -q /downloads/music/deezer \
  && ok "beet import completed" \
  || { fail "beet import exited with errors (check beet.log)"; IMPORT_FAILED=1; }

# -----------------------------------------------------------------------------
# 4. Extract imported source paths from beet.log (new lines only)
# -----------------------------------------------------------------------------
log "--- Extracting imported paths for cleanup ---"

IMPORTED_DIRS=()
if [ -f "${BEET_LOG}" ]; then
  # beet logs lines like: "Importing /downloads/music/deezer/Artist - Album [...]"
  mapfile -t IMPORTED_DIRS < <(
    tail -n +"$((LOG_LINES_BEFORE + 1))" "${BEET_LOG}" \
    | grep -E '^(asis|import) /downloads/music/deezer/' \
    | cut -d' ' -f2- \
    | tr ';' '\n' \
    | grep -oP '/downloads/music/deezer/[^/]+' \
    | sort -u \
    | sed 's|/downloads/music/deezer|'"${DEEZER_DIR}"'|'
  )
fi

CLEANED=0
FAILED_CLEAN=0

if [ "${#IMPORTED_DIRS[@]}" -eq 0 ]; then
  log "No imported paths found in beet.log — skipping cleanup"
else
  log "--- Cleaning up ${#IMPORTED_DIRS[@]} imported directories ---"
  for dir in "${IMPORTED_DIRS[@]}"; do
    if [ -d "${dir}" ]; then
      rm -rf "${dir}"
      log "  ✓ Removed: ${dir}"
      ((CLEANED++)) || true
    else
      log "  ⚠ Not found (already removed?): ${dir}"
    fi
  done
fi

# -----------------------------------------------------------------------------
# 5. Summary
# -----------------------------------------------------------------------------
log "========================================"
log "Import done: $(date)"
log "  Cleaned up: ${CLEANED} directories"
log "========================================"

if [ "${IMPORT_FAILED}" -eq 0 ]; then
  notify "✅ Import OK" "Beets import completed. ${CLEANED} albums cleaned from deezer dir." "default" "musical_note"
else
  notify "⚠ Import with errors" "Import finished with errors. Cleaned: ${CLEANED}. Check: ${LOG_FILE}" "high" "warning"
  exit 1
fi
