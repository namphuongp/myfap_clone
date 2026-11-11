import '../../core/api/api_client.dart';
import '../models/student_request.dart';

class StudentRequestsData {
  const StudentRequestsData({required this.sessions, required this.leaves});

  final List<LeaveSessionOption> sessions;
  final List<StudentLeaveRequest> leaves;
}

class StudentRequestRepository {
  const StudentRequestRepository(this.api);

  final ApiClient api;

  List<Map<String, dynamic>> _rows(dynamic value) => (value as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  Future<StudentRequestsData> load() async {
    final now = DateTime.now().toUtc();
    final from = Uri.encodeQueryComponent(now.toIso8601String());
    final to = Uri.encodeQueryComponent(
      now.add(const Duration(days: 90)).toIso8601String(),
    );
    final results = await Future.wait([
      api.request('GET', '/schedule?from=$from&to=$to'),
      api.request('GET', '/leave-requests?page=1'),
    ]);
    final cutoff = DateTime.now().toUtc();
    final sessions =
        _rows(results[0])
            .map(LeaveSessionOption.fromJson)
            .where(
              (session) =>
                  session.status == 'SCHEDULED' &&
                  session.startAt.isAfter(cutoff),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final requestPayload = Map<String, dynamic>.from(results[1] as Map);
    final leaves = _rows(requestPayload['items'])
        .map(StudentLeaveRequest.fromJson)
        .toList();
    return StudentRequestsData(sessions: sessions, leaves: leaves);
  }

  Future<void> createLeave({
    required String sessionId,
    required String reason,
  }) async {
    await api.request('POST', '/leave-requests', {
      'session_id': sessionId,
      'reason': reason.trim(),
    });
  }
}
