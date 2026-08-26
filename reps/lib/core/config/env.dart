import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  const Env._();

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }

  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabaseAnonKey =>
      dotenv.get('SUPABASE_ANON_KEY', fallback: '');

  /// Base URL da API SECAMI (backend Spring Boot). Ex.: https://api.secami...
  /// Quando definida, o app usa o backend REST + LDAP (SPEC §10) em vez do
  /// Supabase. Vazia = comportamento legado (Supabase).
  static String get apiBaseUrl => dotenv.get('API_BASE_URL', fallback: '');

  static bool get hasRestApi => apiBaseUrl.isNotEmpty;

  /// URL para onde o Supabase redireciona apos o clique no link de
  /// confirmacao de e-mail. Aponta para a pagina de agradecimento estatica
  /// (Vercel — Supabase nao renderiza HTML no supabase.co), nao o esquema
  /// `reps://` cru, que quebra no navegador desktop.
  /// Sem valor, cai no esquema nativo (comportamento antigo).
  static String get authRedirectUrl =>
      dotenv.get('AUTH_REDIRECT_URL', fallback: 'reps://auth-callback');

  static String get sentryDsn => dotenv.get('SENTRY_DSN', fallback: '');
  static String get posthogApiKey =>
      dotenv.get('POSTHOG_API_KEY', fallback: '');
  static String get posthogHost =>
      dotenv.get('POSTHOG_HOST', fallback: 'https://us.i.posthog.com');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasSentry => sentryDsn.isNotEmpty;
  static bool get hasPostHog => posthogApiKey.isNotEmpty;
}
