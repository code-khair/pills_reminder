import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pills_reminder/app/routes/app_routes.dart';
import 'package:pills_reminder/domain/services/reminder_scheduler.dart';
import 'package:pills_reminder/domain/usecases/reminder_usecases.dart';

/// Controller global: tab aktif, penanda perubahan data, dan izin notifikasi.
class AppController extends GetxController with WidgetsBindingObserver {
  AppController(this._scheduler, this._syncReminders);

  final ReminderScheduler _scheduler;
  final SyncRemindersUseCase _syncReminders;

  final RxInt currentTab = 0.obs;

  /// Dinaikkan setiap data berubah; controller lain memantau nilai ini.
  final RxInt dataVersion = 0.obs;

  void changeTab(int index) => currentTab.value = index;

  void notifyDataChanged() => dataVersion.value++;

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addObserver(this);
    _scheduler.setTapHandler((medicineId) {
      Get.toNamed(Routes.detail, arguments: medicineId);
    });
    _bootstrapReminders();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// Saat aplikasi kembali dibuka (mis. setelah memberi izin di Pengaturan,
  /// atau ganti hari): jadwal notifikasi diselaraskan ulang dan daftar
  /// "Hari Ini" dimuat ulang.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resync();
      notifyDataChanged();
    }
  }

  Future<void> _bootstrapReminders() async {
    try {
      await _scheduler.requestPermission();
    } catch (_) {
      // Gagal meminta izin tidak boleh menghentikan aplikasi.
    }
    await _resync();
  }

  bool _syncing = false;

  Future<void> _resync() async {
    if (_syncing) return; // hindari sinkronisasi ganda yang berebut
    _syncing = true;
    try {
      await _syncReminders();
    } catch (_) {
      // Kegagalan penjadwalan tidak boleh menghentikan aplikasi.
    } finally {
      _syncing = false;
    }
  }

  Future<void> requestPermission() async {
    final granted = await _scheduler.requestPermission(force: true);
    await _resync();
    Get.snackbar(
      granted ? 'Izin diberikan' : 'Izin ditolak',
      granted
          ? 'Notifikasi pengingat dapat ditampilkan.'
          : 'Aktifkan izin notifikasi di pengaturan perangkat.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> sendTestNotification() async {
    try {
      await _scheduler.showTest();
      Get.snackbar(
        'Tes notifikasi',
        'Notifikasi akan muncul dalam 5 detik.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('Gagal', 'Notifikasi uji tidak dapat dijadwalkan.',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}
