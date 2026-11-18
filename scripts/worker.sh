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
    echo "[FIFO] Memproses antrean: $JOB_ID ($JOB_NAME, param=$PARAM)"

    bash "$ALLOWED_JOBS_DIR/$JOB_NAME" "$PARAM" >> "$LOG_FILE" 2>&1
    EXIT_CODE=$?
    END_TIME=$(date '+%F %T')

    mv "$QUEUE_RUN/$BASENAME" "$QUEUE_DONE/$BASENAME"
    echo "$JOB_ID,$JOB_NAME,$PARAM,DONE,-,$EXIT_CODE,$START_TIME,$END_TIME" >> "$STATUS_DB"
    echo "$(date '+%F %T') | FIFO_PROCESSED | ID: $JOB_ID | Order_OK" >> "$LOG_FILE"
done
echo "$(date '+%F %T') | WORKER_LOCK_RELEASED | Worker_PID: $$" >> "$LOG_FILE"
exit 0
