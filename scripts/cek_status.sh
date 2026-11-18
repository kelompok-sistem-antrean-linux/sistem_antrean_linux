#!/bin/bash
source "$(dirname "$0")/../config/queue.conf"
echo "=== TABEL STATUS PEKERJAAN ==="
column -t -s',' "$STATUS_DB"
