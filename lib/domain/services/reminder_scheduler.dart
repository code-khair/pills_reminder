import 'package:pills_reminder/domain/entities/medicine.dart';

/// Kontrak layanan penjadwalan notifikasi pengingat.
abstract class ReminderScheduler {
  Future<void> init();

  /// Meminta izin notifikasi. Mengembalikan true jika diizinkan.
  ///
  /// Halaman pengaturan "alarm presisi" hanya dibuka sekali (saat pertama
  /// kali), kecuali [force] true (misalnya dari menu "Minta izin").
  Future<bool> requestPermission({bool force = false});

  /// Menjadwalkan (ulang) seluruh pengingat milik [medicine].
  Future<void> schedule(Medicine medicine);

  /// Membatalkan seluruh pengingat milik [medicineId].
  Future<void> cancel(int medicineId);

  /// Menyelaraskan jadwal notifikasi dengan daftar obat terkini.
  Future<void> syncAll(List<Medicine> medicines);

  /// Menampilkan notifikasi uji beberapa detik dari sekarang.
  Future<void> showTest();

  /// Dipanggil saat pengguna mengetuk notifikasi.
  void setTapHandler(void Function(int medicineId) handler);
}
