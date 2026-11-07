# Pills Reminder

Aplikasi pengingat obat berbasis Flutter. Pengguna dapat mencatat obat, menerima notifikasi pengingat (sekali, harian, mingguan), menandai dosis yang sudah diminum, dan melihat riwayat serta kepatuhan 7 hari. Data disimpan lokal dengan Hive, sehingga berjalan tanpa internet.

Proyek Mobile Programming, Kelompok 3, Teknik Informatika UIN Maulana Malik Ibrahim Malang (2026).
Anggota: Izza Zulfa Atikah (240605110019) dan Nor Khairina (240605110030).

## Fitur

- Tambah, ubah, hapus obat dengan validasi masukan
- Pengingat sekali, harian, atau mingguan (maksimal 4 jam per obat)
- Notifikasi tetap berjalan saat aplikasi ditutup
- Jadwal hari ini, tombol Minum/Batalkan, riwayat, dan kepatuhan 7 hari

## Teknologi

Flutter (Dart >= 3.3), GetX (`get`), Hive (`hive`, `hive_flutter`), `flutter_local_notifications` 17.2.4, `timezone`, `flutter_timezone` 3.0.1. Arsitektur: Clean Architecture (domain / data / presentation).

## Struktur Proyek

```
lib/
  main.dart            Titik masuk: init Hive dan notifikasi
  app/                 Aplikasi, rute, dan dependency injection
  core/                Konstanta, tema, utilitas tanggal
  domain/              Lapisan bisnis
    entities/            Medicine, IntakeLog, ScheduledDose, AdherenceSummary
    repositories/        Kontrak repositori
    services/            DoseScheduler, ReminderScheduler
    usecases/            Aksi bisnis (tambah, ubah, hapus, tandai diminum, dst.)
    validators/          Aturan validasi masukan
  data/                Lapisan data
    models/              Serialisasi entitas
    datasources/         Akses Hive
    repositories/        Implementasi repositori
    services/            LocalNotificationScheduler
  presentation/        Lapisan UI
    controllers/         Controller GetX
    pages/               7 halaman
    widgets/             Komponen UI bersama
test/                  Unit test (18 kasus uji)
docs/                  Dokumentasi tambahan
```

## Cara Menjalankan

```bash
git clone https://github.com/code-khair/pills_reminder.git
cd pills_reminder
flutter pub get
flutter run
```

Izinkan notifikasi saat diminta. Agar notifikasi berfungsi di Android, konfigurasi manifest dan *core library desugaring* harus sudah diatur (lihat `docs/ANDROID_SETUP.md`).

## Pengujian

```bash
flutter test
```

Terdapat 18 kasus uji untuk `DoseScheduler`, `Medicine`, dan `MedicineValidator`.

## Batasan

- Notifikasi berulang baru diselaraskan ulang saat aplikasi dibuka.
- Android 12+ memerlukan izin alarm presisi; jika ditolak, notifikasi bisa terlambat beberapa menit.
- Beberapa pabrikan (Xiaomi, Oppo, Vivo) membatasi aplikasi di latar belakang; matikan optimasi baterai untuk aplikasi ini.
