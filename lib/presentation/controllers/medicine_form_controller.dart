import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pills_reminder/core/constants/app_constants.dart';
import 'package:pills_reminder/core/utils/date_time_utils.dart';
import 'package:pills_reminder/domain/validators/medicine_validator.dart';
import 'package:pills_reminder/domain/entities/medicine.dart';
import 'package:pills_reminder/domain/usecases/medicine_usecases.dart';
import 'package:pills_reminder/presentation/controllers/app_controller.dart';

/// Mengelola state dan validasi formulir tambah / ubah obat.
class MedicineFormController extends GetxController {
  MedicineFormController(
      this._addMedicine, this._updateMedicine, this._app, this.initial);

  final AddMedicineUseCase _addMedicine;
  final UpdateMedicineUseCase _updateMedicine;
  final AppController _app;

  /// Obat yang sedang diubah; null berarti mode tambah.
  final Medicine? initial;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  late final TextEditingController nameC;
  late final TextEditingController doseC;
  late final TextEditingController notesC;

  final Rx<Frequency> frequency = Frequency.daily.obs;
  final RxString unit = AppConstants.doseUnits.first.obs;
  final RxList<int> weekdays = <int>[].obs;
  final RxList<String> times = <String>[].obs;
  final Rx<DateTime> startDate =
      DateTimeUtils.dateOnly(DateTime.now()).obs;
  final Rxn<DateTime> endDate = Rxn<DateTime>();

  final RxnString timesError = RxnString();
  final RxnString weekdaysError = RxnString();
  final RxnString dateError = RxnString();
  final RxBool isSaving = false.obs;

  bool get isEdit => initial != null;

  @override
  void onInit() {
    super.onInit();
    final m = initial;
    nameC = TextEditingController(text: m?.name ?? '');
    doseC = TextEditingController(
        text: m == null ? '' : m.doseLabel.split(' ').first);
    notesC = TextEditingController(text: m?.notes ?? '');
    if (m != null) {
      frequency.value = m.frequency;
      unit.value = m.doseUnit;
      weekdays.assignAll(m.weekdays);
      times.assignAll(m.times);
      startDate.value = DateTimeUtils.dateOnly(m.startDate);
      endDate.value = m.endDate;
    }
  }

  @override
  void onClose() {
    nameC.dispose();
    doseC.dispose();
    notesC.dispose();
    super.onClose();
  }

  void setFrequency(Frequency f) {
    frequency.value = f;
    weekdaysError.value = null;
    dateError.value = null;
    if (f == Frequency.once) endDate.value = null;
  }

  void toggleWeekday(int day) {
    if (weekdays.contains(day)) {
      weekdays.remove(day);
    } else {
      weekdays.add(day);
    }
    weekdaysError.value = null;
  }

  Future<void> pickTime(BuildContext context) async {
    if (times.length >= AppConstants.maxTimesPerMedicine) {
      Get.snackbar('Batas tercapai',
          'Maksimal ${AppConstants.maxTimesPerMedicine} jam pengingat per obat.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Pilih jam pengingat',
    );
    if (picked == null) return;
    final value = DateTimeUtils.formatHm(picked.hour, picked.minute);
    if (times.contains(value)) {
      Get.snackbar('Jam sudah ada', 'Jam $value sudah ditambahkan.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    times
      ..add(value)
      ..sort();
    timesError.value = null;
  }

  void removeTime(String value) => times.remove(value);

  Future<void> pickStartDate(BuildContext context) async {
    final today = DateTimeUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate.value,
      firstDate: isEdit && startDate.value.isBefore(today)
          ? startDate.value
          : today,
      lastDate: DateTime(today.year + 5),
      helpText: 'Tanggal mulai',
    );
    if (picked != null) {
      startDate.value = DateTimeUtils.dateOnly(picked);
      dateError.value = null;
    }
  }

  Future<void> pickEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate.value ?? startDate.value,
      firstDate: startDate.value,
      lastDate: DateTime(startDate.value.year + 5),
      helpText: 'Tanggal selesai',
    );
    if (picked != null) {
      endDate.value = DateTimeUtils.dateOnly(picked);
      dateError.value = null;
    }
  }

  void clearEndDate() {
    endDate.value = null;
    dateError.value = null;
  }

  /// Menjalankan seluruh validasi; true jika semua masukan valid.
  bool validate() {
    final formOk = formKey.currentState?.validate() ?? false;

    timesError.value = MedicineValidator.times(times);
    weekdaysError.value =
        MedicineValidator.weekdays(frequency.value, weekdays);
    dateError.value =
        MedicineValidator.dateRange(
            frequency.value, startDate.value, endDate.value) ??
        MedicineValidator.onceNotInPast(
            frequency.value, startDate.value, times, DateTime.now());

    return formOk &&
        timesError.value == null &&
        weekdaysError.value == null &&
        dateError.value == null;
  }

  Future<void> save() async {
    if (isSaving.value || !validate()) return;
    isSaving.value = true;
    try {
      final notes = notesC.text.trim();
      final sortedDays = [...weekdays]..sort();
      final medicine = Medicine(
        id: initial?.id ?? 0,
        name: nameC.text.trim(),
        doseAmount: double.parse(doseC.text.trim().replaceAll(',', '.')),
        doseUnit: unit.value,
        frequency: frequency.value,
        weekdays: frequency.value == Frequency.weekly ? sortedDays : const [],
        times: [...times]..sort(),
        startDate: startDate.value,
        endDate: frequency.value == Frequency.once ? null : endDate.value,
        notes: notes.isEmpty ? null : notes,
        createdAt: initial?.createdAt ?? DateTime.now(),
      );

      var reminderFailed = false;
      if (isEdit) {
        await _updateMedicine(medicine);
        reminderFailed = _updateMedicine.lastReminderFailed;
      } else {
        await _addMedicine(medicine);
        reminderFailed = _addMedicine.lastReminderFailed;
      }
      _app.notifyDataChanged();
      Get.back();
      if (reminderFailed) {
        Get.snackbar(
          'Data tersimpan',
          'Namun pengingat belum bisa dijadwalkan. Periksa izin notifikasi '
              'dan alarm di pengaturan HP.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
        );
      } else {
        Get.snackbar(
          'Berhasil',
          isEdit ? 'Data obat diperbarui.' : 'Obat berhasil ditambahkan.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar('Gagal menyimpan', 'Terjadi kesalahan. Silakan coba lagi.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSaving.value = false;
    }
  }
}
