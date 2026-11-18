# Skenario Pengujian Sistem Antrean (`proyek-so-5b`)

## 1. Pengujian Positif
| No | Modul / Fitur | Langkah Pengujian | Hasil yang Diharapkan |
| :--- | :--- | :--- | :--- |
| 1 | Pengajuan & Eksekusi Antrean (`submit_job.sh`, `worker.sh`) | Kirim tiket tugas valid menggunakan data `tests/dummy_valid.job`, lalu jalankan `bash scripts/worker.sh`. | Tugas diproses berurutan (FIFO), proses selesai normal dengan status `SUCCESS` (exit code `0`) saat dicek melalui `cek_status.sh`. |
| 2 | Pelaporan & Integritas (`monitor_report.sh`) | Jalankan `bash scripts/monitor_report.sh` setelah antrean selesai diproses. | Berkas laporan terbentuk disertai nilai hash SHA-256 yang valid. |

## 2. Pengujian Negatif
| No | Modul / Fitur | Langkah Pengujian | Hasil yang Diharapkan |
| :--- | :--- | :--- | :--- |
| 1 | Validasi Input (`submit_job.sh`) | Ajukan tiket menggunakan data tidak valid (`tests/dummy_invalid.job`) atau perintah di luar `jobs_allowed/`. | Sistem menolak pengajuan tugas dan menampilkan pesan peringatan validasi. |
| 2 | Pencegahan Worker Ganda (`flock`) | Jalankan dua proses `bash scripts/worker.sh` secara bersamaan di dua terminal berbeda. | Worker pertama berjalan normal; worker kedua ditolak otomatis dengan pesan terkunci (exit code `99`). |
| 3 | Penolakan Hak Akses (`2770` & `labqueue`) | Jalankan perintah `touch queue/waiting/test_ilegal.job` menggunakan akun non-anggota grup (`guest_user`). | Akses ditolak oleh sistem operasi dengan galat `Permission denied` (exit code `13`). |
| 4 | Isolasi Volume Docker (`readonly`) | Jalankan kontainer Alpine dengan mount `evidence/` mode `readonly`, lalu jalankan `touch /data/uji_tulis.txt`. | Penulisan berkas gagal dengan pesan galat `Read-only file system`. |
