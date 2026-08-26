import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Identidade do modo convidado. Persiste um uuid local em shared_preferences.
/// Usado como user_id em escritas locais ate o usuario criar conta.
class GuestIdentity {
  GuestIdentity(this._prefs);

  static const _key = 'reps.guest_user_id';
  static const _uuid = Uuid();

  final SharedPreferences _prefs;

  String getOrCreate() {
    final existing = _prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = _uuid.v4();
    // ignore: discarded_futures
    _prefs.setString(_key, created);
    return created;
  }

  String? get current => _prefs.getString(_key);

  Future<void> clear() => _prefs.remove(_key);
}
