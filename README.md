# Researcher Affiliation Tracker (LPDP to Google Scholar)

Proyek ini bertujuan untuk memantau mobilitas akademik peneliti, khususnya penerima pendanaan dari **LPDP (Lembaga Pengelola Dana Pendidikan)**. Dengan menggabungkan data publikasi historis dan profil publik saat ini, alat ini dapat mendeteksi perubahan afiliasi peneliti dari waktu ke waktu.

## 📋 Ikhtisar Sistem

Sistem ini terdiri dari dua komponen utama yang bekerja secara berurutan untuk melacak apakah seorang peneliti telah memperbarui afiliasi mereka, terutama memantau tren "kembali" ke instansi di Indonesia.

### 1. `lpdp.sh` (Data Extraction)

Skrip ini berfungsi sebagai titik awal untuk mendapatkan daftar peneliti yang didanai oleh LPDP.

* **Sumber Data**: Crossref REST API (berdasarkan Funder ID LPDP: `501100014538`).
* **Fungsi**: Mengambil data artikel terbaru, mengekstrak **First Author**, afiliasi saat artikel diterbitkan, dan ID ORCID.
* **Output**: File `first_author_affiliations.csv` yang berisi daftar nama untuk divalidasi.

### 2. `scholar.sh` (Validation & Current Status)

Skrip ini digunakan untuk memvalidasi data yang didapat dari langkah pertama dengan profil publik terbaru.

* **Sumber Data**: Google Scholar via SerpApi.
* **Fungsi**: Mencari profil peneliti berdasarkan nama yang ditemukan di `lpdp2.sh` untuk melihat afiliasi mereka yang terdaftar secara *real-time* di Google Scholar.
* **Tujuan**: Memastikan apakah afiliasi yang tercatat di jurnal (masa lalu) berbeda dengan afiliasi yang tercatat di profil Google Scholar (masa sekarang).

---

## 🛠 Prasyarat

Sebelum menjalankan skrip, pastikan sistem Anda memiliki:

* `bash`
* `curl` & `jq` (untuk pengolahan data JSON)
* `python3` (untuk URL encoding dan parsing tambahan)
* **SerpApi Key**: Diperlukan untuk menjalankan `scholar.sh` (Dapatkan di [serpapi.com](https://serpapi.com)).

---

## 🚀 Alur Kerja (Workflow)

1. **Ekstraksi Data Awal**:
Jalankan skrip LPDP untuk mendapatkan daftar penulis yang terafiliasi dengan pendanaan Indonesia di masa lalu.
```bash
chmod +x lpdp.sh
./lpdp2.sh

```


Hasilnya akan muncul di terminal dan tersimpan di `first_author_affiliations.csv`.
2. **Validasi Perubahan Afiliasi**:
Ambil nama penulis dari hasil langkah pertama, lalu jalankan skrip Scholar untuk mengecek status mereka saat ini.
```bash
chmod +x scholar.sh
./scholar.sh "Nama Peneliti" "YOUR_SERPAPI_KEY"

```


3. **Analisis Perbandingan**:
* **Data LPDP**: Menunjukkan afiliasi peneliti saat riset didanai (mungkin di luar negeri saat studi).
* **Data Scholar**: Menunjukkan di mana peneliti tersebut bekerja sekarang.



---

## 🎯 Target Masa Depan: Deteksi "Homecoming"

Tujuan akhir dari pengembangan alat ini adalah untuk melakukan otomasi pemantauan terhadap peneliti Indonesia di luar negeri.

Sistem akan dikembangkan untuk mendeteksi kata kunci institusi Indonesia (seperti "Universitas", "BRIN", "Institut") pada hasil `scholar.sh`. Jika ditemukan perbedaan di mana afiliasi awal adalah institusi luar negeri dan profil terbaru adalah institusi Indonesia, maka sistem akan mencatatnya sebagai **perubahan afiliasi positif (kembali ke tanah air)**.

---

## ⚠️ Catatan

* Pastikan penggunaan API Key SerpApi tetap dalam batas kuota gratis Anda.
* Skrip `lpdp.sh` saat ini mengambil 5 baris data terbaru secara default (dapat diubah pada variabel `ROWS`).
* Skrip dibuat dengan menggunakan Claude dan sudah ditesting

