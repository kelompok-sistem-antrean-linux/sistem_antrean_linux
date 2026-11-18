#!/bin/bash

source "$(dirname "$0")/../config/queue.conf"

mkdir -p "$QUEUE_WAIT" "$QUEUE_RUN" "$QUEUE_DONE" "$QUEUE_FAIL"
mkdir -p "$ALLOWED_JOBS_DIR" "$(dirname "$LOG_FILE")" "$(dirname "$STATUS_DB")"

if [ ! -f "$STATUS_DB" ] || [ ! -s "$STATUS_DB" ]; then
    echo "JOB_ID,JOB_NAME,PARAM,STATUS,PID,EXIT_CODE,START_TIME,END_TIME" > "$STATUS_DB"
fi

for TICKET in "$QUEUE_WAIT"/*.job; do
    [ -f "$TICKET" ] || continue

    BASENAME=$(basename "$TICKET")

    source "$TICKET"

    START_TIME=$(date '+%F %T')

    mv "$TICKET" "$QUEUE_RUN/$BASENAME"

    if [ ! -f "$ALLOWED_JOBS_DIR/$JOB_NAME" ]; then
        echo "[ERROR] Job tidak ditemukan: $JOB_NAME" >> "$LOG_FILE"
        EXIT_CODE=127
        CHILD_PID=0
    else
        bash "$ALLOWED_JOBS_DIR/$JOB_NAME" "$PARAM" >> "$LOG_FILE" 2>&1 &
        CHILD_PID=$!

        echo "$(date '+%F %T') | JOB_RUNNING | ID: $JOB_ID | Child_PID: $CHILD_PID" >> "$LOG_FILE"

        wait "$CHILD_PID"
        EXIT_CODE=$?
    fi

    END_TIME=$(date '+%F %T')

    if [ "$EXIT_CODE" -eq 0 ]; then
        FINAL_STATUS="SUCCESS"
        mv "$QUEUE_RUN/$BASENAME" "$QUEUE_DONE/$BASENAME"
    else
        FINAL_STATUS="FAILED"
        mv "$QUEUE_RUN/$BASENAME" "$QUEUE_FAIL/$BASENAME"
    fi

    echo "$JOB_ID,$JOB_NAME,$PARAM,$FINAL_STATUS,$CHILD_PID,$EXIT_CODE,$START_TIME,$END_TIME" >> "$STATUS_DB"

    echo "$(date '+%F %T') | $FINAL_STATUS | ID: $JOB_ID | PID: $CHILD_PID | EXIT: $EXIT_CODE" >> "$LOG_FILE"

done

echo "[OK] Worker selesai memproses antrean."
