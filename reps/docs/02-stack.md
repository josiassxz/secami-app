# 02 – Stack técnica

Decisão otimizada para time pequeno (1–3 pessoas) que precisa entregar iOS + Android + (idealmente) web sem triplicar o esforço.

## Stack canônica

| Camada | Escolha | Por quê |
|---|---|---|
| Front-end mobile + web | **Flutter (Dart)** | Single codebase iOS/Android/web, performance nativa, animações sólidas |
| State management | **Riverpod** | Sem code-gen pesado, testável, comunidade ativa |
| Banco local | **Drift** (SQLite reativo) | Queries SQL com type-safety, reativo, suporta migrações |
| Backend | **Supabase** | Postgres gerenciado + Auth + RLS prontos; elimina semanas de boilerplate |
| Auth | **Supabase Auth** | E-mail/senha no MVP. Login social (Google/Apple) adiado para V1.1 |
| GIFs de exercícios | **Assets locais** (`assets/exercises/*.gif`) | MVP empacota os 100 GIFs no app. Sem bucket, sem CDN. Custo: app ~20MB. Migrar para Storage só quando precisar atualizar biblioteca sem release |
| Analytics | **PostHog** (opcional no dev) | Open-source. Variável vazia no `.env` → SDK vira no-op |
| Crash reporting | **Sentry** (opcional no dev) | Free tier generoso. Variável vazia no `.env` → SDK vira no-op |
| CI/CD | **GitHub Actions** | Free tier suficiente; build de Android e iOS via runners |

## Alternativas consideradas e descartadas

| Alternativa | Por que descartada |
|---|---|
| React Native + Expo | Time não tem expertise React; Flutter entrega melhor performance em listas longas e animações |
| Firebase | Lock-in maior, custo cresce mais rápido, sem SQL puro |
| Node + Postgres em VPS | Devops desnecessário para MVP |
| Isar / Realm | Menos maduras que Drift no ecossistema Flutter |
| Provider / BLoC | Riverpod resolve os mesmos problemas com menos código |

## Dependências pubspec (versões aproximadas, ajustar no scaffold)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.0
  drift: ^2.18.0
  drift_flutter: ^0.2.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  supabase_flutter: ^2.5.0
  go_router: ^14.0.0
  fl_chart: ^0.68.0          # gráficos de progressão
  cached_network_image: ^3.3.0
  vibration: ^2.0.0          # timer com feedback tátil
  audioplayers: ^6.0.0       # bipe do timer
  posthog_flutter: ^4.0.0
  sentry_flutter: ^8.0.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0
  intl: ^0.19.0
  uuid: ^4.0.0
  share_plus: ^9.0.0         # exportação CSV/JSON
  csv: ^6.0.0

dev_dependencies:
  flutter_lints: ^4.0.0
  build_runner: ^2.4.0
  drift_dev: ^2.18.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  mocktail: ^1.0.0
```

## Estrutura de pastas (após scaffold)

```
lib/
  main.dart
  app.dart                  # MaterialApp + go_router
  core/
    theme/
    config/                 # env, constantes
    logging/                # sentry/posthog setup
    sync/                   # motor local-first
  data/
    local/                  # drift database + DAOs
    remote/                 # Supabase client + endpoints
    repositories/
  domain/
    entities/               # modelos (freezed)
    usecases/
  features/
    auth/
    library/                # biblioteca de exercícios
    routines/               # construtor de treinos
    workout/                # modo execução
    history/
    cardio/
    settings/
    onboarding/
  shared/
    widgets/                # botões grandes, timer, etc.
    formatters/

assets/
  exercises/                # 100 GIFs (≤ 200kb cada), nome = slug do exercício
  templates/                # templates.json (PPL, U/L, Full Body)
  sounds/                   # bipes do timer
  icon/                     # ícone do app
  legal/                    # privacidade.md
```

## Setup de Supabase

1. Criar projeto em [supabase.com](https://supabase.com) (free tier).
2. Anotar `SUPABASE_URL` e `SUPABASE_ANON_KEY` em `.env` (gitignored).
3. Aplicar migrações de `supabase/migrations/` (criadas pelo Claude durante Stage 1) via SQL Editor do console ou Supabase CLI.
4. RLS e policies já vêm nas migrações.

**Storage não é usado no MVP** — os GIFs ficam empacotados como assets do app. Criar bucket `exercise-gifs` é tarefa de V1.1, quando quiser permitir atualização de biblioteca sem release.

## Custo no MVP

Free tier de Supabase cobre até ~50k MAU. Sentry free tier: 5k erros/mês. PostHog cloud free: 1M eventos/mês. Storage não é usado (GIFs locais). **Custo inicial efetivo: R$ 0.**
