# Dokumentasi Teknis Sistem Antrean Tugas

## 1. Susunan Folder Proyek
- `config/`: Menyimpan file pengaturan utama (`queue.conf`) yang mendefinisikan lokasi direktori antrean, log, dan file kunci.
- `jobs_allowed/`: Berisi daftar perintah atau skrip yang diizinkan untuk dijalankan oleh sistem (*whitelist*).
- `scripts/`: Kumpulan skrip utama yang mengatur jalannya antrean (`submit_job.sh`, `worker.sh`, `cek_status.sh`, dan `monitor_report.sh`).
- `tests/`: Berisi skenario pengujian positif dan negatif beserta data *dummy* untuk simulasi.
- `evidence/`: Arsip bukti pengujian dan log sistem yang sudah dibersihkan dari informasi sensitif.
- `docs/`: Dokumentasi teknis sistem dan berkas laporan akhir kelompok.

## 2. Alur Kerja Sistem
1. **Pengajuan & Validasi Tiket (`scripts/submit_job.sh`)**
   Ketika pengguna mengirim tugas baru, skrip akan memeriksa apakah perintah tersebut terdaftar di dalam `jobs_allowed/`. Jika sesuai, tiket `.job` dibuat di folder antrean tunggu. Jika tidak terdaftar, pengajuan langsung ditolak.
2. **Penguncian Proses Worker (`scripts/worker.sh` — `flock`)**
   Untuk mencegah dua proses *worker* berjalan bersamaan dan memproses tiket yang sama, skrip mengunci file lock menggunakan `flock` pada *file descriptor* `200`. Jika ada *worker* kedua yang dijalankan saat *worker* pertama masih aktif, proses kedua otomatis ditolak dengan kode keluar `99`.
3. **Eksekusi Antrean Berurutan (`scripts/worker.sh` — FIFO)**
   Tiket `.job` yang masuk diproses satu per satu sesuai urutan kedatangan (*First-In, First-Out*). Tiket yang sedang dikerjakan dipindahkan ke folder berjalan agar tidak diambil ulang oleh proses lain.
4. **Pemantauan PID & Status Eksekusi (`scripts/worker.sh` & `scripts/cek_status.sh`)**
   Setiap tugas dijalankan di *background* sambil mencatat *Process ID* (PID), waktu mulai, waktu selesai, serta kode status keluarnya (*exit status*) ke dalam log.
5. **Pembuatan Laporan & Cek Integritas (`scripts/monitor_report.sh`)**
   Setelah antrean selesai diproses, skrip ini merangkum aktivitas sistem ke `output/laporan.txt` dan membuat nilai hash `SHA-256` menggunakan `sha256sum` untuk memastikan isi laporan tetap utuh.

## 3. Keamanan & Isolasi Lingkungan
- **Pembatasan Hak Akses Linux:** Direktori operasional diatur kepemilikannya untuk grup `labqueue` dengan izin `2770` (SetGID). Pengguna di luar grup akan ditolak saat mencoba mengakses atau menulis file (`Permission denied`), sementara file baru yang dibuat di dalamnya otomatis mewarisi grup `labqueue`.
- **Isolasi Kontainer Docker:** Pemeriksaan bukti pengujian dilakukan melalui kontainer `alpine:3.20` dengan memasang direktori `evidence/` dalam mode baca saja (`readonly`) menggunakan parameter `--mount type=bind,source="$(pwd)/evidence",target=/data,readonly`. Dengan cara ini, proses di dalam kontainer tidak dapat mengubah atau menghapus file bukti asli di komputer *host*.

## 4. Penanganan Kendala & Pemulihan
- **File Kunci Tertinggal (*Stale Lock*):** Jika `worker.sh` berhenti mendadak (misalnya dihentikan paksa dengan `kill -9`) sehingga mekanisme `trap` tidak sempat menghapus file kunci, pastikan terlebih dahulu tidak ada proses *worker* yang masih berjalan melalui `ps aux | grep worker.sh`, lalu hapus file kunci secara manual sesuai jalur pada `config/queue.conf`.
- **Hash Laporan Tidak Cocok:** Jika pengecekan `sha256sum` menunjukkan perbedaan nilai hash pada laporan, jalankan ulang `bash scripts/monitor_report.sh` untuk membangun kembali file laporan beserta hash `SHA-256` terbarunya dari catatan log asli.
