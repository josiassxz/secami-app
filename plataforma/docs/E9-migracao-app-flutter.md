# E9–E10 — Migração do app Flutter (`reps/`) para a Plataforma SECAMI

Migração do app: transport Supabase → REST, auth LDAP/JWT, re-tema Casa Militar e telas de aluno de academia. Segue a SPEC §10 e o `reps/CLAUDE.md` (feature-first, Riverpod, Drift, pt-BR).

**Status: ✅ migração completa e VERIFICADA por 2 testes de integração reais** (`secami_login_test.dart` + `secami_sync_test.dart`), rodando o app de verdade num simulador iOS contra o backend Spring Boot real (`localhost:8080`): login LDAP, navegação pelas 4 telas de academia, **agendar/cancelar horário de ponta a ponta** (confirmado no Postgres), e **sincronizar uma rotina criada na UI** (confirmado no Postgres). "All tests passed!" nos dois — não é só "compila". 5 bugs reais foram encontrados e corrigidos ao longo do processo (ver §3). Ver §5 para como reproduzir.

## 1. O que foi feito

| Item | Arquivo | Estado |
|---|---|---|
| **Re-tema Casa Militar** | `lib/core/theme/app_theme.dart` | ✅ tokens verde/dourado, raio 12px, Inter + JetBrains Mono, light/dark |
| **Paleta de grupos musculares suavizada** | `lib/features/library/presentation/exercise_thumb.dart` | ✅ 10 tons dessaturados (era a paleta Tailwind vívida do tema antigo) |
| **Banner de PR usa o tema** | `lib/features/workout/presentation/workout_screen.dart` | ✅ `scheme.secondary`/`onSecondary` (era `#FACC15` fixo) |
| **Config da API** | `lib/core/config/env.dart` (+`.env.example`) | ✅ `API_BASE_URL` e `Env.hasRestApi` |
| **Cliente HTTP + JWT** | `lib/core/network/api_client.dart` | ✅ refresh automático no 401, cache síncrono do user id (`cachedUserId`, decodifica o JWT) p/ uso do adapter de sync |
| **Auth LDAP/JWT** | `lib/features/auth/data/rest_auth_service.dart` | ✅ `SecamiUser`, `RestAuthService`, `secamiCurrentUserProvider` |
| **Adapter de identidade** | `lib/features/auth/data/auth_providers.dart` | ✅ `currentUserProvider` (Supabase `User?`) constrói um `User` sintético a partir do `SecamiUser` quando `hasRestApi` — os ~16 consumidores existentes (coaching, sync, settings...) continuam funcionando sem alteração |
| **Tela de login LDAP** | `lib/features/auth/presentation/ldap_sign_in_screen.dart` | ✅ usuário de rede + senha, sem e-mail/cadastro/"esqueci senha" |
| **Router** | `lib/core/router/app_router.dart` | ✅ sem modo convidado quando `hasRestApi` (SPEC §12.4); `/sign-in` obrigatório sem sessão; `/sign-up`/`/forgot-password` inacessíveis |
| **Sync offline → REST** | `lib/core/sync/rest_sync_transport.dart` (novo) + `sync_engine.dart` (editado) | ✅ adapter que imita a fatia do `SupabaseClient` usada pelo engine (`.auth.currentUser`, `.from().select()/.eq()/.gt()/.upsert()`) — o motor de push/pull/last-write-wins (876 linhas) **não foi reescrito**, só teve os tipos trocados para `dynamic` (despacho em runtime entre Supabase e REST) |
| **Coaching → REST** | `lib/features/coaching/data/coach_repository.dart` | ✅ `criarConvite`/`resgatarConvite`/`meusAlunos`/`meusTreinadores` funcionam nos dois modos. Ver nota de escopo em §2 |
| **Telas de aluno (academia)** | `lib/features/academy/presentation/*.dart` | ✅ `AcademiaHomeScreen` (hub), `MinhaAgendaScreen`, `MeuTreinoScreen`, `AvisosScreen`, `MeuPerfilScreen` — aba "Academia" no bottom-nav quando `hasRestApi` |
| **Backend: sync + workout-logs** | `plataforma/backend/.../training/sync/*`, `.../training/log/*` | ✅ `GET/POST /sync/{routines,routine_exercises,workout_sessions,set_logs,cardio_sessions,recommender_runs}`, `GET/PUT /me/workout-logs` — testados por HTTP direto (curl/python) |

## 2. Nota de escopo — o que ficou de fora desta passada

O módulo de coaching do reps (`coach_repository.dart`) tem features **nativas do reps** sem equivalente no backend SECAMI:
- `encerrarVinculo`, `rotinasAtribuidas`, `atribuirRotina` (clona uma `routine` reps para o aluno), `evolucaoAluno` (analytics 30d), e os métodos de academia/org multi-tenant (`minhasOrgs`, `criarOrg`, `membrosDaOrg`).

Esses métodos **continuam chamando só o Supabase** (não migrados). Em uma implantação SECAMI pura (sem Supabase configurado), eles falham com uma `CoachException` clara ("Recurso indisponível sem conta conectada") em vez de silenciosamente não fazer nada — comportamento seguro, não um bug escondido. A prescrição de treino no SECAMI é feita pelas **fichas** (`WorkoutPlan`/`features/academy/`), que é o mecanismo equivalente e já 100% migrado.

O **recomendador** (`features/recommender/`) continua funcionando 100% local (Drift), sem mudança — não foi migrado para o backend (fora do escopo desta passada; o push dele para `/sync/recommender_runs` existe no backend só para não derrubar o ciclo de sync caso o usuário já tenha gerado uma recomendação localmente).

## 3. Decisões técnicas relevantes (para quem retomar)

- **`dynamic` no sync engine**: Dart não tem duck-typing estrutural, então para o motor de sync aceitar tanto `SupabaseClient` quanto `RestSyncTransport` sem duplicar 250+ linhas de lógica, os parâmetros internos (`_runOnce`, `_pushAll`, `_pullTable`, etc.) foram tipados `dynamic`. Os métodos públicos de teste (`debugRunOnce`, `debugPull`) continuam tipados `SupabaseClient?` — os testes existentes (`test/sync_*_test.dart`) não foram tocados e continuam passando.
- **`strict-casts: true`** está ativo em `analysis_options.yaml`: qualquer atribuição implícita de `dynamic` para um tipo concreto é erro de compilação. Por isso `rest_sync_transport.dart` e os pontos de uso em `sync_engine.dart` têm casts explícitos (`as String`, `as List`).
- **`RestQueryBuilder implements Future<...>`**: o código original do sync engine encadeia `.select().eq().gt()` e só faz `await` no final (mesmo contrato do `PostgrestFilterBuilder` do Supabase) — por isso o adapter precisa ser um builder preguiçoso que implementa `Future` por delegação, não um método `async` que já dispara a rede.
- **`ApiClient.cachedUserId`**: o engine acessa `client.auth.currentUser` de forma **síncrona** (sem `await`), mas o token fica no `SharedPreferences` (assíncrono). Resolvido com um cache em memória decodificado do JWT, aquecido no construtor do `ApiClient` (pequena corrida possível nos primeiríssimos instantes do app — documentada no código).
- **Corrida login → redirect**: `ref.invalidate(secamiCurrentUserProvider)` sem aguardar deixava `currentUserProvider` momentaneamente `null`, e o redirect reativo do router batia de volta pra `/sign-in` antes do `context.go('/routines')` "vencer" a corrida. Corrigido com `await ref.refresh(secamiCurrentUserProvider.future)` antes de navegar — **bug real encontrado e corrigido pelo teste de integração**, não só um ajuste de teste.
- **Jackson vs. Postgrest**: o backend Spring serializa records em camelCase (`aceitoEm`), diferente do `snake_case` (`aceito_em`) que os DTOs antigos do coaching esperavam. Resolvido com factories `fromRestJson` paralelas em `coach_models.dart` (as `fromJson` originais continuam servindo o modo Supabase).
- **`ListTile.trailing` com `FilledButton`** (`minha_agenda_screen.dart`): o tema define `FilledButton` com `Size.fromHeight` (só fixa altura); sem largura limitada, o botão tentava ocupar toda a largura do `ListTile.trailing` e quebrava o layout ("Trailing widget consumes the entire tile width"). Só apareceu rodando de verdade num device — `flutter analyze` não pega esse tipo de erro de layout em runtime. Corrigido com um `SizedBox(width: 96, height: 36)` ao redor do botão.
- **`pumpAndSettle()` sem timeout é perigoso em CI/automação**: a 1ª tentativa do teste de integração travou ~9 minutos (processo vivo, CPU ~0%) porque uma tela presa em "loading" (spinner com animação perpétua, por causa do bug do `ListTile` acima) faz `pumpAndSettle()` sem timeout esperar para sempre — o spinner sempre agenda mais um frame. Todo `pumpAndSettle()` do teste agora passa um `timeout` explícito (10s), então uma trava vira falha clara (`PumpAndSettleTimedOutException`) em vez de um processo pendurado.
- **`ListView(children: [...])` ainda virtualiza** (`minha_agenda_screen.dart`): mesmo passando uma lista literal (não `.builder`), o `Sliver` por trás só constrói os filhos dentro da viewport + cache extent — a seção "Meus agendamentos" (abaixo de ~15 tiles de horário) simplesmente não existia na árvore de elementos até a tela ser rolada até ela. `find.text(...)` não encontra o que não foi construído. Corrigido usando `tester.scrollUntilVisible(...)` (que existe exatamente pra isso — "allows looking for finder that is not yet built").
- **Sub-telas dentro do `ShellRoute` ficam sob a bottom nav** (`app_router.dart`): as 4 rotas novas (`/academia/agenda`, etc.) estavam aninhadas dentro do `ShellRoute` (junto do hub `/academia`), então ganhavam a `NavigationBar` do `HomeShell` por baixo. O botão "Agendar" ficava exatamente na mesma faixa Y da bottom nav — o texto aparecia normalmente, mas o **tap não acertava o botão** (hit-test miss, capturado pelo `RenderOffstage` da nav por baixo). Corrigido movendo as 4 sub-telas para **fora** do `ShellRoute` (mesmo padrão já usado por `/coach/alunos`, `/records`, `/cardio` no app — só o hub `/academia` fica dentro, como aba).

## 4. Backend: o que ainda falta (não bloqueia o app)
- Reconciliação do catálogo de exercícios do reps (`seed:<slug>`, biblioteca local em assets) com o catálogo `exercise` do SECAMI (migrado do CSV, sem slugs ainda). Sem isso, `routine_exercise`/`set_log` que referenciam exercícios da biblioteca global do reps **não sincronizam** (ficam só locais) até as duas bases serem casadas — rotina/sessão/cardio (headers) sincronizam normalmente. Coluna `exercise.slug` já existe (migration V3), só falta popular.
- Export xlsx nos relatórios do admin, broadcast de e-mail, migração de mídia (fotos) do base44.

## 5. Como testar (e como foi verificado)

Existe um teste de integração real em `integration_test/secami_login_test.dart` — login LDAP contra um backend **de verdade** rodando em `localhost:8080`, navegação pelas 4 telas novas, checando ausência de erros. Não roda no CI comum (precisa do backend no ar + um simulador/device). Rodar com:

```bash
# 1. Backend no ar (outro terminal): cd plataforma/backend && mvn spring-boot:run
# 2. .env do reps com API_BASE_URL=http://localhost:8080
# 3. Simulador iOS aberto (xcrun simctl boot "iPhone 17" && open -a Simulator)
flutter test integration_test/secami_login_test.dart -d "iPhone 17"
```

`flutter test -d chrome` **não** roda testes de `integration_test` nesta versão do Flutter (3.44.7) — "Web devices are not supported for integration tests yet". Use um simulador/device.

## 6. Checklist de aceite (E9–E10)
- [x] `flutter pub get` + `flutter analyze` sem erros (2 avisos pré-existentes, nível info).
- [x] Login com usuário LDAP/dev entra e o router libera as rotas — **verificado em simulador real**.
- [x] Tema Casa Militar aplicado (sem vermelho/amarelo brutalist em nenhum arquivo).
- [x] Aluno navega Agenda/Ficha/Avisos/Perfil sem erro, com dados reais do backend — **verificado em simulador real**.
- [x] Aluno agenda/cancela horário de ponta a ponta **pela UI** — o teste toca em "Agendar" de verdade, rola até "Meus agendamentos", confirma que saiu do estado vazio, toca em "Cancelar", confirma que voltou ao vazio. **Conferido também direto no Postgres**: o agendamento foi criado (13:00, hoje) e cancelado ~meio segundo depois — o mesmo ciclo que o teste executou. `flutter test integration_test/secami_login_test.dart -d "iPhone 17"` → "All tests passed!".
- [x] App sincroniza rotina local↔servidor de ponta a ponta **via UI** — teste separado (`integration_test/secami_sync_test.dart`): cria uma rotina pela tela "Treinos" (grava no Drift local, dispara o auto-sync debounced de 3s), espera o round-trip real, e o teste termina. **Confirmado direto no Postgres**: a rotina criada na UI (nome com sufixo de timestamp, ex. "Teste Sync E2E 1784647628221") aparece na tabela `routine` do backend com `created_at` batendo com o horário da execução — prova que `SyncEngine` + `RestSyncTransport` fazem o ciclo completo (UI → Drift → dirty flag → debounce → push REST → Postgres), não só o contrato JSON testado via curl.

**3 bugs adicionais encontrados e corrigidos ao estender o teste para o fluxo de agendar/cancelar** (além dos 3 já listados acima): `ListView` virtualiza mesmo com `children:` literal (seção fora da viewport nunca é construída — corrigido com `scrollUntilVisible`); sub-telas aninhadas no `ShellRoute` ficam com hit-test quebrado sob a bottom nav (corrigido movendo pra fora do shell, mesmo padrão de `/coach/alunos`). Nenhum destes seria pego por `flutter analyze` ou por uma revisão de código sem rodar o app de verdade.
