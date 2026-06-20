import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/org_member.dart';
import '../models/organization.dart';
import '../models/school.dart';
import 'auth_provider.dart';

const _rememberedClassroomKey = 'routine_ready_remembered_classroom';

/// The current user's org membership (role + org info).
final membershipProvider = FutureProvider<OrgMember?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final client = ref.read(supabaseClientProvider);

  final res = await client
      .from('org_members')
      .select()
      .eq('user_id', user.id)
      .limit(1)
      .maybeSingle();

  if (res == null) return null;
  return OrgMember.fromJson(res);
});

/// The organization the current user belongs to.
final organizationProvider = FutureProvider<Organization?>((ref) async {
  final membership = await ref.watch(membershipProvider.future);
  if (membership == null) return null;

  final client = ref.read(supabaseClientProvider);

  final res = await client
      .from('organizations')
      .select()
      .eq('id', membership.orgId)
      .limit(1)
      .maybeSingle();

  if (res == null) return null;
  return Organization.fromJson(res);
});

/// All classrooms (schools) in the user's org.
/// Every org member (incl. teachers) sees all classrooms in their org — RLS
/// permits this via private.user_in_school_org. Per-user restrictions can be
/// added later if needed; not required for MVP.
final classroomsProvider = FutureProvider<List<School>>((ref) async {
  final membership = await ref.watch(membershipProvider.future);
  if (membership == null) return [];

  final client = ref.read(supabaseClientProvider);

  final res = await client
      .from('schools')
      .select()
      .eq('org_id', membership.orgId)
      .order('class_name');
  return (res as List).map((s) => School.fromJson(s)).toList();
});

/// Currently selected classroom.
final selectedClassroomProvider = StateProvider<School?>((ref) => null);

/// For Display role: remembered classroom ID from secure storage.
final rememberedClassroomIdProvider = FutureProvider<String?>((ref) async {
  const storage = FlutterSecureStorage();
  return storage.read(key: _rememberedClassroomKey);
});

/// Save remembered classroom for display devices.
Future<void> saveRememberedClassroom(String classroomId) async {
  const storage = FlutterSecureStorage();
  await storage.write(key: _rememberedClassroomKey, value: classroomId);
}

/// Clear remembered classroom (for reset/reassignment).
Future<void> clearRememberedClassroom() async {
  const storage = FlutterSecureStorage();
  await storage.delete(key: _rememberedClassroomKey);
}
