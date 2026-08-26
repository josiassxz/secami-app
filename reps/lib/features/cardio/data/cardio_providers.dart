import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../data/local/database.dart';
import '../../auth/data/auth_providers.dart';

const _uuid = Uuid();

class CardioService {
  CardioService(this._db, this._userId);

  final AppDatabase _db;
  final String _userId;

  Stream<List<CardioSessionRow>> watchAll() =>
      _db.cardioDao.watchByUser(_userId);

  Future<String> create({
    required String modalidade,
    required int duracaoMinutos,
    double? distanciaKm,
    int? intensidade,
    int? fcMedia,
    int? fcMax,
    int? calorias,
    DateTime? executadoEm,
  }) async {
    final id = _uuid.v4();
    await _db.cardioDao.upsert(
      CardioSessionsCompanion.insert(
        id: id,
        userId: _userId,
        modalidade: modalidade,
        duracaoMinutos: duracaoMinutos,
        distanciaKm: Value(distanciaKm),
        intensidade: Value(intensidade),
        fcMedia: Value(fcMedia),
        fcMax: Value(fcMax),
        calorias: Value(calorias),
        executadoEm: Value(executadoEm ?? DateTime.now().toUtc()),
      ),
    );
    return id;
  }

  Future<void> remove(String id) => _db.cardioDao.softDelete(id);
}

final cardioServiceProvider = Provider<CardioService>((ref) {
  return CardioService(
    ref.watch(appDatabaseProvider),
    ref.watch(effectiveUserIdProvider),
  );
});

final cardioListProvider = StreamProvider<List<CardioSessionRow>>((ref) {
  return ref.watch(cardioServiceProvider).watchAll();
});
