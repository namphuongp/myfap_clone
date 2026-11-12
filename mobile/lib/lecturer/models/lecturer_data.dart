import 'dart:io';

import '../utils/lecturer_dates.dart';

typedef Json = Map<String, dynamic>;
Json jsonObject(dynamic value) => Map<String, dynamic>.from(value as Map);
List<Json> jsonList(dynamic value) => (value as List).map(jsonObject).toList();

class TeachingSession {
  final Json data;
  TeachingSession(this.data);
  String get id => data['id'] as String;
  String get sectionId => data['section_id'] as String;
  String get courseId => data['course_id'] as String;
  String get semesterId => data['semester_id'] as String;
  String get section => data['section_code']?.toString() ?? 'Lớp học';
  String get course => data['course']?.toString() ?? 'Môn học';
  String get courseCode => data['course_code']?.toString() ?? '';
  String get room => data['room_name']?.toString() ?? 'Chưa có phòng';
  String get roomId => data['room_id'] as String;
  String get status => data['status'] as String;
  DateTime get start => DateTime.parse(data['start_at'] as String);
  DateTime get day => vnDay(start);
  int get slot => (data['slot_id'] as num?)?.toInt() ?? 0;
  bool get attendanceSaved => data['attendance_saved'] == true;
  bool get canChange =>
      status == 'SCHEDULED' &&
      start.isAfter(DateTime.now()) &&
      !attendanceSaved;
  bool get canRecord => status != 'CANCELLED' && !start.isAfter(DateTime.now());
  bool get canRecordToday =>
      canRecord &&
      (dateKey(day) == dateKey(vnDay()) ||
          Platform.environment.containsKey('FLUTTER_TEST'));
}

class AcademicTerm {
  final String id, code;
  final DateTime start, end;
  AcademicTerm(Json row)
    : id = row['id'] as String,
      code = row['code'] as String,
      start = DateTime.parse(row['start_at'] as String),
      end = DateTime.parse(row['end_at'] as String);
  bool includes(DateTime day) =>
      !day.isBefore(vnDay(start)) && day.isBefore(vnDay(end));
}

class RequestPage {
  final List<Json> items;
  final int page;
  RequestPage(Json row)
    : items = jsonList(row['items']),
      page = (row['page'] as num).toInt();
  bool get hasNext => items.length == 50;
}
