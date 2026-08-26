# Stage 5 – Recomendador de Treinos (pós-MVP / V1.x)

> **Status:** plano de trabalho. Não faz parte do MVP (Fases 1–3).
> **Pré-requisito:** Fases 1–3 com critérios de aceite ✅.
> **Fonte canônica:** `regras_de_negocio_recomendador_de_treinos.pdf` (RN-001..052,
> RF-001..012, RNF-001..006, CA-001..008). Em conflito, o PDF vence.
> **Decisões de escopo já tomadas (não reabrir sem pedido):**
> escopo v1 = **E0–E5 completo**; **triagem PAR-Q+ entra na v1**;
> dados de saúde = **local (Drift) + Supabase com consentimento explícito**.

## ⚠️ Aviso de responsabilidade (não negociável)

O recomendador é **uso informativo** e **não substitui** avaliação de
profissional de Educação Física ou de saúde (RN-004). Toda saída leva
disclaimer. Para qualquer alerta de saúde, o sistema **encaminha** — nunca
prescreve treino intenso automaticamente (RN-002/003). A Observação final do
PDF exige **revisão por profissional de Educação Física** das regras de volume,
intensidade, progressão, contraindicações e substituição **antes de produção**.

## Objetivo de saída

Usuário responde um questionário (curto ou completo) e recebe uma rotina de
treino montada por motor de regras — divisão semanal, exercícios, séries/reps/
descanso, justificativa e alertas — e pode **salvá-la como rotina(s)** no app.

Coexistem **três** caminhos de criação de rotina:
1. `USAR MODELO` — templates estáticos atuais ([templates_service.dart](../../lib/features/routines/data/templates_service.dart)). **Mantido como está.**
2. `ANÁLISE SIMPLIFICADA` — poucas perguntas (objetivo, dias, local/equip) → treino rápido.
3. `ANÁLISE COMPLETA` — questionário + triagem PAR-Q+ + limitações + preferências → recomendação justificada com alertas.

Análises 2 e 3 usam o **mesmo motor**; diferem só na profundidade do input.

---

## 1. Arquitetura

Feature nova: `lib/features/recommender/` (feature-first: `data/`, `domain/`,
`presentation/`). O **motor** vive em `lib/domain/usecases/` (Dart puro, sem
Flutter, 100% testável), espelhando o padrão de [progression_engine.dart](../../lib/domain/usecases/progression_engine.dart).

Reuso obrigatório (não reimplementar):
- `LibraryRepository` — fonte de exercícios + filtro por grupo/padrão/equip.
- `RoutineService.create/addExercise` — persistência da rotina gerada (mesmo
  caminho de `TemplatesService.apply`).
- `ProgressionEngine` — progressão de carga (RN-038/039) no E4.
- `SubstituteSheet` — substituição por padrão+grupo (RN-035) já existente.
- Pattern de consentimento LGPD da coaching — para dado de saúde (E5).

Ponto de entrada na UI: tela de Routines / "Nova rotina" ganha os 3 botões.

---

## E0 — Metadados de exercício (fundação; bloqueia E2/E3)

Sem isso o motor não filtra por nível nem ordena multiarticular→isolador.
Cobre RN-032/033/036; CA-007 (desativar exercício).

### Recorte decidido (não reabrir)

- **Motor recomenda só os 100 canônicos** (`exercisesSeed`). Bem curados,
  pt-BR correto, cobrem todos os grupos e padrões → classificáveis e revisáveis
  à mão num esforço viável.
- **Os 231 do `exercises_extended.json` ficam fora da recomendação automática.**
  Continuam na biblioteca para **busca e substituição manual** (nomes
  auto-traduzidos e `padrao` defaultado os tornam ruins para prescrição).
  Marcar com flag `recomendavel = false` (ou filtrar por namespace `seed:` no
  motor) para que `ExerciseSelector` os ignore.
- **`instrucoes`/`alertas` de doc externo (ACE/NASM/MuscleWiki) ficam para fase
  posterior.** Não bloqueiam o motor (são só display, RN-037). Strings curtas já
  existentes em `descricao` servem de placeholder na v1.

### Campos a adicionar em `Exercise` ([exercise.dart](../../lib/features/library/domain/exercise.dart)) e `SeedRow`

- `nivelTecnico` — enum `iniciante | intermediario | avancado`. **Falta em 100%.**
  Classificar os 100 por heurística + revisão:
  máquina/peso corporal → iniciante; barra composta → intermediário;
  terra pesado/olímpico/pliometria → avançado (RN-036).
- `tipo` — enum `multiarticular | isolador | mobilidade | cardio`.
  **Multi vs isolador deriva de `padraoMovimento != isolador` (em código, sem
  trabalho manual).** Só marcar à mão os poucos `mobilidade`/`cardio`.
- `recomendavel` — `bool` (default `false` nos extended; `true` nos 100).
- `ativo` — `bool` (RN-048 / CA-007).
- `restricoes` — `List<String>` (opcional na v1; preencher nos exercícios de
  maior risco). `substituicoes` já coberto por SubstituteSheet via padrão+grupo.

### Tarefas

- [ ] Add campos ao `Exercise` + `SeedRow` + parser do extended (default
      `recomendavel:false`, `nivelTecnico:iniciante`, `tipo` derivado).
- [ ] Classificar `nivelTecnico` dos **100** canônicos (manual, ~1 passada).
- [ ] Marcar `tipo` mobilidade/cardio onde aplicável (resto derivado).
- [ ] `ExerciseSelector` (E2) filtra `recomendavel == true`.
- [x] ~~Migration `0005_*`~~ **adiada**: motor roda local sobre `exercisesSeed`
      em memória; `nivelTecnico` é derivado em código (não armazenado) e
      extended/custom já são `recomendavel:false` por default. Coluna no
      Supabase só será necessária se quisermos sincronizar/recomendar custom.

**Status: ✅ feito** (commit pendente). Entregue:
- `Exercise` ganhou `nivelTecnico`, `recomendavel`, `ativo` + getter `tipo`
  ([exercise.dart](../../lib/features/library/domain/exercise.dart)).
- Classificador heurístico revisável
  ([exercise_classifier.dart](../../lib/features/library/domain/exercise_classifier.dart)).
- Seed marcado `recomendavel:true` + nível classificado
  ([library_repository.dart](../../lib/features/library/data/library_repository.dart)).
- Testes ([exercise_classifier_test.dart](../../test/exercise_classifier_test.dart)) 6/6.

**Distribuição dos 100:** 65 iniciante · 27 intermediário · 8 avançado.

**Aceite E0:** os 100 canônicos têm `nivelTecnico` e `tipo` preenchidos e
`recomendavel = true`; extended/custom ficam `recomendavel = false`; busca/filtros
da biblioteca seguem passando; `flutter analyze` 0 issues. ✅

---

## E1 — Questionário + triagem de segurança

RF-002/003; RN-001/005/007; seção 6 do PDF; RNF-001 (progressivo, linguagem
acessível).

- Models (`domain/`): `PerfilQuestionario` e `RespostasTriagem`.
  - Perfil: idade (obrig.), objetivo principal **único** (RN-008) + secundários,
    prioridade muscular (RN-009), nível, dias/semana, tempo/sessão, local,
    equipamentos. Sexo/peso/altura **opcionais** (não obrigatórios — seção 6).
  - Triagem: PAR-Q+ simplificado (coração, pressão, dor no peito, tontura,
    equilíbrio, doença crônica, medicamentos, lesões/restrições).
- Fluxo `presentation/`: wizard progressivo.
  - **Simplificada** = subset mínimo (RN-007: objetivo, dias, tempo, local/equip,
    restrições) — sem PAR-Q+ completo, mas com pergunta-gatilho de segurança.
  - **Completa** = perfil cheio + PAR-Q+ + limitações + preferências + recuperação.
- Validação RN-007: não habilita "gerar" sem campos mínimos.
- Re-triagem (RN-005): refazer ao mudar saúde, registrar dor/lesão ou inatividade.

**Aceite E1:** ambos os fluxos coletam e validam campos; CA-003 (treino em casa
sem equipamento restringe seleção).

---

## E2 — Motor de regras (núcleo)

`lib/domain/usecases/recommender/`, Dart puro, **versionado** (RN-052). Pipeline
espelha a seção 13 do PDF (fluxo macro).

1. `SafetyGate` (RN-001/002/003) — **mais crítico.** Alerta positivo →
   bloqueia treino intenso/avançado/alta carga e retorna encaminhamento
   profissional. CA-002.
2. `ProfileClassifier` (RN-013 conservador em dúvida; RN-014/017 retorno após
   pausa = tratar como iniciante/intermediário conservador).
3. `SplitSelector` — matriz da seção 8 (RN-018..023): 2d→FB A/B; 3d→FB A/B/C
   ou Sup/Inf/Full; 4d→Upper/Lower 2x; 5d→U/L+ponto fraco ou PPL adaptado;
   6d→PPL 2x. Limite por sessão (RN-023, RN-010): respeita tempo declarado.
4. `ExerciseSelector` — filtra por equip (RN-011/034), restrições e preferências
   (RN-012); ordena multiarticular→isolador (RN-033); prioridade muscular sem
   zerar demais grupos (RN-009/024); CA-004/CA-005.
5. `Prescriber` — séries/reps/descanso por objetivo (RN-024..031):
   ~10 séries/sem por grupo p/ hipertrofia (RN-026); força = composto/carga
   alta/reps baixas/descanso maior (RN-027); reps em reserva, sem falha p/
   iniciante (RN-030); descanso por objetivo (RN-031). Regras por objetivo =
   seção 9.8.

**Aceite E2:** suíte de testes cobrindo CA-001..006; matriz de divisão 2–6 dias;
SafetyGate bloqueia em todas as condições do RN-002.

---

## E3 — Saída + apresentação

RF-007; RN-043..047.

- Tela de resultado: divisão semanal, dias sugeridos, exercícios, séries/reps/
  descanso, observações, substituições (RN-043).
- Justificativa da escolha usando objetivo+frequência+nível+prioridade (RN-044).
- Linguagem simples, sem jargão sem explicação (RN-045).
- Alertas **antes** do treino e **nos exercícios afetados** (RN-046).
- Disclaimer de responsabilidade exibido antes do treino (RN-004).
- Botão `SALVAR COMO ROTINA(S)` → `RoutineService.create/addExercise`
  (reusa caminho do `TemplatesService.apply`).
- "Gerar outro" varia exercícios preservando volume/padrão/objetivo (RN-047).

**Aceite E3:** treino gerado é salvável como rotina(s) e abre no fluxo de
execução existente; alertas aparecem nos dois lugares.

---

## E4 — Feedback + ajuste

RF-009/010; RN-038..042. Reusa `ProgressionEngine` + histórico já existentes.

- Pós-treino: registra carga/reps/conclusão/PSE (RN-042 — já parcialmente coberto).
- Redução por fadiga (RN-040): dor persistente/sono ruim/queda de performance →
  reduz volume/intensidade/complexidade temporariamente. CA-006.
- Revisão periódica (RN-041): sugerir revisar a cada 4–8 semanas ou ao registrar
  dor/estagnação/mudança de objetivo/disponibilidade.
- Dor durante exercício (RN-006): interromper + registrar + oferecer substituição
  segura só se não houver alerta clínico grave.

**Aceite E4:** fadiga reportada dispara recomendação de redução (CA-006).

---

## E5 — Conformidade, auditoria e dados de saúde

RN-050/051/052; RNF-002/003.

- **Rastreabilidade** (RN-050/RNF-003): persistir, por treino gerado, a versão
  do motor + entradas principais + regras aplicadas. CA-008.
- **Versionamento das regras** (RN-052): motor carrega `versao` constante;
  mudanças bumpam versão.
- **Dados de saúde sensíveis** (RN-051): triagem/limitações são **dado sensível**.
  - Local-first: gravam em Drift primeiro.
  - Sync Supabase **só com consentimento explícito** (reusa pattern LGPD da
    coaching). Migration com RLS própria. Sem consentimento → fica só no device.
  - **Atenção:** revisar a memória `stage-04-coaching` — sync de dado de aluno
    para o Drift do professor é proibido; não misturar escopos.

**Aceite E5:** treino auditável mostra versão+entradas+critérios (CA-008);
dado de saúde só sobe ao backend após consentimento.

---

## Admin (RN-048/049; RF-011) — transversal

- Gestão de biblioteca já existe parcialmente (custom exercises). Estender para
  desativar/classificar (CA-007 mantém histórico antigo).
- Gestão de templates de treino por objetivo/nível/frequência (RN-049) — pode
  reusar a estrutura de `templates.json`.

---

## Critérios de aceite (gate do stage)

- [ ] `flutter analyze` 0 issues; suíte de testes do motor verde.
- [x] CA-001: 3d/sem, iniciante, hipertrofia → FB A/B/C, volume moderado. *(teste)*
- [x] CA-002: condição cardíaca → não gera treino intenso, mostra encaminhamento. *(teste)*
- [x] CA-003: casa sem equip → só peso corporal/elástico se informados. *(teste)*
- [x] CA-004: prioridade pernas/glúteos → mais volume inferior sem zerar superiores. *(teste)*
- [x] CA-005: rejeitar exercício → substituição equivalente quando existir. *(teste)*
- [x] CA-006: fadiga alta → redução temporária de volume/intensidade. *(teste)*
- [~] CA-007: motor já filtra `ativo`/`recomendavel`; custom têm `archive`.
      Painel admin de toggle = **BL-003 (backlog do PDF)**, fora da v1.
- [x] CA-008: treino auditado → versão da regra + entradas + critérios (`RecommenderRuns`).
- [x] Disclaimer (RN-004) e alertas (RN-046) presentes em toda saída.
- [x] Dado de saúde só **persiste e sincroniza** com consentimento (RN-051).
      Sync push-only no `SyncEngine` envia só runs com `sincronizavel=true`
      (snapshot do consentimento na geração); tabela + RLS em `0005`.
- [ ] Regras de volume/intensidade/progressão revisadas por profissional de Ed.
      Física antes de produção (Observação final do PDF). **Pendente — gate de produção.**

## Status de implementação (v1)

| Etapa | Status | Onde |
|-------|--------|------|
| E0 metadados | ✅ | `library/domain/exercise*.dart` |
| E1 modelos + questionário | ✅ | `recommender/domain/*.dart`, `presentation/questionario_screen.dart` |
| E2 motor | ✅ 11 testes | `recommender/domain/engine/` |
| E3 saída + salvar rotina | ✅ | `presentation/resultado_treino_screen.dart`, `data/recommender_providers.dart` |
| E4 fadiga (RN-040) | ✅ | motor + toggle no questionário |
| E5 auditoria + consent local | ✅ | `RecommenderRuns` (Drift) + `recommender_consent.dart` |
| E5 sync Supabase | ✅ | push gated por `sincronizavel` no `SyncEngine` (push-only) |
| Admin (RF-011) | ⏭️ backlog | BL-003 |
| `instrucoes`/`alertas` por exercício (RN-037) | ⏭️ fase 2 | doc externo (ACE/NASM/MuscleWiki) |

Suite: **69 testes verdes**, `flutter analyze` 0 issues no código novo.

## Ordem de execução sugerida

`E0 → E1 → E2 → E3` (caminho feliz utilizável) → `E5` (conformidade) → `E4`
(feedback). SafetyGate (parte do E2) deve vir **antes** de qualquer geração real.
