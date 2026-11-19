#!/usr/bin/env bash
# Apply a bounded runtime to one already-validated queue job.
# Usage: timeout_runner.sh SECONDS STATUS_FILE LOG_FILE -- COMMAND [ARG ...]

set -u
# Keep logs private to the owner and readable by the project group.
umask 027

usage() {
  echo "Usage: $0 SECONDS STATUS_FILE LOG_FILE -- COMMAND [ARG ...]" >&2
  exit 2
}

[[ $# -ge 5 ]] || usage
limit_seconds=$1
status_file=$2
log_file=$3
shift 3
[[ ${1:-} == "--" ]] || usage
shift
[[ $# -gt 0 ]] || usage

if [[ ! $limit_seconds =~ ^[1-9][0-9]{0,3}$ ]] || (( limit_seconds > 3600 )); then
  echo "Batas waktu harus bilangan bulat 1 sampai 3600 detik." >&2
  exit 2
fi

if ! command -v timeout >/dev/null 2>&1; then
  echo "Perintah 'timeout' tidak tersedia (disediakan oleh GNU coreutils)." >&2
  exit 127
fi

status_dir=$(dirname -- "$status_file")
log_dir=$(dirname -- "$log_file")
mkdir -p -- "$status_dir" "$log_dir" || {
  echo "Tidak dapat membuat direktori status/log." >&2
  exit 1
}

start_epoch=$(date +%s) || exit 1
start_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ) || exit 1
job_pid=-
child_pid_file="${status_file}.childpid.$$"
rm -f -- "$child_pid_file"

write_status() {
  local state=$1 exit_status=$2 end_utc=$3 duration=$4
  local temporary_file
  temporary_file=$(mktemp "${status_file}.tmp.XXXXXX") || return 1
  {
    printf 'state=%s\n' "$state"
    printf 'timeout_seconds=%s\n' "$limit_seconds"
    printf 'supervisor_pid=%s\n' "$supervisor_pid"
    printf 'job_pid=%s\n' "$job_pid"
    printf 'exit_status=%s\n' "$exit_status"
    printf 'start_utc=%s\n' "$start_utc"
    printf 'end_utc=%s\n' "$end_utc"
    printf 'duration_seconds=%s\n' "$duration"
    printf 'timeout_signal=TERM\n'
    printf 'kill_after_seconds=3\n'
  } >"$temporary_file" || {
    rm -f -- "$temporary_file"
    return 1
  }
  mv -f -- "$temporary_file" "$status_file"
}

printf '[%s] state=running timeout_seconds=%s\n' "$start_utc" "$limit_seconds" >>"$log_file" || exit 1

# The small Bash wrapper records its PID and then execs the job, preserving
# that PID for process inspection. GNU timeout manages the job's process group.
timeout --signal=TERM --kill-after=3s "${limit_seconds}s" \
  bash -c 'pid_file=$1; shift; printf "%s\n" "$$" >"$pid_file" || exit 125; exec "$@"' \
  _ "$child_pid_file" "$@" >>"$log_file" 2>&1 &
supervisor_pid=$!
for ((attempt = 0; attempt < 50; attempt++)); do
  if [[ -s $child_pid_file ]]; then
    IFS= read -r job_pid <"$child_pid_file"
    break
  fi
  if ! kill -0 "$supervisor_pid" 2>/dev/null; then
    break
  fi
  sleep 0.02
done
rm -f -- "$child_pid_file"
if ! write_status "running" "-" "-" "-"; then
  kill -TERM "$supervisor_pid" 2>/dev/null || true
  wait "$supervisor_pid" 2>/dev/null || true
  echo "Tidak dapat menulis berkas status." >&2
  exit 1
fi

wait "$supervisor_pid"
job_exit_status=$?
end_epoch=$(date +%s) || end_epoch=$start_epoch
end_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ) || end_utc=$start_utc
duration_seconds=$((end_epoch - start_epoch))

if (( job_exit_status == 0 )); then
  final_state=succeeded
elif (( job_exit_status == 124 )); then
  final_state=timed_out
elif (( job_exit_status == 137 && duration_seconds >= limit_seconds )); then
  final_state=force_terminated_after_timeout
else
  final_state=failed
fi

printf '[%s] state=%s exit_status=%s duration_seconds=%s\n' \
  "$end_utc" "$final_state" "$job_exit_status" "$duration_seconds" >>"$log_file"

if ! write_status "$final_state" "$job_exit_status" "$end_utc" "$duration_seconds"; then
  echo "Pekerjaan selesai, tetapi berkas status akhir gagal ditulis." >&2
  exit 1
fi

printf 'state=%s job_pid=%s supervisor_pid=%s exit_status=%s duration_seconds=%s\n' \
  "$final_state" "$job_pid" "$supervisor_pid" "$job_exit_status" "$duration_seconds"
exit "$job_exit_status"
