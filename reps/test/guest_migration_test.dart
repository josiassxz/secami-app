// Fase 1.1 (docs/stages/stage-07-arquitetura.md): no login, os dados criados
// como convidado precisam ser reatribuidos para a nova conta. Sem isso ficam
// orfaos: somem da UI (queries filtram por user_id) e nunca sobem no sync.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  const guest = 'guest-uuid';
  const conta = 'supabase-uuid';

  test('reatribui rotina/sessao/cardio do convidado e marca dirty', () async {
    await db.routineDao.upsert(
      RoutinesCompanion.insert(
        id: 'r1',
        userId: guest,
        nome: 'A',
        dirty: const Value(false),
      ),
      markDirty: false,
    );
    await db.sessionDao.upsert(
      WorkoutSessionsCompanion.insert(
        id: 's1',
        userId: guest,
        dirty: const Value(false),
      ),
      markDirty: false,
    );
    await db.cardioDao.upsert(
      CardioSessionsCompanion.insert(
        id: 'c1',
        userId: guest,
        modalidade: 'corrida',
        duracaoMinutos: 30,
        dirty: const Value(false),
      ),
      markDirty: false,
    );

    final total = await db.reassignGuestData(guestId: guest, newUserId: conta);

    expect(total, 3, reason: 'rotina + sessao + cardio reatribuidos');

    final r = await db.routineDao.findById('r1');
    expect(r!.userId, conta);
    expect(r.dirty, isTrue, reason: 'precisa subir no proximo sync');

    final s = await db.sessionDao.findById('s1');
    expect(s!.userId, conta);
    expect(s.dirty, isTrue);

    // Aparece nas queries da nova conta (antes sumiria da UI).
    final rotinas = await db.routineDao.listAtivas(conta);
    expect(rotinas.map((e) => e.id), contains('r1'));
  });

  test('nao toca dados de outro usuario', () async {
    await db.routineDao.upsert(
      RoutinesCompanion.insert(id: 'r2', userId: 'outro', nome: 'B'),
      markDirty: false,
    );

    final total = await db.reassignGuestData(guestId: guest, newUserId: conta);

    expect(total, 0);
    final r = await db.routineDao.findById('r2');
    expect(r!.userId, 'outro');
  });

  test('no-op quando guest == conta', () async {
    final total = await db.reassignGuestData(guestId: conta, newUserId: conta);
    expect(total, 0);
  });

  test('no-op com guestId vazio', () async {
    final total = await db.reassignGuestData(guestId: '', newUserId: conta);
    expect(total, 0);
  });
}
