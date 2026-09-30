// Fake em memória de InstructorApi para os widget tests do perfil Instrutor —
// sem rede: registra as chamadas e devolve o que o teste configurar.

import 'package:reps/features/instructor/data/instructor_api.dart';

class FakeInstructorApi implements InstructorApi {
  // ---- alunos ----

  /// Chamadas a [students], na ordem.
  final List<({String? q, int page})> studentCalls = [];

  /// Resposta por chamada; padrão = página única com [alunos].
  Future<StudentsPage> Function(String? q, int page)? onStudents;
  List<StudentSummary> alunos = const [];

  // ---- fichas ----

  List<InstructorWorkoutPlan> plans = [];
  Object? plansError;
  int studentPlansCalls = 0;

  final List<WorkoutPlanPayload> created = [];
  final List<({String id, WorkoutPlanPayload payload})> updated = [];
  final List<String> deleted = [];

  /// Se definido, `createPlan`/`updatePlan` só terminam depois deste future
  /// (pra testar o estado "salvando").
  Future<void>? saveGate;
  Object? saveError;
  Object? deleteError;

  // ---- catálogo ----

  List<CatalogExercise> catalog = const [];
  Object? catalogError;

  @override
  Future<StudentsPage> students({String? q, int page = 0}) {
    studentCalls.add((q: q, page: page));
    final custom = onStudents;
    if (custom != null) return custom(q, page);
    return Future.value(
      StudentsPage(content: alunos, totalElements: alunos.length),
    );
  }

  @override
  Future<List<InstructorWorkoutPlan>> studentPlans(String studentId) async {
    studentPlansCalls++;
    final erro = plansError;
    if (erro != null) throw erro;
    return List.of(plans);
  }

  @override
  Future<InstructorWorkoutPlan> createPlan(WorkoutPlanPayload payload) async {
    created.add(payload);
    await saveGate;
    final erro = saveError;
    if (erro != null) throw erro;
    final plan = _planFrom('novo-${created.length}', payload);
    plans = [...plans, plan];
    return plan;
  }

  @override
  Future<InstructorWorkoutPlan> updatePlan(
    String planId,
    WorkoutPlanPayload payload,
  ) async {
    updated.add((id: planId, payload: payload));
    await saveGate;
    final erro = saveError;
    if (erro != null) throw erro;
    final plan = _planFrom(planId, payload);
    plans = [
      for (final p in plans)
        if (p.id == planId) plan else p,
    ];
    return plan;
  }

  @override
  Future<void> deletePlan(String planId) async {
    deleted.add(planId);
    final erro = deleteError;
    if (erro != null) throw erro;
    plans = plans.where((p) => p.id != planId).toList();
  }

  @override
  Future<List<CatalogExercise>> exercises({String? q, String? grupo}) async {
    final erro = catalogError;
    if (erro != null) throw erro;
    return catalog;
  }

  InstructorWorkoutPlan _planFrom(String id, WorkoutPlanPayload p) =>
      InstructorWorkoutPlan(
        id: id,
        studentId: p.studentId,
        sheetLabel: p.sheetLabel,
        title: p.title,
        active: p.active,
        validUntil: p.validUntil,
        exercises: p.exercises,
      );
}
