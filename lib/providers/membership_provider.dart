import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/org_member.dart';
import '../models/organization.dart';
import '../models/school.dart';
import 'auth_provider.dart';

const _rememberedClassroomKey = 'routine_ready_remembered_classroom';

/// The current user's org membership (role + org info).
final membershipProvider = FutureProvider<OrgMember?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final client = ref.read(supabaseClientProvider);

  final res = await client
      .from('org_members')
      .select()
      .eq('user_id', userId)
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
      .order('class_name', ascending: true);
  return (res as List).map((s) => School.fromJson(s)).toList();
});

/// All classrooms across every org, grouped by org — for RoutineReady staff
/// super-admins. Relies on the staff RLS read bypass (is_routineready_staff).
typedef OrgClassrooms = ({Organization org, List<School> classrooms});

final staffAllClassroomsProvider =
    FutureProvider<List<OrgClassrooms>>((ref) async {
  final client = ref.read(supabaseClientProvider);

  final orgsRes =
      await client.from('organizations').select().order('name', ascending: true);
  final schoolsRes = await client
      .from('schools')
      .select()
      .order('class_name', ascending: true);

  final orgs = (orgsRes as List).map((o) => Organization.fromJson(o)).toList();
  final schools = (schoolsRes as List).map((s) => School.fromJson(s)).toList();

  final byOrg = <String, List<School>>{};
  for (final s in schools) {
    if (s.orgId == null) continue;
    byOrg.putIfAbsent(s.orgId!, () => []).add(s);
  }

  return [
    for (final org in orgs)
      if ((byOrg[org.id] ?? const []).isNotEmpty)
        (org: org, classrooms: byOrg[org.id]!),
  ];
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
