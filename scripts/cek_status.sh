#!/bin/bash

source "$(dirname "$0")/../config/queue.conf"

if [ ! -f "$STATUS_DB" ]; then
    echo "[INFO] Database status belum tersedia."
    exit 0
fi

echo "========== STATUS SELURUH JOB =========="
column -t -s',' "$STATUS_DB"
