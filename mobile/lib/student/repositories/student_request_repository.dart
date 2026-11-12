import '../../core/api/api_client.dart';
import '../models/student_request.dart';

class StudentRequestsData {
  const StudentRequestsData({
    required this.sessions,
    required this.leaves,
    required this.majorTransfers,
    required this.majors,
    required this.currentMajorId,
    required this.currentMajorName,
  });

  final List<LeaveSessionOption> sessions;
  final List<StudentLeaveRequest> leaves;
  final List<Map<String, dynamic>> majorTransfers;
  final List<Map<String, dynamic>> majors;
  final String? currentMajorId;
  final String? currentMajorName;
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
      api.request('GET', '/major-transfer-options'),
      api.request('GET', '/major-transfer-requests?page=1'),
      api.request('GET', '/profile'),
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
    final transferPayload = Map<String, dynamic>.from(results[3] as Map);
    final profile = Map<String, dynamic>.from(results[4] as Map);
    final major = profile['major'] is Map
        ? Map<String, dynamic>.from(profile['major'] as Map)
        : null;
    return StudentRequestsData(
      sessions: sessions,
      leaves: leaves,
      majorTransfers: _rows(transferPayload['items']),
      majors: _rows(results[2]),
      currentMajorId: major?['id']?.toString(),
      currentMajorName: major?['name']?.toString(),
    );
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

  Future<void> createMajorTransfer({
    required String majorId,
    required String reason,
  }) async {
    await api.request('POST', '/major-transfer-requests', {
      'to_major_id': majorId,
      'reason': reason.trim(),
    });
  }
}
