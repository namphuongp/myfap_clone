import '../../core/api/api_client.dart';
import '../models/lecturer_data.dart';
import '../models/teaching_class.dart';
import '../utils/lecturer_dates.dart';

class LecturerRepository {
  final ApiClient api;
  LecturerRepository(this.api);
  Future<List<AcademicTerm>> terms() async =>
      jsonList(await api.request('GET', '/semesters'))
          .map(AcademicTerm.new)
          .toList();
  Future<List<Json>> rooms() async =>
      jsonList(await api.request('GET', '/rooms'));
  Future<List<TeachingSession>> schedule(DateTime from, DateTime to) async {
    final query = Uri(
      queryParameters: {
        'from': vnMidnight(from).toIso8601String(),
        'to': vnMidnight(to).toIso8601String(),
      },
    ).query;
    return jsonList(await api.request('GET', '/schedule?$query'))
        .map(TeachingSession.new)
        .toList();
  }

  Future<List<TeachingSession>> attendanceSessions(AcademicTerm term) async {
    final rows = await schedule(vnDay(term.start), vnDay(term.end));
    return rows
        .where((s) => s.semesterId == term.id && s.status != 'CANCELLED')
        .toList();
  }

  Future<({AcademicTerm? term, List<TeachingClass> classes})>
  attendanceOverview() async {
    final term = (await terms()).where((t) => t.includes(vnDay())).firstOrNull;
    if (term == null) return (term: null, classes: <TeachingClass>[]);
    // Tải cả kỳ một lần rồi nhóm theo lớp, tránh gọi một API cho từng lớp.
    return (
      term: term,
      classes: TeachingClass.group(await attendanceSessions(term)),
    );
  }

  Future<Json> attendance(String id) async =>
      jsonObject(await api.request('GET', '/sessions/$id/attendance'));
  Future<void> saveAttendance(String id, int version, List<Json> rows) async {
    await api.request('PUT', '/sessions/$id/attendance', {
      'version': version,
      'rows': rows,
    });
  }

  Future<RequestPage> requests({
    required bool leave,
    String? status,
    int page = 1,
  }) async {
    final query = Uri(queryParameters: {'page': '$page', 'status': ?status})
        .query;
    return RequestPage(
      jsonObject(
        await api.request(
          'GET',
          '/${leave ? 'leave' : 'change'}-requests?$query',
        ),
      ),
    );
  }

  Future<void> reviewLeave(Json request, String decision, String note) async {
    await api.request('PATCH', '/leave-requests/${request['id']}/decision', {
      'version': request['version'],
      'decision': decision,
      'note': note,
    });
  }

  Future<void> createChange({
    required TeachingSession session,
    required String roomId,
    required DateTime day,
    required int slot,
    required String reason,
  }) async {
    await api.request('POST', '/change-requests', {
      'session_id': session.id,
      'proposed_room_id': roomId,
      'proposed_date': dateKey(day),
      'proposed_slot_id': slot,
      'reason': reason,
    });
  }
}
