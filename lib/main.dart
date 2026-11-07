import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pills_reminder/app/app.dart';
import 'package:pills_reminder/core/constants/app_constants.dart';
import 'package:pills_reminder/data/services/local_notification_scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox(AppConstants.medicinesBox),
    Hive.openBox(AppConstants.logsBox),
    Hive.openBox(AppConstants.metaBox),
  ]);

  final scheduler = LocalNotificationScheduler();
  try {
    await scheduler.init();
  } catch (e, st) {
    debugPrint('Gagal inisialisasi notifikasi: $e\n$st');
  }

  runApp(PillsReminderApp(scheduler: scheduler));
}
