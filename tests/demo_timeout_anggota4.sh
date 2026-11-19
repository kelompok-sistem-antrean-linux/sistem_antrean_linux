#!/usr/bin/env bash
# Reproducible positive and negative demonstration for Anggota 4 (project 5B).

set -u

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "$script_dir/.." && pwd)
runner="$project_dir/scripts/timeout_runner.sh"
evidence_dir=${EVIDENCE_DIR:-"$project_dir/evidence/anggota4-timeout"}
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
run_dir="$evidence_dir/$run_id"

if [[ ! -x $runner ]]; then
  echo "Jadikan scripts/timeout_runner.sh executable sebelum menjalankan demo." >&2
  echo "Contoh: chmod +x '$runner'" >&2
  exit 2
fi
mkdir -p -- "$run_dir" || exit 1

read_field() {
  local key=$1 file=$2
  awk -F= -v wanted="$key" '$1 == wanted { print substr($0, index($0, "=") + 1); exit }' "$file"
}

echo "[POSITIF] Pekerjaan selesai sebelum batas 5 detik."
"$runner" 5 "$run_dir/positive.status" "$run_dir/positive.log" -- \
  bash -c 'sleep 1; printf "PEKERJAAN_POSITIF_SELESAI\n"'
positive_rc=$?
positive_state=$(read_field state "$run_dir/positive.status")

if (( positive_rc != 0 )) || [[ $positive_state != succeeded ]] || \
  ! grep -q 'PEKERJAAN_POSITIF_SELESAI' "$run_dir/positive.log"; then
  echo "GAGAL: skenario positif tidak sesuai hasil yang diharapkan." >&2
  exit 1
fi
echo "LULUS: exit status=$positive_rc, state=$positive_state"

echo "[NEGATIF] Pekerjaan 10 detik dihentikan oleh batas 2 detik."
"$runner" 2 "$run_dir/negative.status" "$run_dir/negative.log" -- \
  bash -c 'printf "PEKERJAAN_NEGATIF_DIMULAI\n"; sleep 10; printf "PENANDA_TIDAK_BOLEH_MUNCUL\n"'
negative_rc=$?
negative_state=$(read_field state "$run_dir/negative.status")
negative_duration=$(read_field duration_seconds "$run_dir/negative.status")

if (( negative_rc != 124 )) || [[ $negative_state != timed_out ]] || \
  grep -q 'PENANDA_TIDAK_BOLEH_MUNCUL' "$run_dir/negative.log"; then
  echo "GAGAL: skenario timeout tidak sesuai hasil yang diharapkan." >&2
  exit 1
fi
if [[ ! $negative_duration =~ ^[0-9]+$ ]] || (( negative_duration < 2 || negative_duration > 10 )); then
  echo "GAGAL: durasi timeout di luar rentang pemeriksaan: $negative_duration detik." >&2
  exit 1
fi
echo "LULUS: exit status=$negative_rc, state=$negative_state, durasi=${negative_duration}s"

echo
echo "Bukti demo tersimpan di: $run_dir"
echo "Periksa berkas *.status dan *.log; keduanya hanya memakai data uji dummy."
