#!/bin/bash
source "$(dirname "$0")/../config/queue.conf"
JOB_NAME="$1"
PARAM="$2"

if [ ! -w "$QUEUE_WAIT" ]; then
    echo "[ERROR] Akses ditolak: Anda bukan anggota grup labqueue." >&2
    exit 13
fi
if [ -z "$JOB_NAME" ] || [ -z "$PARAM" ]; then
    echo "[ERROR] Penggunaan: $0 <nama_script.sh> <angka_1_sd_60>" >&2
    exit 1
fi
if [[ "$JOB_NAME" == *"/"* ]] || [ ! -f "$ALLOWED_JOBS_DIR/$JOB_NAME" ]; then
    echo "[ERROR] Pekerjaan '$JOB_NAME' tidak terdaftar dalam whitelist!" >&2
    echo "$(date '+%F %T') | SUBMIT_REJECTED | User: $USER | Job: $JOB_NAME | Whitelist error" >> "$LOG_FILE"
    exit 2
fi
if ! [[ "$PARAM" =~ ^[1-9][0-9]*$ ]] || [ "$PARAM" -gt 60 ]; then
    echo "[ERROR] Parameter '$PARAM' tidak valid (wajib angka 1-60)." >&2
    echo "$(date '+%F %T') | SUBMIT_REJECTED | User: $USER | Job: $JOB_NAME | Param error: $PARAM" >> "$LOG_FILE"
    exit 3
fi

JOB_ID="JOB_$(date '+%Y%m%d_%H%M%S_%N')"
cat <<TICKET > "$QUEUE_WAIT/${JOB_ID}.job"
JOB_ID=$JOB_ID
JOB_NAME=$JOB_NAME
PARAM=$PARAM
SUBMITTER=$USER
SUBMIT_TIME=$(date '+%F %T')
TICKET

echo "$JOB_ID,$JOB_NAME,$PARAM,WAITING,-,-,$(date '+%F %T'),-" >> "$STATUS_DB"
echo "$(date '+%F %T') | SUBMIT_OK | ID: $JOB_ID | Job: $JOB_NAME | Param: $PARAM | By: $USER" >> "$LOG_FILE"
echo "[OK] Pekerjaan berhasil masuk antrean: $JOB_ID (Status: WAITING)"
exit 0
