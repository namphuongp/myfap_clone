import '../utils/schedule_date.dart';

class ScheduleSession {
  const ScheduleSession({
    required this.course,
    required this.sectionCode,
    required this.roomName,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.slotId,
  });

  final String course;
  final String sectionCode;
  final String roomName;
  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final int? slotId;

  DateTime get day => vietnamCalendarDate(startAt);

  factory ScheduleSession.fromJson(Map<String, dynamic> json) =>
      ScheduleSession(
        course: json['course']?.toString() ?? 'Môn học',
        sectionCode: json['section_code']?.toString() ?? 'Chưa có mã lớp',
        roomName: json['room_name']?.toString() ?? 'Chưa có phòng',
        startAt: DateTime.parse(json['start_at'] as String).toUtc(),
        endAt: DateTime.parse(json['end_at'] as String).toUtc(),
        status: json['status']?.toString() ?? 'SCHEDULED',
        slotId: json['slot_id'] as int?,
      );
}
