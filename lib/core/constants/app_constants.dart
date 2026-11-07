/// Konstanta global aplikasi.
class AppConstants {
  AppConstants._();

  static const String appName = 'Pills Reminder';

  // Nama box Hive
  static const String medicinesBox = 'medicines_box';
  static const String logsBox = 'intake_logs_box';
  static const String metaBox = 'meta_box';
  static const String nextIdKey = 'next_medicine_id';

  // Notifikasi
  // ID diubah ke v3 karena pengaturan suara sebuah channel tidak dapat
  // diubah setelah channel dibuat di HP. ID baru memaksa channel baru
  // (dengan nada pill_reminder) terbentuk.
  static const String channelId = 'pills_reminder_channel_v3';

  /// Nama file nada di android/app/src/main/res/raw (tanpa ekstensi).
  static const String notificationSound = 'pill_reminder';
  static const String channelName = 'Pengingat Obat';
  static const String channelDescription =
      'Notifikasi pengingat jadwal minum obat';

  /// Batas jam pengingat per obat.
  static const int maxTimesPerMedicine = 4;

  /// Jumlah slot ID notifikasi per obat
  /// (4 jam x 8 kemungkinan hari = 32). ID notifikasi = idObat * 32 + slot.
  static const int notificationSlotsPerMedicine = 32;

  static const List<String> doseUnits = [
    'tablet',
    'kapsul',
    'ml',
    'sendok takar',
    'tetes',
    'sachet',
  ];
}
