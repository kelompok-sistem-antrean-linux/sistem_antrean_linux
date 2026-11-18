#!/bin/bash
source "$(dirname "$0")/../config/queue.conf"

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
exit 0
