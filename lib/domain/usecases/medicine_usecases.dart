import 'package:pills_reminder/domain/entities/medicine.dart';
import 'package:pills_reminder/domain/repositories/medicine_repository.dart';
import 'package:pills_reminder/domain/services/reminder_scheduler.dart';

/// Mengambil seluruh obat, terbaru di atas.
class GetMedicinesUseCase {
  GetMedicinesUseCase(this._repository);
  final MedicineRepository _repository;

  Future<List<Medicine>> call() async {
    final list = await _repository.getAll();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}

/// Menyimpan obat baru lalu menjadwalkan notifikasinya.
///
/// Data disimpan lebih dulu. Jika penjadwalan notifikasi gagal, data tetap
/// tersimpan dan [lastReminderFailed] bernilai true (UI bisa memberi tahu).
class AddMedicineUseCase {
  AddMedicineUseCase(this._repository, this._scheduler);
  final MedicineRepository _repository;
  final ReminderScheduler _scheduler;

  bool lastReminderFailed = false;

  Future<Medicine> call(Medicine medicine) async {
    final saved = await _repository.add(medicine);
    lastReminderFailed = !await _safeSchedule(_scheduler, saved);
    return saved;
  }
}

/// Memperbarui obat lalu menjadwalkan ulang notifikasinya.
class UpdateMedicineUseCase {
  UpdateMedicineUseCase(this._repository, this._scheduler);
  final MedicineRepository _repository;
  final ReminderScheduler _scheduler;

  bool lastReminderFailed = false;

  Future<void> call(Medicine medicine) async {
    await _repository.update(medicine);
    lastReminderFailed = !await _safeSchedule(_scheduler, medicine);
  }
}

/// Menghapus obat beserta seluruh jadwal notifikasinya.
class DeleteMedicineUseCase {
  DeleteMedicineUseCase(this._repository, this._scheduler);
  final MedicineRepository _repository;
  final ReminderScheduler _scheduler;

  Future<void> call(int id) async {
    try {
      await _scheduler.cancel(id);
    } catch (_) {
      // Gagal membatalkan notifikasi tidak boleh menghalangi penghapusan data.
    }
    await _repository.delete(id);
  }
}

/// Menjadwalkan notifikasi tanpa pernah melempar error ke pemanggil.
/// Mengembalikan true jika berhasil.
Future<bool> _safeSchedule(ReminderScheduler scheduler, Medicine m) async {
  try {
    await scheduler.schedule(m);
    return true;
  } catch (_) {
    return false;
  }
}
