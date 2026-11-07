import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pills_reminder/core/constants/app_constants.dart';
import 'package:pills_reminder/core/utils/date_time_utils.dart';
import 'package:pills_reminder/domain/entities/medicine.dart';
import 'package:pills_reminder/domain/services/reminder_scheduler.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Implementasi [ReminderScheduler] memakai flutter_local_notifications.
///
/// Strategi penjadwalan:
/// - Sekali   : satu notifikasi pada tanggal mulai + jam.
/// - Harian   : satu notifikasi berulang tiap hari per jam (DateTimeComponents.time).
/// - Mingguan : satu notifikasi berulang tiap minggu per hari & jam
///              (DateTimeComponents.dayOfWeekAndTime).
///
/// ID notifikasi = idObat * 32 + slot, slot = indeksJam * 8 + hari (0 = tidak
/// bergantung hari). Dengan begitu semua notifikasi sebuah obat dapat
/// dibatalkan tanpa menyimpan daftar ID.
class LocalNotificationScheduler implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  void Function(int medicineId)? _onTap;

  static const int _testNotificationId = 2000000000;

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      AppConstants.channelId,
      AppConstants.channelName,
      channelDescription: AppConstants.channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      enableVibration: true,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  @override
  void setTapHandler(void Function(int medicineId) handler) {
    _onTap = handler;
  }

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    await _configureLocalTimezone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final id = int.tryParse(response.payload ?? '');
        if (id != null) _onTap?.call(id);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          AppConstants.channelId,
          AppConstants.channelName,
          description: AppConstants.channelDescription,
          importance: Importance.max,
        ));
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Cadangan: cocokkan selisih UTC perangkat dengan zona waktu Indonesia.
      final offset = DateTime.now().timeZoneOffset;
      const candidates = ['Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura'];
      var chosen = 'Asia/Jakarta';
      for (final name in candidates) {
        final loc = tz.getLocation(name);
        if (tz.TZDateTime.now(loc).timeZoneOffset == offset) {
          chosen = name;
          break;
        }
      }
      tz.setLocalLocation(tz.getLocation(chosen));
    }
  }

  static const String _exactPromptedKey = 'exact_alarm_prompted';

  @override
  Future<bool> requestPermission({bool force = false}) async {
    var granted = true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? false;

      // Alarm presisi (Android 12+). Halaman pengaturannya hanya dibuka
      // sekali agar tidak muncul setiap aplikasi dibuka.
      final canExact = await android.canScheduleExactNotifications() ?? false;
      if (!canExact && (force || !_alreadyPromptedExact())) {
        await _markPromptedExact();
        await android.requestExactAlarmsPermission();
      }
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ??
              false;
    }
    return granted;
  }

  bool _alreadyPromptedExact() {
    try {
      return Hive.box(AppConstants.metaBox)
              .get(_exactPromptedKey, defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markPromptedExact() async {
    try {
      final box = Hive.box(AppConstants.metaBox);
      await box.put(_exactPromptedKey, true);
      await box.flush();
    } catch (_) {}
  }

  int _notificationId(Medicine m, int timeIndex, int weekday) =>
      m.id * AppConstants.notificationSlotsPerMedicine +
      timeIndex * 8 +
      weekday;

  @override
  Future<void> schedule(Medicine m) async {
    await cancel(m.id);

    final now = tz.TZDateTime.now(tz.local);
    if (m.statusOn(now) == MedicineStatus.finished) return;

    for (var i = 0; i < m.times.length; i++) {
      final hour = DateTimeUtils.hourOf(m.times[i]);
      final minute = DateTimeUtils.minuteOf(m.times[i]);

      switch (m.frequency) {
        case Frequency.once:
          final when = tz.TZDateTime(tz.local, m.startDate.year,
              m.startDate.month, m.startDate.day, hour, minute);
          if (when.isAfter(now)) {
            await _zoned(_notificationId(m, i, 0), m, when, null);
          }
          break;
        case Frequency.daily:
          final when = _nextInstance(now, m.startDate, hour, minute);
          await _zoned(
              _notificationId(m, i, 0), m, when, DateTimeComponents.time);
          break;
        case Frequency.weekly:
          for (final wd in m.weekdays) {
            final when =
                _nextInstance(now, m.startDate, hour, minute, weekday: wd);
            await _zoned(_notificationId(m, i, wd), m, when,
                DateTimeComponents.dayOfWeekAndTime);
          }
          break;
      }
    }
  }

  /// Waktu terdekat (setelah [now] dan tidak sebelum [startDate]) untuk
  /// jam:menit tertentu, opsional pada hari [weekday] tertentu.
  tz.TZDateTime _nextInstance(
    tz.TZDateTime now,
    DateTime startDate,
    int hour,
    int minute, {
    int? weekday,
  }) {
    var day = DateTimeUtils.dateOnly(now);
    final start = DateTimeUtils.dateOnly(startDate);
    if (start.isAfter(day)) day = start;

    tz.TZDateTime build(DateTime d) =>
        tz.TZDateTime(tz.local, d.year, d.month, d.day, hour, minute);

    var candidate = build(day);
    while (!candidate.isAfter(now) ||
        (weekday != null && candidate.weekday != weekday)) {
      day = DateTime(day.year, day.month, day.day + 1);
      candidate = build(day);
    }
    return candidate;
  }

  Future<void> _zoned(
    int id,
    Medicine m,
    tz.TZDateTime when,
    DateTimeComponents? match,
  ) async {
    Future<void> run(AndroidScheduleMode mode) {
      return _plugin.zonedSchedule(
        id,
        'Waktunya minum obat',
        '${m.name} - ${m.doseLabel}',
        when,
        _details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: match,
        payload: '${m.id}',
      );
    }

    try {
      await run(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException {
      // Izin alarm presisi belum diberikan -> pakai alarm tidak presisi.
      await run(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  @override
  Future<void> cancel(int medicineId) async {
    for (var slot = 0;
        slot < AppConstants.notificationSlotsPerMedicine;
        slot++) {
      await _plugin
          .cancel(medicineId * AppConstants.notificationSlotsPerMedicine + slot);
    }
  }

  @override
  Future<void> syncAll(List<Medicine> medicines) async {
    for (final m in medicines) {
      try {
        await schedule(m);
      } catch (_) {
        // Satu obat gagal dijadwalkan tidak boleh menghentikan yang lain.
      }
    }
  }

  @override
  Future<void> showTest() async {
    final when =
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    try {
      await _plugin.zonedSchedule(
        _testNotificationId,
        'Tes notifikasi',
        'Pengingat obat berfungsi dengan baik.',
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException {
      await _plugin.zonedSchedule(
        _testNotificationId,
        'Tes notifikasi',
        'Pengingat obat berfungsi dengan baik.',
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
