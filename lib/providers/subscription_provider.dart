import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/revenuecat_config.dart';
import 'auth_provider.dart';
import 'membership_provider.dart';

/// Whether RevenueCat has been initialized.
bool _revenueCatInitialized = false;

/// Initialize RevenueCat SDK. Call once at app startup.
Future<void> initRevenueCat() async {
  if (!RevenueCatConfig.isConfigured) return;
  if (_revenueCatInitialized) return;

  await Purchases.setLogLevel(LogLevel.debug);

  late PurchasesConfiguration config;
  if (kIsWeb) {
    if (RevenueCatConfig.webApiKey.isEmpty) return;
    config = PurchasesConfiguration(RevenueCatConfig.webApiKey);
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    if (RevenueCatConfig.googleApiKey.isEmpty) return;
    config = PurchasesConfiguration(RevenueCatConfig.googleApiKey);
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    if (RevenueCatConfig.appleApiKey.isEmpty) return;
    config = PurchasesConfiguration(RevenueCatConfig.appleApiKey);
  } else {
    return; // Unsupported platform
  }

  await Purchases.configure(config);
  _revenueCatInitialized = true;
}

/// Link RevenueCat customer to Supabase user. Call after auth.
Future<void> linkRevenueCatUser(String supabaseUserId) async {
  if (!_revenueCatInitialized) return;
  await Purchases.logIn(supabaseUserId);
}

/// Unlink RevenueCat customer on sign-out.
Future<void> unlinkRevenueCatUser() async {
  if (!_revenueCatInitialized) return;
  await Purchases.logOut();
}

/// Check RevenueCat entitlement directly (client-side, cached).
Future<bool> checkRevenueCatEntitlement() async {
  if (!_revenueCatInitialized) return false;
  try {
    final customerInfo = await Purchases.getCustomerInfo();
    return customerInfo
            .entitlements.all[RevenueCatConfig.entitlementId]?.isActive ??
        false;
  } catch (_) {
    return false;
  }
}

/// Subscription plan lookup — checks three sources:
/// 1. User-level subscription (RevenueCat App Store / Stripe)
/// 2. School-level subscription (manually set up by admin)
/// 3. No subscription = free tier
final subscriptionPlanProvider = FutureProvider<String>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return 'free';

  final client = ref.read(supabaseClientProvider);

  // Check user-level subscription first (App Store / RevenueCat)
  final userSub = await client
      .from('subscriptions')
      .select('plan, status')
      .eq('user_id', userId)
      .eq('status', 'active')
      .limit(1)
      .maybeSingle();

  if (userSub != null) {
    return userSub['plan'] as String? ?? 'free';
  }

  // Then check org-level subscription
  final membership = await ref.watch(membershipProvider.future);
  if (membership != null) {
    final orgSub = await client
        .from('subscriptions')
        .select('plan, status')
        .eq('org_id', membership.orgId)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();

    if (orgSub != null) {
      return orgSub['plan'] as String? ?? 'free';
    }
  }

  // Then check school-level subscription (manual setup)
  final school = await client
      .from('schools')
      .select('id')
      .eq('owner_id', userId)
      .limit(1)
      .maybeSingle();

  if (school == null) return 'free';

  final schoolSub = await client
      .from('subscriptions')
      .select('plan, status')
      .eq('school_id', school['id'])
      .eq('status', 'active')
      .limit(1)
      .maybeSingle();

  if (schoolSub == null) return 'free';
  return schoolSub['plan'] as String? ?? 'free';
});

/// Full subscription state with slot limits.
final subscriptionProvider = FutureProvider<SubscriptionState>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return SubscriptionState.free();

  final client = ref.read(supabaseClientProvider);

  // Check user-level subscription first
  final userSub = await client
      .from('subscriptions')
      .select()
      .eq('user_id', userId)
      .eq('status', 'active')
      .limit(1)
      .maybeSingle();

  if (userSub != null) {
    return SubscriptionState(
      plan: userSub['plan'] as String? ?? 'free',
      maxDisplaySlots: userSub['max_display_slots'] as int? ?? 1,
      maxAdminSlots: userSub['max_admin_slots'] as int? ?? 1,
      status: userSub['status'] as String? ?? 'active',
      source: userSub['source'] as String? ?? 'unknown',
      periodType: userSub['period_type'] as String?,
      expiresAt: userSub['expires_at'] != null
          ? DateTime.tryParse(userSub['expires_at'] as String)
          : null,
    );
  }

  // Then check org-level subscription
  final membership = await ref.watch(membershipProvider.future);
  if (membership != null) {
    final orgSub = await client
        .from('subscriptions')
        .select()
        .eq('org_id', membership.orgId)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();

    if (orgSub != null) {
      return SubscriptionState(
        plan: orgSub['plan'] as String? ?? 'free',
        maxDisplaySlots: orgSub['max_display_slots'] as int? ?? 1,
        maxAdminSlots: orgSub['max_admin_slots'] as int? ?? 1,
        status: orgSub['status'] as String? ?? 'active',
        source: orgSub['source'] as String? ?? 'manual',
        periodType: orgSub['period_type'] as String?,
        expiresAt: orgSub['expires_at'] != null
            ? DateTime.tryParse(orgSub['expires_at'] as String)
            : null,
      );
    }
  }

  // Then check school-level subscription
  final school = await client
      .from('schools')
      .select('id')
      .eq('owner_id', userId)
      .limit(1)
      .maybeSingle();

  if (school == null) return SubscriptionState.free();

  final schoolSub = await client
      .from('subscriptions')
      .select()
      .eq('school_id', school['id'])
      .eq('status', 'active')
      .limit(1)
      .maybeSingle();

  if (schoolSub == null) return SubscriptionState.free();

  return SubscriptionState(
    plan: schoolSub['plan'] as String? ?? 'free',
    maxDisplaySlots: schoolSub['max_display_slots'] as int? ?? 1,
    maxAdminSlots: schoolSub['max_admin_slots'] as int? ?? 1,
    status: schoolSub['status'] as String? ?? 'active',
    source: schoolSub['source'] as String? ?? 'manual',
    periodType: schoolSub['period_type'] as String?,
    expiresAt: schoolSub['expires_at'] != null
        ? DateTime.tryParse(schoolSub['expires_at'] as String)
        : null,
  );
});

/// Convenience provider: is the user on a paid plan?
final isPaidProvider = Provider<bool>((ref) {
  final plan = ref.watch(subscriptionPlanProvider).valueOrNull;
  return plan != null && plan != 'free';
});

/// Available offerings from RevenueCat (for paywall display).
final revenueCatOfferingsProvider = FutureProvider<Offerings?>((ref) async {
  if (!_revenueCatInitialized) return null;
  try {
    return await Purchases.getOfferings();
  } catch (_) {
    return null;
  }
});

class SubscriptionState {
  final String plan;
  final int maxDisplaySlots;
  final int maxAdminSlots;
  final String status;
  final String source;
  final String? periodType;
  final DateTime? expiresAt;

  SubscriptionState({
    required this.plan,
    this.maxDisplaySlots = 1,
    this.maxAdminSlots = 1,
    this.status = 'active',
    this.source = 'unknown',
    this.periodType,
    this.expiresAt,
  });

  factory SubscriptionState.free() => SubscriptionState(plan: 'free');

  bool get isFree => plan == 'free';
  bool get isPaid => plan != 'free' && status == 'active';
  bool get isLifetime => periodType == 'lifetime';
}
