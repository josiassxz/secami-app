import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Rótulos de ficha aceitos pelo backend (SPEC §9.3), na ordem de exibição.
const sheetLabels = ['A', 'B', 'C', 'D'];

/// Aluno na lista do instrutor (`GET /students`).
class StudentSummary {
  const StudentSummary({
    required this.id,
    required this.fullName,
    this.cpf = '',
    this.studentType = 'Civil',
    this.departmentName,
    this.situacao = 'ATIVO',
    this.active = true,
    this.photoId,
  });

  final String id;
  final String fullName;

  /// CPF já mascarado pelo backend.
  final String cpf;
  final String studentType;
  final String? departmentName;

  /// `ATIVO`, `INATIVO` ou `BLOQUEADO`.
  final String situacao;
  final bool active;
  final String? photoId;

  bool get isAtivo => situacao == 'ATIVO';

  factory StudentSummary.fromJson(Map<String, dynamic> j) => StudentSummary(
    id: j['id'].toString(),
    fullName: (j['fullName'] as String?) ?? '',
    cpf: (j['cpf'] as String?) ?? '',
    studentType: (j['studentType'] as String?) ?? 'Civil',
    departmentName: j['departmentName'] as String?,
    situacao: (j['situacao'] as String?) ?? 'ATIVO',
    active: (j['active'] as bool?) ?? true,
    photoId: j['photoId'] as String?,
  );
}

/// Página de alunos (Spring `Page`).
class StudentsPage {
  const StudentsPage({
    required this.content,
    this.totalElements = 0,
    this.totalPages = 0,
    this.number = 0,
    this.last = true,
  });

  final List<StudentSummary> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final bool last;

  factory StudentsPage.fromJson(Map<String, dynamic> j) {
    // Spring serializa a paginação na raiz (`Page`) ou aninhada em `page`
    // (`PagedModel`, conforme a config do backend) — aceita as duas formas.
    final aninhado = j['page'];
    final meta = aninhado is Map
        ? aninhado.cast<String, dynamic>()
        : const <String, dynamic>{};
    int campo(String nome) => ((j[nome] ?? meta[nome]) as num?)?.toInt() ?? 0;

    final content = ((j['content'] as List?) ?? const [])
        .map((e) => StudentSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    final number = campo('number');
    final totalPages = campo('totalPages');
    return StudentsPage(
      content: content,
      totalElements: campo('totalElements'),
      totalPages: totalPages,
      number: number,
      // Sem `last` explícito, deduz pela contagem de páginas.
      last: (j['last'] as bool?) ?? (number + 1 >= totalPages),
    );
  }
}

/// Exercício prescrito dentro de uma ficha.
class PlanExerciseItem {
  const PlanExerciseItem({
    required this.exerciseName,
    this.exerciseId,
    this.ordem = 0,
    this.sets,
    this.reps,
    this.restSeconds,
    this.notes,
  });

  /// Id no catálogo; `null` quando o exercício foi digitado livremente.
  final String? exerciseId;
  final String exerciseName;
  final int ordem;
  final int? sets;
  final String? reps;
  final int? restSeconds;
  final String? notes;

  factory PlanExerciseItem.fromJson(Map<String, dynamic> j) => PlanExerciseItem(
    exerciseId: j['exerciseId'] as String?,
    exerciseName: (j['exerciseName'] as String?) ?? '',
    ordem: (j['ordem'] as num?)?.toInt() ?? 0,
    sets: (j['sets'] as num?)?.toInt(),
    reps: j['reps'] as String?,
    restSeconds: (j['restSeconds'] as num?)?.toInt(),
    notes: j['notes'] as String?,
  );

  /// Corpo do item em `POST`/`PUT /workout-plans`. A ordem não vai no corpo:
  /// o backend usa a posição no array.
  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'sets': sets,
    'reps': reps,
    'restSeconds': restSeconds,
    'notes': notes,
  };
}

/// Ficha de treino (A–D) de um aluno, vista pelo instrutor.
class InstructorWorkoutPlan {
  const InstructorWorkoutPlan({
    required this.id,
    required this.studentId,
    required this.sheetLabel,
    required this.title,
    this.studentName = '',
    this.professorId,
    this.active = true,
    this.validUntil,
    this.exercises = const [],
  });

  final String id;
  final String studentId;
  final String studentName;
  final String? professorId;
  final String sheetLabel;
  final String title;
  final bool active;
  final DateTime? validUntil;
  final List<PlanExerciseItem> exercises;

  factory InstructorWorkoutPlan.fromJson(Map<String, dynamic> j) {
    final exercises =
        ((j['exercises'] as List?) ?? const [])
            .map((e) => PlanExerciseItem.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.ordem.compareTo(b.ordem));
    return InstructorWorkoutPlan(
      id: j['id'].toString(),
      studentId: (j['studentId'] as String?) ?? '',
      studentName: (j['studentName'] as String?) ?? '',
      professorId: j['professorId'] as String?,
      sheetLabel: (j['sheetLabel'] as String?) ?? 'A',
      title: (j['title'] as String?) ?? '',
      active: (j['active'] as bool?) ?? true,
      validUntil: DateTime.tryParse((j['validUntil'] as String?) ?? ''),
      exercises: exercises,
    );
  }
}

/// Corpo de criação/edição de ficha (`POST`/`PUT /workout-plans`).
class WorkoutPlanPayload {
  const WorkoutPlanPayload({
    required this.studentId,
    required this.sheetLabel,
    required this.title,
    required this.active,
    required this.exercises,
    this.validUntil,
  });

  final String studentId;
  final String sheetLabel;
  final String title;
  final bool active;
  final DateTime? validUntil;

  /// A ordem dos exercícios na ficha é a ordem desta lista.
  final List<PlanExerciseItem> exercises;

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'sheetLabel': sheetLabel,
    'title': title,
    'active': active,
    'validUntil': validUntil == null ? null : isoDate(validUntil!),
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}

/// Exercício do catálogo (`GET /exercises`).
class CatalogExercise {
  const CatalogExercise({
    required this.id,
    required this.name,
    this.muscleGroup,
    this.equipment,
    this.arquivado = false,
  });

  final String id;
  final String name;
  final String? muscleGroup;
  final String? equipment;
  final bool arquivado;

  factory CatalogExercise.fromJson(Map<String, dynamic> j) => CatalogExercise(
    id: j['id'].toString(),
    name: (j['name'] as String?) ?? '',
    muscleGroup: _textoOuNull(j['muscleGroup']),
    equipment: _textoOuNull(j['equipment']),
    arquivado: (j['arquivado'] as bool?) ?? false,
  );
}

String? _textoOuNull(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// `YYYY-MM-DD` (formato de `LocalDate` do backend).
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Acesso REST do perfil Instrutor (papel `professor` no backend): lista de
/// alunos, fichas de treino e catálogo de exercícios.
class InstructorApi {
  InstructorApi(this._api);

  final ApiClient _api;

  /// Tamanho de página da lista de alunos.
  static const pageSize = 20;

  /// Alunos da academia, por nome ou CPF. `perfil=aluno` tira os próprios
  /// instrutores da lista (eles também têm cadastro em `/students`).
  Future<StudentsPage> students({String? q, int page = 0}) async {
    final termo = q?.trim() ?? '';
    final params = <String, String>{
      if (termo.isNotEmpty) 'q': termo,
      'page': '$page',
      'size': '$pageSize',
      'perfil': 'aluno',
    };
    final data = await _api.get('/students?${_query(params)}');
    return StudentsPage.fromJson(data as Map<String, dynamic>);
  }

  Future<List<InstructorWorkoutPlan>> studentPlans(String studentId) async {
    final data = await _api.get(
      '/students/${Uri.encodeComponent(studentId)}/workout-plans',
    );
    return ((data as List?) ?? const [])
        .map((e) => InstructorWorkoutPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<InstructorWorkoutPlan> createPlan(WorkoutPlanPayload payload) async {
    final data = await _api.post('/workout-plans', body: payload.toJson());
    return InstructorWorkoutPlan.fromJson(data as Map<String, dynamic>);
  }

  Future<InstructorWorkoutPlan> updatePlan(
    String planId,
    WorkoutPlanPayload payload,
  ) async {
    final data = await _api.put(
      '/workout-plans/${Uri.encodeComponent(planId)}',
      body: payload.toJson(),
    );
    return InstructorWorkoutPlan.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deletePlan(String planId) =>
      _api.delete('/workout-plans/${Uri.encodeComponent(planId)}');

  /// Catálogo de exercícios, sem os arquivados.
  Future<List<CatalogExercise>> exercises({String? q, String? grupo}) async {
    final termo = q?.trim() ?? '';
    final g = grupo?.trim() ?? '';
    final params = <String, String>{
      if (termo.isNotEmpty) 'q': termo,
      if (g.isNotEmpty) 'grupo': g,
    };
    final path = params.isEmpty ? '/exercises' : '/exercises?${_query(params)}';
    final data = await _api.get(path);
    return ((data as List?) ?? const [])
        .map((e) => CatalogExercise.fromJson(e as Map<String, dynamic>))
        .where((e) => !e.arquivado)
        .toList();
  }

  /// Query string com valores URL-encoded (nome/CPF têm espaço, acento, ponto).
  static String _query(Map<String, String> params) => params.entries
      .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');
}

final instructorApiProvider = Provider<InstructorApi>(
  (ref) => InstructorApi(ref.watch(apiClientProvider)),
);
