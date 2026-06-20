import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

// --- Gate providers ---

final isStaffAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  final email = user?.email;
  if (email == null) return false;
  return email.endsWith('@routineready.app') || email.endsWith('@routineready.co.uk');
});

final staffAdminModeProvider = StateProvider<bool>((ref) => false);

/// When a staff admin chooses to use the normal member experience (their own
/// org membership) instead of the Staff Admin gate. Session-only; resets on
/// reload so a staff admin always returns to the gate first.
final staffViewAsMemberProvider = StateProvider<bool>((ref) => false);

// --- Safe response parsing helpers ---

List<Map<String, dynamic>> _parseList(dynamic data, String fallbackError) {
  if (data is List) {
    return data.map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}).toList();
  }
  final error = data is Map ? data['error'] : null;
  throw Exception(error ?? fallbackError);
}

Map<String, dynamic> _parseMap(dynamic data, String fallbackError) {
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    if (map.containsKey('error')) throw Exception(map['error']);
    return map;
  }
  throw Exception(fallbackError);
}

// --- Data providers ---

final staffAdminOrgsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final client = ref.read(supabaseClientProvider);
    final res = await client.functions.invoke('staff-admin', body: {
      'action': 'list_organizations',
    });
    if (res.status != 200) {
      throw Exception(res.data is Map ? res.data['error'] : 'Failed to load organizations');
    }
    return _parseList(res.data, 'Failed to load organizations');
  } catch (e) {
    throw Exception(_cleanError(e));
  }
});

final staffAdminOrgDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, orgId) async {
  try {
    final client = ref.read(supabaseClientProvider);
    final res = await client.functions.invoke('staff-admin', body: {
      'action': 'get_organization',
      'org_id': orgId,
    });
    if (res.status != 200) {
      throw Exception(res.data is Map ? res.data['error'] : 'Failed to load organization');
    }
    return _parseMap(res.data, 'Failed to load organization');
  } catch (e) {
    throw Exception(_cleanError(e));
  }
});

final staffAdminUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final client = ref.read(supabaseClientProvider);
    final res = await client.functions.invoke('staff-admin', body: {
      'action': 'list_users',
    });
    if (res.status != 200) {
      throw Exception(res.data is Map ? res.data['error'] : 'Failed to load users');
    }
    return _parseList(res.data, 'Failed to load users');
  } catch (e) {
    throw Exception(_cleanError(e));
  }
});

// --- Error cleaning ---

String _cleanError(Object e) {
  final msg = e.toString();
  // Strip nested "Exception: " prefixes for cleaner UI display
  final cleaned = msg.replaceAll(RegExp(r'^(Exception:\s*)+'), '');
  if (cleaned.contains('Failed host lookup') || cleaned.contains('SocketException')) {
    return 'Network error. Please check your connection and try again.';
  }
  if (cleaned.contains('FunctionException') || cleaned.contains('<!DOCTYPE')) {
    return 'Something went wrong. Please try again.';
  }
  return cleaned.isEmpty ? 'Something went wrong. Please try again.' : cleaned;
}

// --- Actions ---

class StaffAdminActions {
  final Ref _ref;
  StaffAdminActions(this._ref);

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    try {
      final client = _ref.read(supabaseClientProvider);
      final res = await client.functions.invoke('staff-admin', body: body);
      if (res.status != 200) {
        final error = res.data is Map ? res.data['error'] : 'Request failed';
        throw Exception(error ?? 'Request failed');
      }
      return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : {'result': res.data};
    } catch (e) {
      throw Exception(_cleanError(e));
    }
  }

  // Organizations
  Future<void> createOrganization(String name) async {
    await _invoke({'action': 'create_organization', 'name': name});
    _ref.invalidate(staffAdminOrgsProvider);
  }

  Future<void> updateOrganization(String orgId, String name) async {
    await _invoke({'action': 'update_organization', 'org_id': orgId, 'name': name});
    _ref.invalidate(staffAdminOrgsProvider);
    _ref.invalidate(staffAdminOrgDetailProvider(orgId));
  }

  Future<void> deleteOrganization(String orgId) async {
    await _invoke({'action': 'delete_organization', 'org_id': orgId});
    _ref.invalidate(staffAdminOrgsProvider);
  }

  // Schools
  Future<void> createSchool({
    required String orgId,
    String? ownerId,
    String? schoolName,
    String? className,
    String? teacherName,
    String? deviceName,
  }) async {
    await _invoke({
      'action': 'create_school',
      'org_id': orgId,
      if (ownerId != null) 'owner_id': ownerId,
      if (schoolName != null) 'school_name': schoolName,
      if (className != null) 'class_name': className,
      if (teacherName != null) 'teacher_name': teacherName,
      if (deviceName != null) 'device_name': deviceName,
    });
    _ref.invalidate(staffAdminOrgDetailProvider(orgId));
  }

  Future<void> updateSchool({
    required String schoolId,
    required String orgId,
    String? schoolName,
    String? className,
    String? teacherName,
    String? deviceName,
    String? ownerId,
  }) async {
    await _invoke({
      'action': 'update_school',
      'school_id': schoolId,
      if (schoolName != null) 'school_name': schoolName,
      if (className != null) 'class_name': className,
      if (teacherName != null) 'teacher_name': teacherName,
      if (deviceName != null) 'device_name': deviceName,
      if (ownerId != null) 'owner_id': ownerId,
    });
    _ref.invalidate(staffAdminOrgDetailProvider(orgId));
  }

  Future<void> deleteSchool(String schoolId, String orgId) async {
    await _invoke({'action': 'delete_school', 'school_id': schoolId});
    _ref.invalidate(staffAdminOrgDetailProvider(orgId));
  }

  // Users
  Future<void> createUser({
    required String email,
    required String password,
    String? orgId,
    String? role,
  }) async {
    await _invoke({
      'action': 'create_user',
      'email': email,
      'password': password,
      if (orgId != null) 'org_id': orgId,
      if (role != null) 'role': role,
    });
    _ref.invalidate(staffAdminUsersProvider);
    if (orgId != null) _ref.invalidate(staffAdminOrgDetailProvider(orgId));
  }

  Future<void> deleteUser(String userId) async {
    await _invoke({'action': 'delete_user', 'user_id': userId});
    _ref.invalidate(staffAdminUsersProvider);
    _ref.invalidate(staffAdminOrgsProvider);
  }

  Future<void> resetUserPassword(String email) async {
    await _invoke({'action': 'reset_user_password', 'email': email});
  }

  // Org Members
  Future<void> addOrgMember({
    required String orgId,
    required String userId,
    required String role,
  }) async {
    await _invoke({
      'action': 'add_org_member',
      'org_id': orgId,
      'user_id': userId,
      'role': role,
    });
    _ref.invalidate(staffAdminOrgDetailProvider(orgId));
    _ref.invalidate(staffAdminUsersProvider);
  }

  Future<void> updateOrgMember({
    required String memberId,
    required String role,
    required String orgId,
  }) async {
    await _invoke({'action': 'update_org_member', 'member_id': memberId, 'role': role});
    _ref.invalidate(staffAdminOrgDetailProvider(orgId));
  }

  Future<void> removeOrgMember(String memberId, String orgId) async {
    await _invoke({'action': 'remove_org_member', 'member_id': memberId});
    _ref.invalidate(staffAdminOrgDetailProvider(orgId));
    _ref.invalidate(staffAdminUsersProvider);
  }
}

final staffAdminActionsProvider = Provider<StaffAdminActions>((ref) {
  return StaffAdminActions(ref);
});
