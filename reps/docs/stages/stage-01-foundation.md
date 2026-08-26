# Stage 1 – Alicerce (semanas 1–4)

**Objetivo de saída:** usuário cadastra, navega pela biblioteca de exercícios e vê GIFs. **Ainda não treina** — isso é Stage 2.

## Pré-requisitos

- [ ] Flutter SDK ≥ 3.22 instalado e em PATH (`flutter --version`)
- [ ] Conta gratuita no [Supabase](https://supabase.com) **(obrigatório)**
- [ ] Conta gratuita no [Sentry](https://sentry.io) **(opcional — sem DSN o SDK vira no-op)**
- [ ] Conta gratuita no [PostHog](https://posthog.com) **(opcional — sem API key o SDK vira no-op)**

## Entregáveis

### E1.1 – Scaffold do projeto Flutter
- `flutter create reps_app --org com.reps.app --platforms ios,android,web`
- Mover/renomear estrutura para `lib/` conforme [02-stack.md](../02-stack.md#estrutura-de-pastas-após-scaffold)
- Adicionar dependências do pubspec listadas em [02-stack.md](../02-stack.md#dependências-pubspec)
- Configurar `analysis_options.yaml` com `flutter_lints` + regras estritas
- Configurar `.gitignore` (incluir `.env`, `*.g.dart`, `*.freezed.dart`)
- `dart format .` + `flutter analyze` passam sem warnings

### E1.2 – Schema Supabase + RLS
- Criar projeto no Supabase, anotar `SUPABASE_URL` + `SUPABASE_ANON_KEY` em `.env`
- Escrever migrações em `supabase/migrations/0001_init.sql` cobrindo todas as 7 tabelas de [03-data-model.md](../03-data-model.md)
- Adicionar índices: `set_logs(session_id)`, `set_logs(exercise_id)`, `workout_sessions(user_id, iniciado_em desc)`, `cardio_sessions(user_id, executado_em desc)`
- Adicionar Row-Level Security em todas as tabelas: `user_id = auth.uid()`. Em `exercises`, leitura pública + escrita só por `criado_por = auth.uid()`
- Triggers `BEFORE UPDATE` para auto-atualizar `updated_at`

### E1.3 – Auth (e-mail/senha + convidado)
- Cliente Supabase inicializado em `lib/core/config/`
- Telas: `splash`, `welcome`, `sign_up`, `sign_in`, `forgot_password`, `magic_link_sent`
- **MVP: somente e-mail/senha.** Login social Google/Apple fica para V1.1 (evita configurar OAuth na Apple Developer e console Google)
- **Modo convidado** ativado por padrão → user_id local gerado via uuid v4
- Fluxo de "mesclar convidado em conta": ao cadastrar, fazer push das tabelas locais usando o `user_id` da nova conta
- Tela de exclusão de conta com confirmação dupla → chamada para edge function que enfileira deleção em 30 dias

### E1.4 – Biblioteca de exercícios
- Tela `LibraryScreen` com lista, busca (debounce 300ms) e filtros multi-select (grupo muscular, padrão de movimento, equipamento)
- Card de exercício com GIF carregado de **asset local** (`AssetImage('assets/exercises/${slug}.gif')`), nome, grupo muscular primário
- Modal de detalhes: GIF maior, descrição, tags
- Fonte de dados (metadados): tabela `exercises` no Supabase. Coluna `gif_url` guarda o **slug** (ex.: `supino_reto_barra`), não URL. App resolve para asset local

### E1.5 – Curadoria dos 100 exercícios (paralelo)
- Planilha CSV em `content/exercises-seed.csv` com colunas: `slug, nome, descricao, grupo_muscular_primario, grupo_muscular_secundario, padrao_movimento, equipamento`
- **GIFs em `assets/exercises/<slug>.gif`**, comprimidos para ≤ 200kb cada (custo: ~20MB no app, aceitável para MVP)
- Declarar a pasta `assets/exercises/` no `pubspec.yaml` (`flutter: assets:`)
- Script de seed em `supabase/seeds/exercises.sql` que insere os 100 registros (com `gif_url = slug`)
- **Sem upload para bucket** — Storage entra só em V1.1

### E1.6 – Observabilidade (opcional)
- Sentry inicializado em `main.dart` **somente se `SENTRY_DSN` não está vazio no `.env`**. Caso vazio, wrapper vira no-op silencioso.
- PostHog inicializado **somente se `POSTHOG_API_KEY` não está vazio**. Caso vazio, wrapper no-op.
- Wrappers em `lib/core/logging/observability.dart` expõem `captureError()` e `track(event, props)` independente das chaves estarem preenchidas. Resto do código não muda.
- Quando chaves estiverem preenchidas, validar no console que pelo menos um evento de teste aparece.

### E1.7 – CI básico
- `.github/workflows/ci.yml`:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter test`
  - `flutter build apk --debug` (smoke build)
- Rodar em push e PR contra `main`

## Critérios de aceite (gate para Stage 2)

- [x] `flutter analyze` retorna 0 issues
- [x] `flutter test` passa (6/6 testes do LibraryRepository)
- [x] `flutter build web --release` compila com sucesso
- [ ] CI verde em `main` (depende de push pro GitHub)
- [ ] App abre em emulador Android → modo convidado por padrão (testar com `flutter run`)
- [x] Biblioteca lista os 100 exercícios (fallback colorido enquanto GIFs reais não chegam)
- [ ] Cadastro completo (e-mail + senha) cria registro em `users` e em `auth.users` (depende de aplicar migrações no Supabase)
- [x] Com `SENTRY_DSN` e `POSTHOG_API_KEY` vazios, app abre normalmente e nenhum log de erro aparece sobre observability
