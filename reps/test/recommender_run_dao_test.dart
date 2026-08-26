// Cobre o E5: persistencia auditavel e o gate de sincronizacao por
// consentimento (RN-051). So registros `sincronizavel` entram na fila de push.

import 'package:drift/drift.dart' hide isNull, isNotNull;
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

  RecommenderRunsCompanion run(String id, {required bool sincronizavel}) {
    return RecommenderRunsCompanion.insert(
      id: id,
      userId: 'u1',
      versaoRegras: 'rec-v1',
      perfilJson: '{}',
      treinoJson: '{}',
      sincronizavel: Value(sincronizavel),
    );
  }

  test(
    'so registros com consentimento entram na fila de sync (RN-051)',
    () async {
      await db.recommenderRunDao.insert(run('a', sincronizavel: true));
      await db.recommenderRunDao.insert(run('b', sincronizavel: false));

      final pend = await db.recommenderRunDao.pendentesSync('u1');
      expect(pend.map((r) => r.id), ['a']);
    },
  );

  test('marcarSincronizado remove da fila', () async {
    await db.recommenderRunDao.insert(run('a', sincronizavel: true));
    await db.recommenderRunDao.marcarSincronizado('a');

    final pend = await db.recommenderRunDao.pendentesSync('u1');
    expect(pend, isEmpty);
  });

  test('marcarSincronizadoAll em batch remove da fila', () async {
    await db.recommenderRunDao.insert(run('a', sincronizavel: true));
    await db.recommenderRunDao.insert(run('b', sincronizavel: true));
    await db.recommenderRunDao.insert(run('c', sincronizavel: true));

    await db.recommenderRunDao.marcarSincronizadoAll(['a', 'c']);

    final pend = await db.recommenderRunDao.pendentesSync('u1');
    expect(pend.map((r) => r.id), ['b']);
  });

  test('marcarSincronizadoAll com lista vazia e no-op', () async {
    await db.recommenderRunDao.insert(run('a', sincronizavel: true));

    await db.recommenderRunDao.marcarSincronizadoAll([]);

    final pend = await db.recommenderRunDao.pendentesSync('u1');
    expect(pend.map((r) => r.id), ['a']);
  });

  test('triagem sem consentimento fica nula no registro', () async {
    await db.recommenderRunDao.insert(run('a', sincronizavel: false));
    final rows = await db.recommenderRunDao.watchAll('u1').first;
    expect(rows.single.triagemJson, isNull);
  });
}
