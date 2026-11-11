import '../../api/api_client.dart';

class UserProfile {
  final Map<String, dynamic> data;
  const UserProfile(this.data);
  String get name => data['name'] as String;
  String get role => data['role'] as String;
  String get email => data['email'] as String;
  String get userCode => data['user_code'] as String;
  int get version => data['version'] as int;
  String? get phone => data['phone'] as String?;
  String? get address => data['address'] as String?;
  String? get dateOfBirth => data['date_of_birth'] as String?;
  String get departmentName =>
      (data['department'] as Map?)?['name']?.toString() ?? 'Chưa cập nhật';
  String get majorName =>
      (data['major'] as Map?)?['name']?.toString() ?? 'Chưa cập nhật';
}

class ProfileRepository {
  final ApiClient api;
  ProfileRepository(this.api);
  Future<UserProfile> getProfile() async => UserProfile(
    Map<String, dynamic>.from(await api.request('GET', '/profile') as Map),
  );
  Future<void> clearSession() => api.clearLocalSession();
}
