const _vietnamOffset = Duration(hours: 7);

DateTime vietnamCalendarDate(DateTime instant) {
  final local = instant.toUtc().add(_vietnamOffset);
  return DateTime.utc(local.year, local.month, local.day);
}

DateTime vietnamToday() => vietnamCalendarDate(DateTime.now());

DateTime mondayOf(DateTime date) =>
    date.subtract(Duration(days: date.weekday - DateTime.monday));

DateTime utcAtVietnamMidnight(DateTime date) => date.subtract(_vietnamOffset);

String formatVietnamTime(DateTime instant) {
  final local = instant.toUtc().add(_vietnamOffset);
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String formatDayMonth(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

String formatWeekRange(DateTime monday) {
  final sunday = monday.add(const Duration(days: 6));
  return '${formatDayMonth(monday)} – ${formatDayMonth(sunday)}/${sunday.year}';
}

const shortWeekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const fullWeekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];
