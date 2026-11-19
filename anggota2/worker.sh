#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"

cd "$DIR" || exit 1

ANTRIAN="antrean.txt"
LOCK="worker.lock"
LOG="logs/worker.log"
STATUS="$ROOT/monitoring/status.sh"

umask 077

mkdir -p logs
touch "$ANTRIAN"
chmod 600 "$ANTRIAN"

exec 9>"$LOCK"

if ! flock -n 9; then
    echo "DITOLAK: Worker lain sedang memproses antrean."
    exit 1
fi

echo "Worker berhasil mendapatkan lock."
echo "Worker mulai memproses antrean."

while [ -s "$ANTRIAN" ]; do

    BARIS="$(head -n 1 "$ANTRIAN")"

    if [ -z "$BARIS" ]; then
        break
    fi

    JOB_ID="${BARIS%%|*}"
    PEKERJAAN="${BARIS#*|}"

    if [ "$JOB_ID" = "$PEKERJAAN" ] || [ -z "$PEKERJAAN" ]; then
        echo "ERROR: Format antrean tidak valid: $BARIS"
        exit 1
    fi

    echo "Mengambil: $JOB_ID - $PEKERJAAN"
    echo "$(date '+%F %T') - Memproses: $JOB_ID - $PEKERJAAN" >> "$LOG"

    if ! "$STATUS" start "$JOB_ID" "$$"; then
        echo "ERROR: Gagal memperbarui status running."
        exit 1
    fi

    TIMEOUT_RUNNER="$ROOT/scripts/timeout_runner.sh"
    TIMEOUT_LIMIT=3
    TIMEOUT_STATUS="logs/timeout_${JOB_ID}.status"
    TIMEOUT_LOG="logs/timeout_${JOB_ID}.log"

    "$TIMEOUT_RUNNER" "$TIMEOUT_LIMIT" "$TIMEOUT_STATUS" "$TIMEOUT_LOG" -- ./pekerjaan_dummy.sh "$PEKERJAAN"
    EXIT_CODE=$?

    if ! "$STATUS" finish "$JOB_ID" "$EXIT_CODE"; then
        echo "ERROR: Gagal memperbarui status akhir."
        exit 1
    fi

    if [ "$EXIT_CODE" -ne 0 ]; then
        echo "ERROR: $PEKERJAAN gagal dijalankan."
        echo "$(date '+%F %T') - GAGAL: $JOB_ID (exit $EXIT_CODE)" >> "$LOG"

        if [ "$EXIT_CODE" -eq 124 ]; then
            echo "Job timeout. Job dikeluarkan dari antrean, worker melanjutkan."

            TEMP="${ANTRIAN}.tmp.$$"

            if ! tail -n +2 "$ANTRIAN" > "$TEMP"; then
                rm -f "$TEMP"
                exit 1
            fi

            chmod 600 "$TEMP"

            if ! mv "$TEMP" "$ANTRIAN"; then
                rm -f "$TEMP"
                exit 1
            fi

            continue
        fi

        echo "Pekerjaan tetap disimpan dalam antrean."
        exit 1
    fi

    TEMP="${ANTRIAN}.tmp.$$"

    if ! tail -n +2 "$ANTRIAN" > "$TEMP"; then
        rm -f "$TEMP"
        exit 1
    fi

    chmod 600 "$TEMP"

    if ! mv "$TEMP" "$ANTRIAN"; then
        rm -f "$TEMP"
        exit 1
    fi

    echo "$(date '+%F %T') - Selesai: $JOB_ID - $PEKERJAAN" >> "$LOG"

done

echo "Antrean kosong."
echo "Worker selesai."
