# Bagian Anggota 4 untuk Proyek 5B

## Tanggung jawab

Anggota 4 menerapkan batas waktu untuk satu pekerjaan yang sudah lolos validasi dan diambil oleh worker antrean. Pekerjaan yang selesai sebelum batas waktu diteruskan sebagai berhasil. Pekerjaan yang melampaui batas dihentikan dan hasilnya dicatat sebagai timeout. Pengajuan pekerjaan, FIFO, lock worker, dan monitoring antrean tetap menjadi tanggung jawab anggota lain.

## Antarmuka integrasi

Worker memanggil `scripts/timeout_runner.sh` setelah mengambil satu pekerjaan yang sudah tervalidasi:

```bash
if scripts/timeout_runner.sh 5 output/status/job-001.status output/log/job-001.log -- bash scripts/jobs/job-001.sh; then
  job_exit_status=0
else
  job_exit_status=$?
fi
```

Argumen setelah `--` adalah perintah beserta argumennya. Runner tidak menggunakan `eval`, sehingga parameter tidak dieksekusi sebagai potongan shell. Gunakan direktori status dan log yang khusus untuk ID pekerjaan agar dua pekerjaan tidak menulis berkas yang sama.

Arti hasil runner:

| Exit status runner | Isi status | Arti |
|---|---|---|
| `0` | `succeeded` | Pekerjaan selesai normal sebelum deadline. |
| `124` | `timed_out` | Deadline tercapai; GNU `timeout` mengirim `TERM`. Worker harus mencatat pekerjaan sebagai gagal karena timeout. |
| Status lain | `failed` | Pekerjaan gagal dengan exit status tersebut, atau runner tidak dapat memulainya. |
| `137` dengan durasi mencapai batas | `force_terminated_after_timeout` | Pekerjaan tidak berhenti setelah `TERM`; GNU `timeout` mengirim `KILL` setelah 3 detik. |

Runner mengembalikan exit status pekerjaan agar worker antrean dapat memperbarui statusnya. Gunakan `124` sebagai kode khusus timeout pada kontrak proyek, karena GNU `timeout` memakai kode itu untuk menandai pekerjaan yang melewati deadline. Bila terjadi `force_terminated_after_timeout`, worker tetap mencatat pekerjaan gagal dan menyertakan status rinci dari berkas `.status`.

## Skenario demonstrasi individu

### Positif

- Tujuan: membuktikan pekerjaan yang selesai lebih cepat dari deadline menghasilkan status berhasil.
- Prasyarat: Cloud Shell aktif, direktori proyek berada di `$HOME`, dan `timeout` tersedia (`command -v timeout`).
- Langkah: jalankan `bash tests/demo_timeout_anggota4.sh`.
- Hasil yang diharapkan: runner mengembalikan `0`, status berisi `state=succeeded`, dan log memiliki `PEKERJAAN_POSITIF_SELESAI`.

### Negatif

- Tujuan: membuktikan pekerjaan yang lebih lama dari deadline dihentikan dan tidak melanjutkan instruksi sesudahnya.
- Prasyarat: sama dengan skenario positif; skenario memakai `sleep` dummy, bukan proses atau data produksi.
- Langkah: jalankan `bash tests/demo_timeout_anggota4.sh`.
- Hasil yang diharapkan: runner mengembalikan `124`, status berisi `state=timed_out`, log tidak memiliki `PENANDA_TIDAK_BOLEH_MUNCUL`, dan durasi yang tercatat sekurang-kurangnya 2 detik.
- Pemulihan: tidak ada data proyek yang diubah. Bukti demo ditulis di subdirektori baru pada `evidence/anggota4-timeout/`.

Simpan keluaran terminal bersama berkas `.status` dan `.log` sebagai bukti. Catat exit status tepat setelah perintah runner, sebelum menjalankan perintah lain.

## Menjalankan di Google Cloud Shell

Cloud Shell menyediakan terminal Linux berbasis Debian dan VM-nya bersifat sementara; `$HOME` menjadi penyimpanan yang persisten. Letakkan clone repository, script, serta bukti yang akan disimpan di bawah `$HOME`, dan hindari mode ephemeral saat menyiapkan hasil. Sebelum demo, periksa `pwd`, `command -v bash`, `command -v timeout`, dan `timeout --version`. Tidak diperlukan Ubuntu lokal atau Docker untuk fitur timeout ini. Berkas status dan log dibuat dengan izin pemilik baca-tulis serta grup baca; sesuaikan grup direktori induk dengan rancangan akses anggota 5.

Contoh menyiapkan dan menjalankan bagian ini dari direktori proyek:

```bash
chmod +x scripts/timeout_runner.sh tests/demo_timeout_anggota4.sh
bash tests/demo_timeout_anggota4.sh
```

Google Cloud adalah platformnya; Cloud Shell menjalankan lingkungan Linux berbasis Debian. Tuliskan Cloud Shell serta versi lingkungan aktual di README kelompok, bukan Ubuntu Server. Untuk demo, buka repository dan jalankan seluruh proses dalam sesi yang sama; jangan mengandalkan proses latar tetap hidup setelah sesi ditutup.

## Hubungan dengan konsep sistem operasi

- **Proses dan siklus hidup:** worker membuat proses supervisor `timeout`, yang mengatur proses job. Berkas status mencatat PID job dan PID supervisor secara terpisah; PID job tetap sama ketika wrapper Bash menjalankan `exec` pada perintah.
- **Signal:** pada deadline, GNU `timeout` mengirim `SIGTERM`. Jika proses tidak berhenti dalam 3 detik, `SIGKILL` digunakan. `TERM` memberi kesempatan proses berhenti dengan rapi; `KILL` tidak dapat ditangani oleh proses.
- **Penjadwalan:** deadline membatasi lama satu pekerjaan aplikasi. Ini tidak mengubah algoritma scheduler CPU Linux dan tidak menjamin urutan antrean.
- **Sinkronisasi:** timeout tidak menggantikan FIFO atau lock. Worker tetap harus mencegah dua worker memproses ID pekerjaan yang sama.
- **Exit status dan log:** exit status `124`, status akhir, PID job dan supervisor, durasi, waktu UTC, serta log keluaran menjadi bukti bahwa timeout terjadi dan bukan laporan sukses palsu.
- **Batasan:** `timeout` membatasi proses perintah yang dikelolanya. Worker harus memanggilnya pada setiap job. Proses latar yang sengaja melepaskan diri atau membuat daemon tidak termasuk asumsi job dummy proyek ini.

## Tabel hasil yang diisi saat demo

| ID | Kondisi | Hasil yang diharapkan | Hasil aktual | Exit status | Bukti |
|---|---|---|---|---|---|
| A4-POS-01 | Job `sleep 1`, batas 5 detik | `succeeded`, instruksi akhir muncul | Isi saat demo | Isi saat demo | Path `.status` dan `.log` |
| A4-NEG-01 | Job `sleep 10`, batas 2 detik | `timed_out`, exit `124`, instruksi sesudah sleep tidak muncul | Isi saat demo | Isi saat demo | Path `.status` dan `.log` |

Jangan mengisi hasil aktual sebelum menjalankan demonstrasi. Sesuaikan nama perintah, format status, serta lokasi log dengan interface repository kelompok setelah berdiskusi dengan anggota 2 dan 3.

## Alur presentasi empat menit

1. **Kondisi awal (30 detik):** tunjukkan direktori `$HOME` repository, versi Linux yang tersedia di Cloud Shell, dan bahwa perintah `timeout` tersedia. Jelaskan bahwa demo memakai job `sleep` dummy.
2. **Kondisi positif (60 detik):** jalankan demo; tunjukkan bahwa job 1 detik selesai dengan `state=succeeded` dan exit status `0` di bawah batas 5 detik.
3. **Kondisi negatif (60 detik):** tunjukkan bahwa job 10 detik berhenti pada batas 2 detik, runner mengembalikan exit status `124`, status akhir `timed_out`, dan penanda setelah `sleep` tidak ada di log.
4. **Bukti dan konsep (60 detik):** buka dua berkas status dan log. Terangkan PID supervisor, durasi, waktu UTC, serta urutan `SIGTERM` kemudian `SIGKILL` jika proses mengabaikan penghentian.
5. **Batas dan integrasi (30 detik):** tunjukkan bagaimana worker meneruskan exit status ke status antrean. Tegaskan bahwa timeout membatasi job aplikasi, bukan mengubah scheduler kernel; FIFO dan lock tetap dikelola komponen lain.
