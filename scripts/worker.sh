#!/bin/bash
source "$(dirname "$0")/../config/queue.conf"

# [JENNAR - Anggota 2B] Exclusive Lock pencegah worker ganda
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    ACTIVE_PID=$(cat "$LOCK_FILE" 2>/dev/null)
    echo "[LOCKED] Worker lain (PID: $ACTIVE_PID) sedang berjalan! Worker kedua ditolak." >&2
    echo "$(date '+%F %T') | WORKER_REJECTED | Attempt_PID: $$ | Active_PID: $ACTIVE_PID" >> "$LOG_FILE"
    exit 99
fi
echo "$$" > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT
echo "$(date '+%F %T') | WORKER_LOCK_ACQUIRED | Worker_PID: $$" >> "$LOG_FILE"

# [AMMY - Anggota 2A] Pengambilan antrean secara berurutan (FIFO)
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

    # [HAIKAL - Anggota 3] Jalankan proses anak di background & tangkap PID
    bash "$ALLOWED_JOBS_DIR/$JOB_NAME" "$PARAM" >> "$LOG_FILE" 2>&1 &
    CHILD_PID=$!
    echo "$(date '+%F %T') | JOB_RUNNING | ID: $JOB_ID | PID: $CHILD_PID" >> "$LOG_FILE"

    wait "$CHILD_PID"
    EXIT_CODE=$?
    END_TIME=$(date '+%F %T')

    if [ "$EXIT_CODE" -eq 0 ]; then
        FINAL_STATUS="SUCCESS"
        mv "$QUEUE_RUN/$BASENAME" "$QUEUE_DONE/$BASENAME"
    else
        FINAL_STATUS="FAILED"
        mv "$QUEUE_RUN/$BASENAME" "$QUEUE_FAIL/$BASENAME"
    fi

    echo "$JOB_ID,$JOB_NAME,$PARAM,$FINAL_STATUS,$CHILD_PID,$EXIT_CODE,$START_TIME,$END_TIME" >> "$STATUS_DB"
    echo "[STATUS] $JOB_ID | PID: $CHILD_PID | Exit: $EXIT_CODE | Hasil: $FINAL_STATUS"
done
echo "$(date '+%F %T') | WORKER_LOCK_RELEASED | Worker_PID: $$" >> "$LOG_FILE"
exit 0
