class SectionOption {
  const SectionOption({
    required this.id,
    required this.code,
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.semesterId,
    required this.semesterCode,
    required this.remaining,
    this.registrationOpen = true,
    this.registrationOpenAt,
    this.registrationCloseAt,
    this.withdrawalDeadline,
  });

  final String id;
  final String code;
  final String courseId;
  final String courseName;
  final String courseCode;
  final String semesterId;
  final String semesterCode;
  final int? remaining;
  final bool registrationOpen;
  final DateTime? registrationOpenAt;
  final DateTime? registrationCloseAt;
  final DateTime? withdrawalDeadline;

  factory SectionOption.fromJson(Map<String, dynamic> json) => SectionOption(
    id: json['id'] as String,
    code: json['code']?.toString() ?? 'Lớp học',
    courseId: json['course_id'] as String,
    courseName: json['course']?.toString() ?? 'Môn học',
    courseCode: json['course_code']?.toString() ?? '',
    semesterId: json['semester_id'] as String,
    semesterCode: json['semester_code']?.toString() ?? 'Học kỳ',
    remaining: (json['remaining'] as num?)?.toInt(),
    registrationOpen: json['status'] == 'OPEN',
  );
}

class EnrollmentRecord {
  const EnrollmentRecord({
    required this.sectionId,
    required this.courseId,
    required this.semesterId,
    required this.status,
    required this.version,
  });

  final String sectionId;
  final String courseId;
  final String semesterId;
  final String status;
  final int version;

  bool get isActive => status == 'ACTIVE';

  factory EnrollmentRecord.fromJson(Map<String, dynamic> json) =>
      EnrollmentRecord(
        sectionId: json['section_id'] as String,
        courseId: json['course_id'] as String,
        semesterId: json['semester_id'] as String,
        status: json['status']?.toString() ?? '',
        version: (json['version'] as num?)?.toInt() ?? 0,
      );
}

class SectionSessionPreview {
  const SectionSessionPreview({
    required this.startAt,
    required this.endAt,
    required this.status,
    this.slotId,
    this.roomName,
    this.attendanceSaved = false,
    this.attendanceStatus,
    this.attendanceNote,
  });

  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final int? slotId;
  final String? roomName;
  final bool attendanceSaved;
  final String? attendanceStatus;
  final String? attendanceNote;

  factory SectionSessionPreview.fromJson(Map<String, dynamic> json) =>
      SectionSessionPreview(
        startAt: DateTime.parse(json['start_at'] as String).toUtc(),
        endAt: DateTime.parse(json['end_at'] as String).toUtc(),
        status: json['status']?.toString() ?? 'SCHEDULED',
        slotId: json['slot_id'] as int?,
        roomName: json['room_name']?.toString(),
        attendanceSaved: json['attendance_saved'] == true,
        attendanceStatus: json['my_attendance'] is Map
            ? json['my_attendance']['status']?.toString()
            : null,
        attendanceNote: json['my_attendance'] is Map
            ? json['my_attendance']['note']?.toString()
            : null,
      );
}

class EnrollmentData {
  const EnrollmentData({
    required this.available,
    required this.availableError,
    required this.enrollments,
    required this.mySections,
    required this.courseNames,
    required this.semesterNames,
  });

  final List<SectionOption> available;
  final String? availableError;
  final List<EnrollmentRecord> enrollments;
  final Map<String, SectionOption> mySections;
  final Map<String, String> courseNames;
  final Map<String, String> semesterNames;
}
