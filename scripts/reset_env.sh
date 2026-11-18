#!/bin/bash
source "$(dirname "$0")/../config/queue.conf"
rm -f "$QUEUE_WAIT"/*.job "$QUEUE_RUN"/*.job "$QUEUE_DONE"/*.job "$QUEUE_FAIL"/*.job "$LOCK_FILE"
echo "JOB_ID,JOB_NAME,PARAM,STATUS,PID,EXIT_CODE,START_TIME,END_TIME" > "$STATUS_DB"
: > "$LOG_FILE"
echo "[RESET] Lingkungan antrean dan log berhasil dipulihkan ke kondisi awal."
