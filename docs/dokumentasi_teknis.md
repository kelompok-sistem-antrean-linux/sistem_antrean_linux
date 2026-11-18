# Dokumentasi Teknis Sistem Antrean Tugas (`proyek-so-5b`)

## 1. Susunan Folder Proyek
- `config/`: Menyimpan file pengaturan utama (`queue.conf`) yang berisi lokasi folder kerja sistem.
- `jobs_allowed/`: Daftar skrip atau perintah yang boleh dijalankan oleh sistem antrean (*whitelist*).
- `scripts/`: Kumpulan skrip inti yang mengatur jalannya antrean (`submit_job.sh`, `worker.sh`, `cek_status.sh`, `monitor_report.sh`).
- `tests/`: Berisi skenario pengujian (positif dan negatif) beserta data *dummy* untuk simulasi.
- `evidence/`: Kumpulan log dan bukti hasil pengujian yang sudah dibersihkan dari data sensitif.
- `docs/`: Dokumentasi teknis dan file laporan akhir kelompok.

## 2. Cara Kerja Sistem
1. **Pengajuan & Validasi Tugas (`scripts/submit_job.sh`)**
   Saat pengguna mengirim tugas baru, skrip ini mengecek apakah perintahnya ada di dalam `jobs_allowed/`. Kalau sesuai, tugas dibuat menjadi file tiket `.job` di folder antrean tunggu. Kalau tidak terdaftar, tugas langsung ditolak.
2. **Mencegah Worker Ganda (`scripts/worker.sh` — `flock`)**
   Agar tidak ada dua proses *worker* yang jalan bersamaan dan saling berebut tiket, skrip memakai `flock` pada *file descriptor* `200` (`$LOCK_FILE`). Jika ada *worker* kedua yang dijalankan saat *worker* pertama masih aktif, proses kedua otomatis ditolak dengan status keluar `99`.
3. **Eksekusi Berurutan (`scripts/worker.sh` — FIFO)**
   Tiket `.job` yang masuk diproses satu per satu sesuai urutan kedatangan (*First-In, First-Out*). Tiket yang sedang dikerjakan dipindahkan ke folder berjalan agar tidak diambil ulang.
4. **Pemantauan Proses & Status (`scripts/worker.sh` & `scripts/cek_status.sh`)**
   Setiap tugas dijalankan di *background* sambil mencatat *Process ID* (PID), waktu mulai, waktu selesai, dan kode status keluarnya (*exit status*) ke file log.
5. **Pembuatan Laporan & Cek Integritas (`scripts/monitor_report.sh`)**
   Setelah proses selesai, skrip ini merangkum aktivitas sistem ke `output/laporan.txt` dan menghitung nilai hash `SHA-256` untuk memastikan isi laporan tidak berubah atau rusak.

## 3. Keamanan & Isolasi
- **Pembatasan Hak Akses Linux:** Folder operasional diatur agar hanya bisa diakses oleh grup `labqueue` dengan izin `2770` (SetGID). Pengguna di luar grup akan ditolak saat mencoba mengakses atau menulis file (`Permission denied`), sedangkan file baru di dalam folder tersebut otomatis mengikuti grup `labqueue`.
- **Isolasi Kontainer Docker:** Pengecekan bukti pengujian dijalankan lewat kontainer `alpine:3.20` dengan memasang folder `evidence/` dalam mode baca saja (`readonly`) menggunakan parameter `--mount type=bind,source="$(pwd)/evidence",target=/data,readonly`. Dengan begitu, proses di dalam kontainer tidak bisa mengubah atau menghapus file bukti asli di komputer *host*.

## 4. Penanganan Masalah & Pemulihan
- **File Kunci Tertinggal (*Stale Lock*):** Jika `worker.sh` berhenti mendadak (misalnya dimatikan paksa dengan `kill -9`) sehingga `trap` tidak sempat menghapus `$LOCK_FILE`, cek dulu apakah masih ada proses *worker* yang aktif memakai `ps aux | grep worker.sh`. Jika sudah tidak ada, hapus file kunci secara manual sesuai lokasi yang tertera di `config/queue.conf`.
- **Nilai Hash Laporan Tidak Cocok:** Jika hasil pengecekan `sha256sum` berbeda dari catatan awal, jalankan ulang `bash scripts/monitor_report.sh` untuk membuat ulang file laporan beserta hash `SHA-256` terbarunya dari log asli.
