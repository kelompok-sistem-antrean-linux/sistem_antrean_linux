#!/bin/bash
DURASI=${1:-2}
echo "[JOB] Komputasi dummy selama $DURASI detik (PID: $$)..."
END=$((SECONDS + DURASI))
while [ $SECONDS -lt $END ]; do
    echo "scale=500; 4*a(1)" | bc -l >/dev/null 2>&1
done
echo "[JOB] Selesai."
exit 0
