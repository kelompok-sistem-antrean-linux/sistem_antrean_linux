#!/bin/bash
# File: scripts/worker.sh (Integrasi Final: Ammy, Jennar, Haikal, Abe)
source "$(dirname "$0")/../config/queue.conf"
TIMEOUT_LIMIT=${1:-$DEFAULT_TIMEOUT}

# [JENNAR - Anggota 2B] Exclusive Lock pencegah worker ganda
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  ACTIVE_PID=$(cat "$LOCK_FILE" 2>/dev/null)
  echo "[LOCKED] Worker lain (PID: $ACTIVE_PID) sedang aktif! Eksekusi ditolak." >&2
  echo "$(date '+%F %T') | WORKER_REJECTED | Attempt_PID: $$ | Active_PID: $ACTIVE_PID" >> "$LOG_FILE"
  exit 99
fi
echo "$$" > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT
echo "$(date '+%F %T') | WORKER_START | Worker_PID: $$ | Timeout: ${TIMEOUT_LIMIT}s" >> "$LOG_FILE"

# [AMMY - Anggota 2A] Pengambilan antrean secara FIFO
JOBS=$(ls -1 "$QUEUE_WAIT"/*.job 2>/dev/null | sort)
if [ -z "$JOBS" ]; then
  echo "[INFO] Antrean kosong. Tidak ada pekerjaan untuk diproses."
  exit 0
fi

for TICKET in $JOBS; do
  source "$TICKET"
  BASENAME=$(basename "$TICKET")
  mv "$TICKET" "$QUEUE_RUN/$BASENAME"
  START_TIME=$(date '+%F %T')

  # [ABE - Anggota 4 & HAIKAL - Anggota 3] Timeout + Pelacakan PID anak
  timeout --signal=TERM --kill-after=2s "${TIMEOUT_LIMIT}s" bash "$ALLOWED_JOBS_DIR/$JOB_NAME" "$PARAM" >> "$LOG_FILE" 2>&1 &
  CHILD_PID=$!
  echo "$(date '+%F %T') | JOB_RUNNING | ID: $JOB_ID | Job: $JOB_NAME | PID: $CHILD_PID" >> "$LOG_FILE"

  wait "$CHILD_PID"
  EXIT_CODE=$?
  END_TIME=$(date '+%F %T')

  if [ "$EXIT_CODE" -eq 0 ]; then
    FINAL_STATUS="SUCCESS"
    mv "$QUEUE_RUN/$BASENAME" "$QUEUE_DONE/$BASENAME"
  elif [ "$EXIT_CODE" -eq 124 ] || [ "$EXIT_CODE" -eq 137 ]; then
    FINAL_STATUS="TIMEOUT_KILLED"
    mv "$QUEUE_RUN/$BASENAME" "$QUEUE_FAIL/$BASENAME"
    echo "$(date '+%F %T') | JOB_TIMEOUT | ID: $JOB_ID | PID: $CHILD_PID | Killed (> ${TIMEOUT_LIMIT}s)" >> "$LOG_FILE"
  else
    FINAL_STATUS="FAILED"
    mv "$QUEUE_RUN/$BASENAME" "$QUEUE_FAIL/$BASENAME"
  fi

  echo "$JOB_ID,$JOB_NAME,$PARAM,$FINAL_STATUS,$CHILD_PID,$EXIT_CODE,$START_TIME,$END_TIME" >> "$STATUS_DB"
  echo "[DONE] $JOB_ID | Status: $FINAL_STATUS | PID: $CHILD_PID | Exit: $EXIT_CODE"
done

echo "$(date '+%F %T') | WORKER_FINISHED | Worker_PID: $$" >> "$LOG_FILE"
exit 0
