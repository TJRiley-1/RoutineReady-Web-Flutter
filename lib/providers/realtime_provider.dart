import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/active_timeline.dart';
import 'auth_provider.dart';
import 'school_provider.dart';

/// Whether the realtime connection is currently live.
final realtimeConnectedProvider = StateProvider<bool>((ref) => false);

final realtimeProvider = Provider<RealtimeManager>((ref) {
  return RealtimeManager(ref);
});

class RealtimeManager {
  final Ref _ref;
  RealtimeChannel? _channel;
  String? _schoolId;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = 30; // seconds

  // Flapping protection: a connection that drops and reconnects repeatedly
  // (flaky classroom wifi, router hiccups) must not be treated as recovered
  // just because it briefly reached 'subscribed'. Without this, every flap
  // reset _reconnectAttempts to 0, removing all backoff, and every flap also
  // triggered a full 7-query reload() below — turning ordinary network
  // instability into a sustained request storm (~60+ reconnects/min observed
  // in production on 2026-07-02, days after the original stale-channel bug
  // was fixed, with no code changes — confirmed via pg_stat_statements).
  // A connection only counts as "recovered" after staying up for this long.
  static const _stableConnectionThreshold = Duration(seconds: 15);
  Timer? _stableConnectionTimer;

  // Reload is expensive (schools/display_settings/templates/tasks/
  // active_timeline/weekly_schedules/custom_themes = 7 queries). Cap how
  // often a reconnect can trigger one, independent of how often reconnects
  // themselves happen.
  static const _minReloadInterval = Duration(seconds: 15);
  DateTime? _lastReloadAt;

  RealtimeManager(this._ref);

  SupabaseClient get _client => _ref.read(supabaseClientProvider);

  void subscribe(String schoolId) {
    _schoolId = schoolId;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _connect(schoolId);
  }

  void _connect(String schoolId) {
    _channel?.unsubscribe();
    _channel = null;

    // Capture the channel in a local so the subscribe callback can detect if
    // it's stale. When _connect() is called again (e.g. during reconnect), the
    // old channel fires a 'closed' callback asynchronously after unsubscribe.
    // Without this guard, that stale callback would call _scheduleReconnect(),
    // tearing down the fresh connection and creating an infinite reload loop
    // (~7 Supabase queries/sec = 420/min).
    RealtimeChannel? channel;
    channel = _client
        .channel('school_$schoolId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'active_timeline',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'school_id',
            value: schoolId,
          ),
          callback: (payload) {
            _handleTimelineChange(payload);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'display_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'school_id',
            value: schoolId,
          ),
          callback: (payload) {
            _handleDisplaySettingsChange(payload);
          },
        )
        .subscribe((status, [error]) {
          if (!identical(_channel, channel)) return; // stale: already reconnected
          if (status == RealtimeSubscribeStatus.subscribed) {
            _ref.read(realtimeConnectedProvider.notifier).state = true;
            // Only treat the connection as genuinely recovered (and reset
            // backoff) once it has stayed up for a while. A flap that drops
            // again before this fires leaves _reconnectAttempts wherever it
            // was, so backoff keeps escalating through a flapping period
            // instead of resetting to 1s on every brief success.
            _stableConnectionTimer?.cancel();
            _stableConnectionTimer = Timer(_stableConnectionThreshold, () {
              _reconnectAttempts = 0;
            });
          } else if (status == RealtimeSubscribeStatus.closed ||
                     status == RealtimeSubscribeStatus.channelError) {
            _stableConnectionTimer?.cancel();
            _ref.read(realtimeConnectedProvider.notifier).state = false;
            _scheduleReconnect();
          }
        });
    _channel = channel;
  }

  void _scheduleReconnect() {
    if (_schoolId == null) return; // Already unsubscribed intentionally

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (capped)
    final delay = _reconnectAttempts <= 1
        ? 1
        : (1 << (_reconnectAttempts - 1)).clamp(1, _maxReconnectDelay);

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_schoolId != null) {
        _connect(_schoolId!);
        _maybeReload();
      }
    });
  }

  // Re-fetch full data to catch anything missed while disconnected — but
  // never more often than _minReloadInterval, regardless of how often
  // reconnects fire. A single genuine outage still gets one reload; a
  // flapping connection doesn't get one reload per flap.
  void _maybeReload() {
    final now = DateTime.now();
    if (_lastReloadAt != null &&
        now.difference(_lastReloadAt!) < _minReloadInterval) {
      return;
    }
    _lastReloadAt = now;
    _ref.read(schoolProvider.notifier).reload();
  }

  void _handleTimelineChange(PostgresChangePayload payload) {
    final newData = payload.newRecord;
    if (newData.isEmpty) return;

    // Carries tasks plus the per-template settings/theme snapshot — this is how
    // a peer device receives per-template changes live. Guard against a
    // malformed payload so a bad row can't throw inside the realtime callback;
    // the next full reload will resync.
    try {
      _ref
          .read(schoolProvider.notifier)
          .applyRemoteTimeline(ActiveTimeline.fromJson(newData));
    } catch (_) {}
  }

  void _handleDisplaySettingsChange(PostgresChangePayload payload) {
    final newData = payload.newRecord;
    if (newData.isEmpty) return;

    // Only the classroom-wide fields live here now; per-template settings + theme
    // arrive via the active_timeline snapshot above.
    try {
      _ref.read(schoolProvider.notifier).applyRemoteGlobals(newData);
    } catch (_) {}
  }

  void unsubscribe() {
    _schoolId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stableConnectionTimer?.cancel();
    _stableConnectionTimer = null;
    _reconnectAttempts = 0;
    _channel?.unsubscribe();
    _channel = null;
    _ref.read(realtimeConnectedProvider.notifier).state = false;
  }
}
