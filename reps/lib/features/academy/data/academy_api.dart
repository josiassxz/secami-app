import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Slot ofertado para agendamento (SPEC §9.4).
class AvailableSlot {
  const AvailableSlot({
    required this.slotStart,
    required this.slotEnd,
    required this.maxCapacity,
    required this.civilCount,
    required this.available,
    this.reason,
  });

  final String slotStart;
  final String slotEnd;
  final int maxCapacity;
  final int civilCount;
  final bool available;
  final String? reason;

  factory AvailableSlot.fromJson(Map<String, dynamic> j) => AvailableSlot(
    slotStart: j['slotStart'] as String,
    slotEnd: (j['slotEnd'] as String?) ?? '',
    maxCapacity: (j['maxCapacity'] as num?)?.toInt() ?? 0,
    civilCount: (j['civilCount'] as num?)?.toInt() ?? 0,
    available: (j['available'] as bool?) ?? false,
    reason: j['reason'] as String?,
  );
}

/// Agendamento do aluno.
class ScheduledAppointment {
  const ScheduledAppointment({
    required this.id,
    required this.date,
    required this.slotStart,
    required this.slotEnd,
    required this.status,
  });

  final String id;
  final String date;
  final String slotStart;
  final String slotEnd;
  final String status;

  /// Se o horário já começou (data + hora de início, no relógio do aparelho).
  /// Horário já começado não se cancela — apagaria a presença/falta.
  bool jaComecou(DateTime agora) {
    final inicio = DateTime.tryParse('${date}T$slotStart:00');
    return inicio != null && !inicio.isAfter(agora);
  }

  factory ScheduledAppointment.fromJson(Map<String, dynamic> j) =>
      ScheduledAppointment(
        id: j['id'] as String,
        date: (j['date'] as String?) ?? '',
        slotStart: (j['slotStart'] as String?) ?? '',
        slotEnd: (j['slotEnd'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'agendado',
      );
}

/// Item de uma ficha de treino.
class PlanExercise {
  const PlanExercise({
    required this.exerciseName,
    this.sets,
    this.reps,
    this.restSeconds,
    this.notes,
  });

  final String exerciseName;
  final int? sets;
  final String? reps;
  final int? restSeconds;
  final String? notes;

  factory PlanExercise.fromJson(Map<String, dynamic> j) => PlanExercise(
    exerciseName: (j['exerciseName'] as String?) ?? '',
    sets: (j['sets'] as num?)?.toInt(),
    reps: j['reps'] as String?,
    restSeconds: (j['restSeconds'] as num?)?.toInt(),
    notes: j['notes'] as String?,
  );
}

/// Ficha de treino (A–D) prescrita ao aluno.
class WorkoutPlanDto {
  const WorkoutPlanDto({
    required this.id,
    required this.sheetLabel,
    required this.title,
    required this.active,
    required this.exercises,
  });

  final String id;
  final String sheetLabel;
  final String title;
  final bool active;
  final List<PlanExercise> exercises;

  factory WorkoutPlanDto.fromJson(Map<String, dynamic> j) => WorkoutPlanDto(
    id: j['id'] as String,
    sheetLabel: (j['sheetLabel'] as String?) ?? 'A',
    title: (j['title'] as String?) ?? '',
    active: (j['active'] as bool?) ?? true,
    exercises: ((j['exercises'] as List?) ?? const [])
        .map((e) => PlanExercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Aviso/informativo.
class NoticeDto {
  const NoticeDto({
    this.id = '',
    required this.title,
    required this.content,
    required this.type,
  });

  final String id;
  final String title;
  final String content;
  final String type;

  factory NoticeDto.fromJson(Map<String, dynamic> j) => NoticeDto(
    id: (j['id'] as String?) ?? '',
    title: (j['title'] as String?) ?? '',
    content: (j['content'] as String?) ?? '',
    type: (j['type'] as String?) ?? 'info',
  );
}

/// Situação de uma punição de Lutas.
enum StatusPunicao { pendente, cumprida, concluida, desconhecido }

/// Item de uma punição (ex.: "10 flexões", "1 Coca-Cola").
class ItemPunicao {
  const ItemPunicao({required this.itemId, required this.nome});

  final String itemId;
  final String nome;

  factory ItemPunicao.fromJson(Map<String, dynamic> j) => ItemPunicao(
    itemId: (j['itemId'] as String?) ?? '',
    nome: ((j['nome'] as String?) ?? '').trim(),
  );
}

/// Punição aplicada por um instrutor de Lutas ao aluno (`GET /me/punicoes`).
class Punicao {
  const Punicao({
    required this.id,
    required this.itens,
    required this.status,
    this.studentId = '',
    this.studentName = '',
    this.observacao,
    this.aplicadaEm,
    this.aplicadaPorNome,
    this.cumpridaEm,
    this.cumpridaPorNome,
    this.concluidaEm,
  });

  final String id;
  final String studentId;
  final String studentName;
  final List<ItemPunicao> itens;
  final String? observacao;
  final StatusPunicao status;
  final DateTime? aplicadaEm;
  final String? aplicadaPorNome;
  final DateTime? cumpridaEm;
  final String? cumpridaPorNome;
  final DateTime? concluidaEm;

  /// "10 flexões + 1 Coca-Cola".
  String get descricao =>
      itens.map((i) => i.nome).where((n) => n.isNotEmpty).join(' + ');

  factory Punicao.fromJson(Map<String, dynamic> j) => Punicao(
    id: (j['id'] as String?) ?? '',
    studentId: (j['studentId'] as String?) ?? '',
    studentName: (j['studentName'] as String?) ?? '',
    itens: ((j['itens'] as List?) ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => ItemPunicao.fromJson(Map<String, dynamic>.from(e)))
        .toList(),
    observacao: _textoOuNulo(j['observacao']),
    status: switch ((j['status'] as String?)?.toUpperCase()) {
      'PENDENTE' => StatusPunicao.pendente,
      'CUMPRIDA' => StatusPunicao.cumprida,
      'CONCLUIDA' => StatusPunicao.concluida,
      _ => StatusPunicao.desconhecido,
    },
    aplicadaEm: _instante(j['aplicadaEm']),
    aplicadaPorNome: _textoOuNulo(j['aplicadaPorNome']),
    cumpridaEm: _instante(j['cumpridaEm']),
    cumpridaPorNome: _textoOuNulo(j['cumpridaPorNome']),
    concluidaEm: _instante(j['concluidaEm']),
  );
}

String? _textoOuNulo(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// ISO do servidor no fuso do aparelho.
DateTime? _instante(Object? v) {
  final t = _textoOuNulo(v);
  if (t == null) return null;
  final d = DateTime.tryParse(t);
  if (d == null) return null;
  return d.isUtc ? d.toLocal() : d;
}

/// Acesso REST as funcionalidades de academia do aluno (SPEC §10.4).
class AcademyApi {
  AcademyApi(this._api);

  final ApiClient _api;

  Future<List<AvailableSlot>> availableSlots(String date) async {
    final data =
        await _api.get('/me/appointments/available?date=$date') as List;
    return data
        .map((e) => AvailableSlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ScheduledAppointment> book(String date, String slotStart) async {
    final data =
        await _api.post(
              '/me/appointments',
              body: {'date': date, 'slotStart': slotStart},
            )
            as Map<String, dynamic>;
    return ScheduledAppointment.fromJson(data);
  }

  Future<List<ScheduledAppointment>> myAppointments() async {
    final data = await _api.get('/me/appointments') as List;
    return data
        .map((e) => ScheduledAppointment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> cancelAppointment(String id) => _api.delete('/appointments/$id');

  Future<List<WorkoutPlanDto>> myWorkoutPlans() async {
    final data = await _api.get('/me/workout-plans') as List;
    return data
        .map((e) => WorkoutPlanDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<NoticeDto>> notices() async {
    final data = await _api.get('/notices/active') as List;
    return data
        .map((e) => NoticeDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> myProfile() async =>
      await _api.get('/me/student') as Map<String, dynamic>;

  /// Punições em aberto (pendentes e cumpridas) do aluno de Lutas, da mais
  /// antiga pra mais nova. Quem não é de Lutas recebe lista vazia.
  Future<List<Punicao>> meusPunicoes() async {
    final data = await _api.get('/me/punicoes');
    if (data is! List) return const [];
    return data
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => Punicao.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> updateMyProfile(Map<String, dynamic> patch) =>
      _api.put('/me/student', body: patch);
}

final academyApiProvider = Provider<AcademyApi>(
  (ref) => AcademyApi(ref.watch(apiClientProvider)),
);
