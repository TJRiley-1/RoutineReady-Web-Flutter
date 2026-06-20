import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'providers/subscription_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    // Implicit flow so email-link auth (password reset, magic link, invite, etc.)
    // works cross-device — the link carries the tokens itself and doesn't need a
    // PKCE code verifier stored on the originating device.
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // Initialize RevenueCat (no-op if API keys not yet configured)
  await initRevenueCat();

  // Link RevenueCat to Supabase user on auth state changes
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.signedIn &&
        data.session?.user != null) {
      linkRevenueCatUser(data.session!.user.id);
    } else if (data.event == AuthChangeEvent.signedOut) {
      unlinkRevenueCatUser();
    }
  });

  // If already signed in, link immediately
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser != null) {
    linkRevenueCatUser(currentUser.id);
  }

  runApp(
    const ProviderScope(
      child: RoutineReadyApp(),
    ),
  );
}
