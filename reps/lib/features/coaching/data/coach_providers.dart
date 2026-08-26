import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/coach_models.dart';
import 'coach_repository.dart';

final coachRepositoryProvider = Provider<CoachRepository>(
  (ref) => CoachRepository.instance,
);

/// Alunos ativos do professor logado (online).
final meusAlunosProvider = FutureProvider.autoDispose<List<VinculoAluno>>(
  (ref) => ref.watch(coachRepositoryProvider).meusAlunos(),
);

/// Treinadores ativos do aluno logado (online).
final meusTreinadoresProvider =
    FutureProvider.autoDispose<List<VinculoTreinador>>(
      (ref) => ref.watch(coachRepositoryProvider).meusTreinadores(),
    );

/// Treinos que o professor atribuiu a um aluno (online), por alunoId.
final rotinasAtribuidasProvider = FutureProvider.autoDispose
    .family<List<RotinaAtribuida>, String>(
      (ref, alunoId) =>
          ref.watch(coachRepositoryProvider).rotinasAtribuidas(alunoId),
    );

/// Evolucao (30d) de um aluno, por alunoId.
final evolucaoAlunoProvider = FutureProvider.autoDispose
    .family<EvolucaoAluno, String>(
      (ref, alunoId) =>
          ref.watch(coachRepositoryProvider).evolucaoAluno(alunoId),
    );

/// Academias que o usuario logado ve (dono ou membro).
final minhasOrgsProvider = FutureProvider.autoDispose<List<Organizacao>>(
  (ref) => ref.watch(coachRepositoryProvider).minhasOrgs(),
);

/// Membros (professores) de uma academia, por orgId.
final membrosOrgProvider = FutureProvider.autoDispose
    .family<List<MembroOrg>, String>(
      (ref, orgId) => ref.watch(coachRepositoryProvider).membrosDaOrg(orgId),
    );
