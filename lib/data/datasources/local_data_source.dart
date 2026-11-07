import 'package:hive/hive.dart';
import 'package:pills_reminder/core/constants/app_constants.dart';
import 'package:pills_reminder/data/models/intake_log_model.dart';
import 'package:pills_reminder/data/models/medicine_model.dart';
import 'package:pills_reminder/domain/entities/intake_log.dart';
import 'package:pills_reminder/domain/entities/medicine.dart';

/// Sumber data lokal untuk obat (Hive). Box dibuka di main.dart.
class MedicineLocalDataSource {
  Box get _box => Hive.box(AppConstants.medicinesBox);
  Box get _meta => Hive.box(AppConstants.metaBox);

  List<Medicine> getAll() {
    return _box.values
        .map((e) => MedicineModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// ID auto-increment, disimpan di meta box.
  Future<int> nextId() async {
    final current = _meta.get(AppConstants.nextIdKey, defaultValue: 1) as int;
    await _meta.put(AppConstants.nextIdKey, current + 1);
    await _meta.flush();
    return current;
  }

  /// Menyimpan lalu langsung memaksa tulis ke disk (flush) agar data tidak
  /// hilang bila aplikasi dimatikan paksa / dibersihkan dari recent apps.
  Future<void> put(Medicine medicine) async {
    await _box.put(medicine.id, MedicineModel.toMap(medicine));
    await _box.flush();
  }

  Future<void> delete(int id) async {
    await _box.delete(id);
    await _box.flush();
  }
}

/// Sumber data lokal untuk riwayat konsumsi (Hive).
class IntakeLogLocalDataSource {
  Box get _box => Hive.box(AppConstants.logsBox);

  List<IntakeLog> getAll() {
    return _box.values
        .map((e) =>
            IntakeLogModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> put(IntakeLog log) async {
    await _box.put(log.key, IntakeLogModel.toMap(log));
    await _box.flush();
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
    await _box.flush();
  }
}
