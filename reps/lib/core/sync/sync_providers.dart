import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local/database.dart';
import '../../features/auth/data/auth_providers.dart';
import '../network/api_client.dart';
import 'sync_engine.dart';
import 'sync_status.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final engine = SyncEngine(db, apiClient: ref.watch(apiClientProvider));
  engine.startPeriodic();
  // Auto-sync dirigido por dados: qualquer escrita que marque linhas dirty
  // agenda um sync (debounce). Os services nao chamam mais runOnce (3.2).
  engine.startAutoSync(db.watchDirtyCount());

  // Dispara um sync assim que o usuario loga, pra puxar os treinos que ja
  // existem na conta (antes so vinha no proximo tick de 5 min ou ao criar algo).
  // Antes do sync, reatribui dados criados como convidado para a nova conta
  // (senao ficam orfaos: somem da UI e nunca sobem). Ver
  // AppDatabase.reassignGuestData e docs/stages/stage-07-arquitetura.md (1.1).
  ref.listen<User?>(currentUserProvider, (prev, next) {
    if (next != null && prev?.id != next.id) {
      final guestId = ref.read(guestIdentityProvider).current;
      unawaited(() async {
        if (guestId != null) {
          await db.reassignGuestData(guestId: guestId, newUserId: next.id);
        }
        await engine.runOnce();
      }());
    }
  });
  // E na subida do app, se ja houver sessao ativa.
  if (ref.read(currentUserProvider) != null) {
    unawaited(engine.runOnce());
  }

  ref.onDispose(engine.dispose);
  return engine;
});

// statusStream é broadcast (sem buffer): quem assina depois não recebe o
// último valor. Emitir engine.status primeiro faz a UI (banner, tile de
// Ajustes) mostrar o estado atual — última sync, pendentes, offline — na hora,
// sem esperar o próximo tick emitir.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final engine = ref.watch(syncEngineProvider);
  yield engine.status;
  yield* engine.statusStream;
});
