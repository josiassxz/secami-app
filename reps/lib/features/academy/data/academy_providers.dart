import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import 'academy_api.dart';

/// Data selecionada na tela de agenda (aluno). Estado local simples.
final agendaSelectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final availableSlotsProvider = FutureProvider.autoDispose<List<AvailableSlot>>((
  ref,
) {
  final date = ref.watch(agendaSelectedDateProvider);
  return ref.watch(academyApiProvider).availableSlots(_iso(date));
});

final myAppointmentsProvider =
    FutureProvider.autoDispose<List<ScheduledAppointment>>((ref) {
      return ref.watch(academyApiProvider).myAppointments();
    });

final myWorkoutPlansProvider = FutureProvider.autoDispose<List<WorkoutPlanDto>>(
  (ref) {
    return ref.watch(academyApiProvider).myWorkoutPlans();
  },
);

final noticesProvider = FutureProvider.autoDispose<List<NoticeDto>>((ref) {
  return ref.watch(academyApiProvider).notices();
});

final myProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) {
  return ref.watch(academyApiProvider).myProfile();
});

/// Punições em aberto do aluno de Lutas (`GET /me/punicoes`).
final minhasPunicoesProvider = FutureProvider.autoDispose<List<Punicao>>((
  ref,
) async {
  if (!Env.hasRestApi) return const [];
  return ref.watch(academyApiProvider).meusPunicoes();
});

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
