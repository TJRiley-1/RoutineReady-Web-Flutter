import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which mode this device is using: 'display', 'admin', or null (not yet chosen).
///
/// Display-count licensing is enforced by how many classrooms RoutineReady staff
/// create (one classroom = one paid display), plus the per-classroom on/off
/// switch (`schools.is_active`) — so there is no concurrent-session/slot
/// counting here anymore.
final sessionModeProvider = StateProvider<String?>((ref) => null);
