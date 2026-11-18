#!/bin/bash
DURASI=${1:-10}
echo "[JOB] Proses panjang selama $DURASI detik (PID: $$)..."
sleep "$DURASI"
exit 0
