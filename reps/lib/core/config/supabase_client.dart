import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

class SupabaseConfig {
  const SupabaseConfig._();

  static Future<void> initialize() async {
    if (!Env.hasSupabase) {
      return;
    }
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient? get clientOrNull {
    if (!Env.hasSupabase) {
      return null;
    }
    return Supabase.instance.client;
  }
}
