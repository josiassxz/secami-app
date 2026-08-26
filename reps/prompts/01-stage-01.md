# Prompt – Stage 1 (Alicerce)

Você está trabalhando no projeto **reps** em `c:\Users\Josias\Documents\reps`. Leia primeiro:
- `CLAUDE.md`
- `docs/02-stack.md`
- `docs/03-data-model.md`
- `docs/stages/stage-01-foundation.md`

Sua tarefa é entregar **todos** os itens E1.1 a E1.7 do `docs/stages/stage-01-foundation.md`, marcando os checkboxes do arquivo conforme avança.

## Regras

1. Siga o protocolo em `prompts/00-prompt-protocol.md`.
2. Decisões já tomadas no `CLAUDE.md` — não reabrir.
3. Não pedir aprovação. Tome decisões técnicas e implemente.
4. Após cada entregável, rodar `dart format .`, `flutter analyze`, `flutter test`, e fazer commit `feat(stage-1): E1.X – <descrição>`.

## Ordem sugerida de execução

1. **E1.1 – Scaffold Flutter**
   - `flutter create reps_app --org com.reps.app --platforms ios,android,web` na raiz do projeto
   - Reorganizar `lib/` conforme estrutura em `docs/02-stack.md`
   - Adicionar deps do pubspec
   - Configurar `analysis_options.yaml` estrito
   - `.gitignore` com `.env`, `*.g.dart`, `*.freezed.dart`, `build/`, `.dart_tool/`
   - `git init` (se ainda não estiver) e commit inicial

2. **E1.2 – Schema Supabase**
   - Criar `supabase/migrations/0001_init.sql` com as 7 tabelas de `docs/03-data-model.md`
   - Triggers de `updated_at`
   - Row-Level Security em todas as tabelas
   - Índices listados no doc da etapa
   - Documentar em `supabase/README.md` como aplicar via Supabase CLI
   - 🛑 HUMAN STEP: aplicar no projeto Supabase real (instruções no README)

3. **E1.3 – Auth (e-mail/senha + convidado)**
   - Inicializar cliente Supabase em `lib/core/config/supabase_client.dart` lendo `.env`
   - Telas em `lib/features/auth/presentation/`: splash, welcome, sign_up, sign_in, forgot_password
   - Riverpod providers para sessão e usuário corrente
   - Modo convidado: gerar `user_id` local com `uuid v4`, persistir em `shared_preferences`
   - Tela de exclusão de conta com confirmação dupla
   - **MVP: somente e-mail/senha. Não implementar Google/Apple sign-in** (adiado para V1.1)

4. **E1.4 – Biblioteca de exercícios**
   - `lib/features/library/` com tela, busca debounce 300ms, filtros multi-select
   - Repository que lê metadados de Supabase (Stage 2 adiciona cache Drift)
   - GIFs vêm de **asset local**: `AssetImage('assets/exercises/${slug}.gif')`
   - Modal de detalhes com GIF maior

5. **E1.5 – Curadoria 100 exercícios (GIFs locais)**
   - Criar `content/exercises-seed.csv` com 100 linhas, colunas: `slug, nome, descricao, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento`
   - Lista canônica cobrindo todos os grupos musculares e padrões de movimento
   - Criar pasta `assets/exercises/` e adicionar entry no `pubspec.yaml` (`flutter: assets: - assets/exercises/`)
   - Para o MVP, **gerar 100 placeholders** `.gif` (ex.: copiar um GIF dummy 1×1 transparente para cada slug) — o usuário substitui os GIFs reais depois sem mudar código
   - Gerar `supabase/seeds/exercises.sql` a partir do CSV (script Dart em `tool/seed_exercises.dart`) — campo `gif_url` recebe o **slug** (não URL)
   - Não usar bucket Storage neste MVP

6. **E1.6 – Observabilidade (opcional, no-op se chaves vazias)**
   - `lib/core/logging/observability.dart` com wrappers `captureError()` e `track(event, props)`
   - Sentry: inicializar **só se** `SENTRY_DSN` está preenchido no `.env`. Vazio → no-op.
   - PostHog: inicializar **só se** `POSTHOG_API_KEY` está preenchido. Vazio → no-op.
   - Evento `app_open` no splash (via wrapper — funciona com ou sem chave)
   - Variáveis em `.env`: `SENTRY_DSN`, `POSTHOG_API_KEY`, `POSTHOG_HOST` (todas podem ficar vazias)

7. **E1.7 – CI**
   - `.github/workflows/ci.yml` com `pub get`, `analyze`, `test`, `build apk --debug`
   - Adicionar badge no README

## Definição de pronto

- Todos os checkboxes de `docs/stages/stage-01-foundation.md` marcados (incluindo `[x]` nos critérios de aceite que puderem ser verificados automaticamente; os manuais ficam `[ ]` com nota)
- `flutter analyze` retorna 0 issues
- `flutter test` passa
- Commits criados por entregável
- Atualizar `README.md` da raiz substituindo "Status: Pré-código" por "Status: Stage 1 completo"
- Anotar em `scripts/.run-log.txt` os passos 🛑 HUMAN STEP que ficaram pendentes

Ao terminar, escreva um resumo de 5 linhas em `scripts/.stage-01-summary.md`.
