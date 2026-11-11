import '../utils/schedule_date.dart';

class LeaveSessionOption {
  const LeaveSessionOption({
    required this.id,
    required this.course,
    required this.courseCode,
    required this.sectionCode,
    required this.roomName,
    required this.slotId,
    required this.startAt,
    required this.endAt,
    required this.status,
  });

  final String id;
  final String course;
  final String courseCode;
  final String sectionCode;
  final String roomName;
  final int? slotId;
  final DateTime startAt;
  final DateTime endAt;
  final String status;

  DateTime get vietnamDate => vietnamCalendarDate(startAt);

  factory LeaveSessionOption.fromJson(Map<String, dynamic> json) =>
      LeaveSessionOption(
        id: json['id'] as String,
        course: json['course']?.toString() ?? 'Môn học',
        courseCode: json['course_code']?.toString() ?? '',
        sectionCode: json['section_code']?.toString() ?? 'Chưa có mã lớp',
        roomName: json['room_name']?.toString() ?? 'Chưa có phòng',
        slotId: (json['slot_id'] as num?)?.toInt(),
        startAt: DateTime.parse(json['start_at'] as String).toUtc(),
        endAt: DateTime.parse(json['end_at'] as String).toUtc(),
        status: json['status']?.toString() ?? 'SCHEDULED',
      );

  String get choiceLabel {
    final date = vietnamDate;
    final weekday = fullWeekdays[date.weekday - 1];
    final courseLabel = courseCode.isEmpty ? course : '$courseCode · $course';
    final slotLabel = slotId == null ? '' : ' · Ca $slotId';
    return '$courseLabel · $sectionCode · $weekday ${date.day}/${date.month} · ${formatVietnamTime(startAt)}$slotLabel · $roomName';
  }
}

class StudentLeaveRequest {
  const StudentLeaveRequest({
    required this.id,
    required this.status,
    required this.reason,
    required this.createdAt,
    required this.reviewNote,
    required this.sessionId,
    required this.requestedStart,
    required this.requestedEnd,
    required this.lesson,
  });

  final String id;
  final String status;
  final String reason;
  final DateTime? createdAt;
  final String? reviewNote;
  final String sessionId;
  final DateTime? requestedStart;
  final DateTime? requestedEnd;
  final Map<String, dynamic>? lesson;

  factory StudentLeaveRequest.fromJson(Map<String, dynamic> json) =>
      StudentLeaveRequest(
        id: json['id'] as String,
        status: json['status']?.toString() ?? 'PENDING',
        reason: json['reason']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')
            ?.toUtc(),
        reviewNote: json['review_note']?.toString(),
        sessionId: json['session_id']?.toString() ?? '',
        requestedStart: DateTime.tryParse(
          json['requested_start']?.toString() ?? '',
        )?.toUtc(),
        requestedEnd: DateTime.tryParse(json['requested_end']?.toString() ?? '')
            ?.toUtc(),
        lesson: json['lesson'] is Map
            ? Map<String, dynamic>.from(json['lesson'] as Map)
            : null,
      );
}
