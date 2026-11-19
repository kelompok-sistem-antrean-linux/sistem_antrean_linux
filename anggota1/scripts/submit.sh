
#!/bin/bash

# ==========================================
# PROJECT 5B - SISTEM ANTREAN PEKERJAAN
# Anggota 1: Pengajuan Pekerjaan
# ==========================================

set -Eeuo pipefail

# Menentukan direktori utama proyek
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE_DIR="$PROJECT_DIR/queue/pending"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/submission.log"

# Membuat direktori jika belum tersedia
mkdir -p "$QUEUE_DIR" "$LOG_DIR"

# Fungsi untuk mencatat aktivitas
write_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Fungsi menampilkan penggunaan program
usage() {
    echo "Penggunaan:"
    echo "./scripts/submit.sh <nama_pekerjaan> <durasi>"
    echo
    echo "Pekerjaan yang tersedia:"
    echo "  normal  : Pekerjaan normal"
    echo "  fail    : Pekerjaan simulasi gagal"
    echo "  slow    : Pekerjaan simulasi lambat"
    echo
    echo "Durasi: 1 sampai 300 detik"
}

# Memeriksa jumlah parameter
if [[ $# -ne 2 ]]; then
    echo "ERROR: Jumlah parameter tidak sesuai."
    usage
    write_log "PENOLAKAN: Jumlah parameter tidak valid"
    exit 1
fi

JOB_NAME="$1"
DURATION="$2"

# Memvalidasi nama pekerjaan
case "$JOB_NAME" in
    normal|fail|slow)
        ;;
    *)
        echo "ERROR: Pekerjaan '$JOB_NAME' tidak diizinkan."
        write_log "PENOLAKAN: Pekerjaan tidak valid: $JOB_NAME"
        exit 2
        ;;
esac

# Memvalidasi format durasi
if [[ ! "$DURATION" =~ ^[0-9]+$ ]] || [[ ${#DURATION} -gt 3 ]]; then
    echo "ERROR: Durasi harus berupa angka."
    write_log "PENOLAKAN: Format durasi tidak valid"
    exit 3
fi

# Mengubah angka menjadi format desimal
DURATION=$((10#$DURATION))

# Memvalidasi batas durasi
if (( DURATION < 1 || DURATION > 300 )); then
    echo "ERROR: Durasi harus antara 1 sampai 300 detik."
    write_log "PENOLAKAN: Durasi di luar batas"
    exit 4
fi

# Membuat ID pekerjaan berdasarkan waktu dan identitas proses
JOB_ID="$(date +%s%N)-$$-$RANDOM"

# Menentukan waktu pengajuan
SUBMITTED_AT="$(date '+%Y-%m-%d %H:%M:%S')"

# Membuat file sementara pada direktori antrean
TEMP_FILE="$(mktemp "$QUEUE_DIR/.tmp.XXXXXX")"

# Menghapus file sementara jika proses gagal
trap 'rm -f "$TEMP_FILE"' EXIT

# Menulis informasi pekerjaan
{
    echo "id=$JOB_ID"
    echo "job=$JOB_NAME"
    echo "duration=$DURATION"
    echo "submitted_at=$SUBMITTED_AT"
    echo "status=waiting"
} > "$TEMP_FILE"

# Memasukkan pekerjaan ke antrean secara atomik
QUEUE_FILE="$QUEUE_DIR/$JOB_ID.job"
mv -- "$TEMP_FILE" "$QUEUE_FILE"

# Mencatat aktivitas pengajuan
write_log "PENERIMAAN: ID=$JOB_ID JOB=$JOB_NAME DURASI=$DURATION"

echo "=================================="
echo " PENGAJUAN PEKERJAAN BERHASIL"
echo "=================================="
echo "ID Pekerjaan : $JOB_ID"
echo "Nama         : $JOB_NAME"
echo "Durasi       : $DURATION detik"
echo "Waktu        : $SUBMITTED_AT"
echo "Status       : WAITING"
echo "Lokasi       : $QUEUE_FILE"
echo "=================================="

exit 0
