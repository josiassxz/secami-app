# Instruções de projeto – reps

Este arquivo orienta Claude Code ao trabalhar neste repositório.

## Contexto

**reps** é um app mobile (Flutter) de gerenciamento de treinos. Fonte canônica do escopo: [Workout_Tracker_MVP_Documentacao.docx](Workout_Tracker_MVP_Documentacao.docx) e o conjunto de docs em [docs/](docs/).

Stack obrigatória (decisão fechada no doc de MVP):
- **Front-end**: Flutter (Dart) – iOS, Android e web do mesmo código.
- **Banco local**: Drift (SQLite reativo).
- **Backend**: Supabase – PostgreSQL gerenciado, Auth, Row-Level Security. **Storage não é usado no MVP** (GIFs ficam como assets locais).
- **Analytics**: PostHog (opcional no dev — sem `POSTHOG_API_KEY` o SDK vira no-op).
- **Crash reporting**: Sentry (opcional no dev — sem `SENTRY_DSN` o SDK vira no-op).

## Princípios não negociáveis

1. **Local-first.** Toda operação funciona offline. Sync com Supabase é assíncrono e nunca bloqueia UI.
2. **Atrito zero na execução.** No modo treino, registrar uma série leva no máximo 2 toques. Botões ≥ 48pt, contraste alto.
3. **Sem features sociais.** Nada de feed, curtidas, comentários. O produto compete com planilha de Excel, não com Strava.
4. **Dado é dono.** Exportação CSV/JSON em qualquer momento, sem paywall.
5. **Português pt-BR.** Toda string visível ao usuário é em pt-BR. Nomes de campos em código também (`carga_kg`, `series_planejadas`).

## Estilo de código

- Dart formatado com `dart format` (linha 80 colunas).
- Lints: `flutter_lints` + regras adicionais em `analysis_options.yaml`.
- Arquitetura: **feature-first**. Cada feature em `lib/features/<nome>/` com `data/`, `domain/`, `presentation/`.
- **Regra de domain (onde mora um modelo/entidade):** usado por **2+ features** → `lib/domain/` (compartilhado); usado por **1 feature** → `lib/features/<nome>/domain/`. Ex.: `exercise.dart` vive em `lib/domain/entities/` (consumido por library/recommender/workout). Evita import cruzado entre features.
- State management: **Riverpod** (decisão padrão para Flutter moderno, sem code-gen pesado).
- Nomes de tabelas e colunas no Postgres em `snake_case` e em português (espelham o modelo de dados em [docs/03-data-model.md](docs/03-data-model.md)).
- Migrações de banco vivem em [supabase/migrations/](supabase/migrations/) (após scaffold).

## Como avançar trabalho

A construção do MVP está fatiada em 3 etapas (ver [docs/01-roadmap.md](docs/01-roadmap.md)):

1. **Fase 1 – Alicerce** ([docs/stages/stage-01-foundation.md](docs/stages/stage-01-foundation.md))
2. **Fase 2 – O motor** ([docs/stages/stage-02-engine.md](docs/stages/stage-02-engine.md))
3. **Fase 3 – Inteligência** ([docs/stages/stage-03-intelligence.md](docs/stages/stage-03-intelligence.md))

Cada arquivo de etapa lista entregáveis verificáveis. **Não pule etapas.** Não comece a Fase 2 sem todos os critérios de aceite da Fase 1 marcados como ✅.

Para execução autônoma, prompts encadeados estão em [prompts/](prompts/). O script [scripts/run-autonomous.ps1](scripts/run-autonomous.ps1) invoca Claude Code em sequência sobre cada prompt.

## Decisões já tomadas (não reabrir sem pedido explícito)

- Stack = Flutter + Supabase + Drift + Riverpod (não trocar por React Native, Next.js, Firebase etc.).
- Idioma da UI = pt-BR única (sem i18n no MVP).
- Sem login obrigatório no primeiro uso → modo convidado é o padrão.
- **Auth no MVP = somente e-mail/senha.** Login social (Google/Apple) adiado para V1.1.
- **GIFs ficam em `assets/exercises/<slug>.gif`** (assets locais). Sem bucket Storage no MVP. Coluna `gif_url` na tabela `exercises` armazena o slug, não URL.
- Sem features sociais.
- Unidade padrão = kg (lb configurável em preferências).

## Convenções de commit

`<tipo>: <descrição curta em pt-BR>` onde tipo ∈ {feat, fix, chore, refactor, docs, test, ci}.

## Quando estiver na dúvida

Releia o doc de origem ([Workout_Tracker_MVP_Documentacao.docx](Workout_Tracker_MVP_Documentacao.docx)). Em conflito entre `.docx` e o conjunto `docs/`, o `.docx` vence — `docs/` é derivado dele.
