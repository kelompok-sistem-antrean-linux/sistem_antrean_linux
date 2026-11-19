# Sistem Antrean Tugas Terisolasi (`proyek-so-5b`)

## 1. Deskripsi
Sistem antrean tugas (*job queue*) berbasis Bash dan Docker yang dirancang untuk mengelola, menjadwalkan, dan memantau eksekusi perintah secara berurutan (*First-In, First-Out*). Sistem ini dilengkapi validasi daftar perintah yang diizinkan, penguncian proses agar tidak terjadi tabrakan antar-*worker*, pembatasan hak akses berbasis grup Linux, pengecekan integritas laporan memakai SHA-256, serta isolasi volume Docker mode baca saja (*readonly*).

## 2. Anggota Kelompok
1. **Aghna Biwalaki Chodori** (2510512177) — Pengujian & Eksekusi Antrean
2. **Fathimah Asrining Nurcahya Pertiwi** (2510512199) — Penjadwalan Antrean FIFO (Anggota 2A)
3. **Jennar Iqlima Rakhman** (2510512176) — Penguncian Eksklusif `flock` (Anggota 2B)
4. **Made Dwi Putra** (2510512204) — Pemantauan Sistem, Keamanan Direktori, & Isolasi Docker (Anggota 5)
5. **Muhammad Haikal Irawan** (2510512185) — Pelacakan PID & Status Eksekusi (Anggota 3)
6. **Muhammad Rijal Akbar** (2510512173) — Validasi Input & Pengajuan Tiket

## 3. Lingkungan
- **Sistem Operasi:** Linux / WSL2 (Ubuntu)
- **Shell & Utilitas:** GNU Bash, `flock`, `sha256sum`, `ps`
- **Kontainer:** Docker Engine dengan image `alpine:3.20`

## 4. Instalasi
1. Unduh repository ke direktori lokal dan masuk ke folder proyek:
   ```bash
   git clone [https://github.com/kelompok-sistem-antrean-linux/sistem_antrean_linux.git](https://github.com/kelompok-sistem-antrean-linux/sistem_antrean_linux.git) ~/proyek-so-5b
   cd ~/proyek-so-5b
   ```
2. Berikan izin eksekusi pada seluruh skrip proyek dan skrip pengujian:
   ```bash
   chmod +x scripts/*.sh tests/*.sh
   ```
3. Siapkan grup `labqueue` dan atur izin direktori operasional menggunakan SetGID `2770`:
   ```bash
   sudo groupadd -f labqueue
   sudo usermod -aG labqueue $USER
   mkdir -p queue/waiting queue/running queue/done logs output
   sudo chown -R :labqueue queue logs output evidence
   sudo chmod -R 2770 queue logs output evidence
   ```
4. Sesuaikan jalur direktori kerja pada berkas konfigurasi `config/queue.conf` bila diperlukan.

## 5. Menjalankan
- **Mengajukan tugas ke antrean:**
  ```bash
  bash scripts/submit_job.sh <nama_tugas_di_jobs_allowed>
  ```
- **Menjalankan worker pemroses antrean:**
  ```bash
  bash scripts/worker.sh
  ```
- **Memeriksa status eksekusi tugas:**
  ```bash
  bash scripts/cek_status.sh
  ```
- **Membuat laporan operasional dan hash SHA-256:**
  ```bash
  bash scripts/monitor_report.sh
  ```

## 6. Menguji
- **Pengujian Positif:** Ajukan tugas menggunakan data simulasi `tests/dummy_valid.job`, jalankan `bash scripts/worker.sh` hingga selesai, lalu jalankan `bash scripts/monitor_report.sh` untuk memverifikasi laporan dan kecocokan hash SHA-256.
- **Pengujian Negatif:**
  1. Ajukan tugas memakai `tests/dummy_invalid.job` untuk memastikan sistem menolak perintah di luar `jobs_allowed/`.
  2. Jalankan dua perintah `bash scripts/worker.sh` secara bersamaan untuk memastikan `flock` menolak *worker* kedua dengan kode keluar `99`.
  3. Coba buat file di dalam `queue/` menggunakan akun di luar grup `labqueue` untuk memastikan muncul penolakan `Permission denied`.
- Rincian langkah dan hasil yang diharapkan tersedia di `tests/README.md`.

## 7. Docker
Untuk memeriksa berkas bukti pengujian secara aman tanpa risiko mengubah atau menghapus data asli di komputer *host*, jalankan kontainer `alpine:3.20` dengan memasang folder `evidence/` dalam mode `readonly`:

```bash
docker run --rm -it --mount type=bind,source="$(pwd)/evidence",target=/data,readonly alpine:3.20 sh
```

Di dalam shell kontainer (`/ #`), isi bukti dapat dibaca melalui direktori `/data`, sedangkan percobaan penulisan berkas baru akan otomatis ditolak dengan galat `Read-only file system`. Ketik `exit` untuk keluar dari kontainer.

## 8. Pemulihan
- **File Kunci Tertinggal (*Stale Lock*):** Jika `worker.sh` berhenti mendadak (misalnya dimatikan paksa dengan `kill -9`) sehingga berkas kunci tidak terhapus otomatis, pastikan tidak ada proses *worker* aktif melalui `ps aux | grep worker.sh`, lalu hapus berkas kunci secara manual sesuai jalur pada `config/queue.conf`.
- **Ketidaksesuaian Checksum Laporan:** Jika pengecekan `sha256sum` menunjukkan perbedaan nilai hash pada berkas laporan, jalankan ulang `bash scripts/monitor_report.sh` untuk membangun kembali laporan beserta nilai hash SHA-256 terbaru dari log asli.
