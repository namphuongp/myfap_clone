// Dùng ngày lịch UTC làm giá trị trung gian, tránh phụ thuộc múi giờ thiết bị.
DateTime vnDay([DateTime? instant]) {
  final value = (instant ?? DateTime.now()).toUtc().add(
    const Duration(hours: 7),
  );
  return DateTime.utc(value.year, value.month, value.day);
}

DateTime monday(DateTime day) => day.subtract(Duration(days: day.weekday - 1));
String dateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String dateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
DateTime vnMidnight(DateTime calendar) =>
    calendar.subtract(const Duration(hours: 7));
const weekdayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const slotLabels = {
  1: '07:30 – 09:50',
  2: '10:00 – 12:20',
  3: '12:50 – 15:10',
  4: '15:20 – 17:40',
};
