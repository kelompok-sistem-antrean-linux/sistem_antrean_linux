#!/bin/bash
source "$(dirname "$0")/../config/queue.conf"

{
    echo "=================================================================="
    echo "LAPORAN RINGKASAN ANTREAN PEKERJAAN & MONITORING PROSES (PROYEK 5B)"
    echo "Waktu Cetak   : $(date '+%F %T')"
    echo "Kernel & Host : $(uname -srm)"
    echo "=================================================================="
    echo ""
    echo "[1] STATISTIK ANTREAN"
    echo "Menunggu (WAITING)       : $(ls -1 "$QUEUE_WAIT"/*.job 2>/dev/null | wc -l)"
    echo "Berhasil (SUCCESS)       : $(grep -c ',SUCCESS,' "$STATUS_DB" 2>/dev/null || echo 0)"
    echo "Timeout (TIMEOUT_KILLED) : $(grep -c ',TIMEOUT_KILLED,' "$STATUS_DB" 2>/dev/null || echo 0)"
    echo "Gagal (FAILED)           : $(grep -c ',FAILED,' "$STATUS_DB" 2>/dev/null || echo 0)"
    echo ""
    echo "[2] RIWAYAT STATUS EKSEKUSI"
    column -t -s',' "$STATUS_DB" 2>/dev/null || cat "$STATUS_DB"
    echo ""
    echo "[3] PEMANTAUAN MEMORI & CPU HOST"
    free -h
    echo ""
    ps -eo pid,ppid,user,%cpu,%mem,rss,stat,comm --sort=-%cpu | head -n 8
} > "$REPORT_FILE"

echo "[OK] Laporan berhasil dibuat di $REPORT_FILE"
sha256sum "$REPORT_FILE"
exit 0
