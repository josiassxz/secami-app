# SPEC — Plataforma SECAMI (Aplicativo + Admin)

> **Documento mestre de especificação.** Consolida o app Flutter (`reps`) e o admin de referência (`academia-secami`) em **uma única plataforma corporativa** para a Academia da Casa Militar / SECAMI (Governo de Goiás), com banco **PostgreSQL** unificado, autenticação **LDAP (AD Goiás)** e identidade visual institucional.
>
> **Autoria:** Fable · **Execução:** Sonnet · **Revisão:** Fable (ver §5 — Metodologia de Entrega)
> **Versão:** 1.0 · **Data:** 2026-07-17 · **Idioma do produto:** pt-BR

---

## 1. Visão geral e objetivo

Hoje existem duas soluções separadas:

1. **`reps`** — aplicativo Flutter de diário de treino (uso pessoal, funciona bem). Offline-first (Drift/SQLite) com sincronização em nuvem (Supabase/Postgres). Já possui um módulo de **coaching** (professor ↔ aluno) e motor de recomendação de treino.
2. **`academia-secami`** — plataforma low-code (Base44/React) de **gestão de academia**: alunos, agendamento por horário, check-in/catraca com reconhecimento facial, fichas de treino, avisos e relatórios. Não é um projeto profissional e hoje só permite exportar dados via CSV (pasta `dados tabelas`).

**Objetivo:** transformar o `reps` num produto corporativo e criar um **Admin** que reúna todas as necessidades operacionais do app (ex.: professor prescrever treino a um aluno) **mais** as funcionalidades de gestão do `academia-secami`, com **um banco único (Postgres)** que os dois front-ends compartilham, **login LDAP** no app e no admin, e paleta de cores institucional (Casa Militar de Goiás) suave e com UX profissional.

### 1.1 Resultado esperado (visão de produto)

| Frente | Tecnologia | Público | Papel |
|---|---|---|---|
| **App** (evolução do `reps`) | Flutter (mantido) | Aluno, Professor | Treino no dia a dia: registrar treino, ver ficha atribuída, agendar horário, check-in, avisos |
| **Admin** | Spring Boot (Java 21) + React (TypeScript) | Admin, Gerente, Recepção, Professor | Gestão: alunos, agenda/horários, check-in, catraca, fichas, exercícios, avisos, relatórios, coaching |
| **API + Banco** | Spring Boot REST + PostgreSQL | — | Fonte única da verdade para ambos os front-ends |
| **Auth** | LDAP (AD Goiás) → JWT | Todos os servidores/militares | Login único institucional |

---

## 2. Escopo

### 2.1 Dentro do escopo
- Unificar os dois domínios (treino + gestão de academia) num **modelo de dados Postgres único** (§8).
- **Backend Spring Boot** que substitui o Supabase como fonte de dados e passa a servir **tanto o app quanto o admin** (§9).
- Migrar a camada de dados do app Flutter de Supabase → **REST do novo backend**, preservando o **offline-first** (Drift + sync) (§10).
- **Re-tema** do app e tema do admin com a **paleta Casa Militar** (§7).
- **Autenticação LDAP** (AD Goiás) para app e admin, com emissão de JWT e RBAC (§12).
- **Admin completo** cobrindo: gestão de alunos, agendamento/horários, **check-in manual**, fichas de treino, catálogo de exercícios, avisos, secretarias/departamentos, datas bloqueadas, relatórios/frequência, **e** o fluxo de coaching (professor prescreve treino/exercícios ao aluno) (§11). *(Check-in automático via catraca fica para fase futura — ver §2.2 e §9.6.)*
- **Migração de dados** dos CSVs (`dados tabelas`) para o Postgres, com de-duplicação e normalização (§13).

### 2.2 Fora do escopo (nesta fase / MVP)
- **Check-in automático via catraca / reconhecimento facial** — é **evolução futura** (decisão do cliente). No MVP o check-in é **manual** pela recepção. O modelo de dados já deixa isso pronto (§9.6, épico E11).
- Cobrança/pagamentos (o `academia-secami` tem dependências Stripe **não usadas** — descartar).
- App para as demais secretarias/órgãos que não usam a academia.
- Reescrita do firmware da catraca/servidor facial.

### 2.3 Premissas
- A rede corporativa alcança o servidor LDAP `ldaps://dc2-dcsrv05.goias.intra:636`.
- O Postgres será provisionado na infraestrutura Goiás (on-prem ou nuvem estadual).
- Nem todo aluno é servidor com conta no AD (há **civis**). Ver §12.4 — estratégia de identidade para alunos civis.

---

## 3. Glossário e papéis

| Termo | Significado |
|---|---|
| **Aluno** | Usuário final da academia (Civil ou Militar). Usa o app. |
| **Professor** | Prescreve fichas/treinos, acompanha evolução. App + Admin. |
| **Recepção** | Faz check-in/out manual e gerencia presença. Admin. |
| **Gerente** | Gestão operacional (alunos, agenda, config, relatórios). Admin. |
| **Admin** | Acesso total, incluindo configurações sensíveis e migrações. Admin. |
| **Ficha (WorkoutPlan)** | Plano de treino A–D prescrito a um aluno. |
| **Rotina (Routine)** | Conceito de treino do `reps` (fixo/flexível, com séries planejadas). |
| **Vínculo** | Relação professor ↔ aluno (tabela `vinculos` do `reps`). |
| **Slot** | Janela de 1h de agendamento (ex.: 07:00–08:00). |
| **Catraca / Frequência** | Evento de acesso físico (entrada/saída) via reconhecimento facial. |
| **Atestado** | Atestado médico de aptidão física; validade 1 ano (obrigatório p/ Civil). |

### 3.1 Papéis (RBAC) — consolidado

Cinco papéis: **`admin`, `gerente`, `recepcao`, `professor`, `aluno`**. Matriz de permissões em §11.1.

---

## 4. Arquitetura alvo

```
┌────────────────────┐        ┌───────────────────────┐
│   App Flutter      │        │   Admin React (TS)    │
│  (Aluno/Professor) │        │ (Admin/Gerente/Recep/ │
│  offline-first     │        │  Professor)           │
│  Drift + sync      │        │  SPA                  │
└─────────┬──────────┘        └───────────┬───────────┘
          │  HTTPS/JSON (JWT)             │  HTTPS/JSON (JWT)
          └──────────────┬────────────────┘
                         ▼
            ┌───────────────────────────┐        ┌────────────────────┐
            │   Spring Boot REST API    │◄──────►│  LDAP / AD Goiás   │
            │  (Java 21)                │  bind   │ dc2-dcsrv05        │
            │  - Auth (LDAP→JWT)        │        └────────────────────┘
            │  - RBAC / regras negócio  │
            │  - Jobs agendados         │        ┌────────────────────┐
            │  - Sync endpoints (app)   │◄──────►│  Servidor Facial / │
            │  - Webhooks catraca       │  API    │  Catraca (contrato)│
            └─────────────┬─────────────┘        └────────────────────┘
                          ▼
                 ┌──────────────────┐
                 │   PostgreSQL     │  (fonte única da verdade)
                 │  Flyway migrations│
                 └──────────────────┘
```

**Princípios:**
- **Fonte única da verdade:** Postgres. Nada de dois bancos.
- **App offline-first preservado:** o Flutter mantém Drift local + fila de sincronização; troca-se apenas o *transport* (Supabase SDK → REST). Colunas de sync (`updated_at`, `deleted_at`, `device_id`, `dirty`) já existem no `reps` e viram o contrato de sync (§10.3).
- **Backend é o dono das regras de negócio** (agendamento, capacidade, atestado, faltas). Nada de regra só no cliente (o `academia-secami` validava quase tudo no front — isso será corrigido).
- **Segurança server-side:** RBAC no backend, JWT curto + refresh, sem senha em texto puro (o `academia-secami` guardava `Student.password` em texto puro — **eliminado**).

### 4.1 Decisão: por que Spring Boot substitui o Supabase
O app hoje fala direto com Supabase (Postgres + Auth + RLS + RPC). Como o requisito é **Postgres + LDAP para app e admin** numa **solução única que conversa entre si**, unificamos num backend Spring Boot que:
- centraliza LDAP (o Supabase Auth não faz LDAP corporativo nativamente);
- serve os dois front-ends com o mesmo modelo e as mesmas regras;
- roda na infraestrutura estadual, sem dependência SaaS externa.

O Postgres **continua sendo Postgres** — apenas deixa de ser gerenciado pelo Supabase.

---

## 5. Metodologia de entrega (Fable → Sonnet → Fable)

Estratégia de trabalho para **todo o projeto**:

| Fase | Modelo | Saída |
|---|---|---|
| **Especificação** (esta e as sub-specs por épico) | **Fable** | Spec detalhada, critérios de aceite, contratos de API/schema |
| **Execução / Implementação** | **Sonnet** | Código (backend, admin, app), migrations, testes |
| **Revisão** | **Fable** | Revisão de código/spec-conformance, riscos, ajustes |

**Fluxo por épico:**
1. **Fable** escreve a sub-spec do épico (deriva desta spec mestre) com contratos e critérios de aceite.
2. **Sonnet** implementa contra a sub-spec, com testes.
3. **Fable** revisa contra a spec e a checklist de qualidade; aponta correções; itera até aprovar.

**WBS (épicos) — cada um segue o ciclo acima:**

| # | Épico | Depende de |
|---|---|---|
| E1 | Fundação: schema Postgres unificado + Flyway + projeto Spring Boot | — |
| E2 | Auth LDAP → JWT + RBAC | E1 |
| E3 | Domínio Academia no backend (alunos, slots, agendamento, check-in, catraca, avisos, secretarias, datas bloqueadas) + regras | E1, E2 |
| E4 | Domínio Treino no backend (exercícios, rotinas/fichas, sessões, set_logs, cardio, records, coaching/vínculos, recomendador) + endpoints de sync | E1, E2 |
| E5 | Migração de dados CSV → Postgres | E1, E3, E4 |
| E6 | Admin React: shell, tema, auth, RBAC | E2, E3, E4 |
| E7 | Admin React: telas de gestão da academia | E3, E6 |
| E8 | Admin React: telas de treino/coaching/exercícios/fichas | E4, E6 |
| E9 | App Flutter: troca de transport (Supabase→REST) + auth LDAP + re-tema | E2, E4 |
| E10 | App Flutter: novas telas de aluno de academia (agenda, check-in, avisos, meu treino) | E3, E9 |
| E11 | Jobs agendados (faltas, lembretes, backup); **integração catraca / check-in automático = pós-MVP** | E3 |
| E12 | Hardening: LGPD, observabilidade, testes e2e, acessibilidade | todos |

---

## 6. Decisões técnicas (ADRs resumidas)

| ID | Decisão | Justificativa |
|---|---|---|
| ADR-01 | **Backend Spring Boot 3 (Java 21)** | Requisito explícito de Java; ecossistema maduro p/ LDAP, segurança, JPA. |
| ADR-02 | **Admin em React + TypeScript** (Vite) + **shadcn/ui** | `academia-secami` já é React; reaproveita telas/ideias; mais ágil que Angular. **shadcn/ui** escolhido (Q4) — casa melhor com os design tokens §7. |
| ADR-03 | **PostgreSQL único**, migrations com **Flyway** | Requisito de Postgres; versionamento de schema auditável. |
| ADR-04 | **Auth LDAP (bind) → JWT** (access curto + refresh) | Login institucional único; stateless na API. |
| ADR-05 | **App Flutter mantido**, camada de dados migrada p/ REST | Requisito de manter Flutter; preservar offline-first. |
| ADR-06 | **Regras de negócio no servidor** | Corrige o antipadrão do `academia-secami` (regra no front). |
| ADR-07 | **UUID v7** como PK em todas as tabelas | Ordenável por tempo, bom p/ sync distribuído e migração. |
| ADR-08 | **Soft-delete + colunas de sync** (`updated_at`, `deleted_at`, `device_id`, `dirty`) | Já usadas no `reps`; base do sync offline. |
| ADR-09 | **Contrato de integração da catraca preservado** (webhooks + API-key) | Não reescrever hardware; manter `registrarAcesso`/`processarFrequencia`. |
| ADR-10 | **Fotos** migradas para storage próprio (Postgres large object / S3 estadual / filesystem) | Sair da dependência `base44.app`. |
| ADR-11 | **i18n pt-BR** e **timezone `America/Sao_Paulo`** fixos | Domínio 100% Brasil; regras dependem de fuso. |

---

## 7. Identidade visual — Paleta Casa Militar (Goiás)

Referência: `goias.gov.br/casamilitar` (verde e dourado/gold como cores-mãe) **+** `referencia-visual.md` (raiz do projeto) — guia de estilo extraído do app **IPASGO Saúde** (Governo de Goiás), trazido pelo cliente como referência direta a seguir "de ponta a ponta" no admin e no app. Decisão revista (substitui a diretriz anterior de tons dessaturados): paleta **vivas e energéticas** — verde institucional vivo como primária, verde-limão como destaque de cards de acesso rápido, dourado vivo como selo/acento — mantendo contraste WCAG AA.

> O `reps`/admin já foram re-temados com esta paleta (ver `app_theme.dart` e `admin/src/index.css`).

### 7.1 Tokens de cor (light — padrão)

| Token | Hex | Uso |
|---|---|---|
| `brand/primary` | `#00783C` | Verde institucional vivo (ações principais, app bar, seleção) |
| `brand/primaryHover` | `#056330` | Estado hover/pressed |
| `brand/primaryContainer` | `#E0F3E7` | Fundos de destaque suaves, chips ativos |
| `brand/onPrimary` | `#FFFFFF` | Texto sobre primary |
| `brand/secondary` (gold) | `#E0B920` | Dourado vivo (selos/badges circulares, destaques, PRs) |
| `brand/secondaryContainer` | `#FBF1D0` | Fundos dourados sutis |
| `brand/onSecondary` | `#3A2E08` | Texto sobre gold |
| `accent/lime` | `#C3E436` | Verde-limão — fundo de cards de acesso rápido (grid estilo referência) |
| `accent/onLime` | `#114023` | Texto/ícone sobre lime |
| `accent/info` | `#3B7A9E` | Azul calmo (informativos, links) |
| `bg/base` | `#F7F8F7` | Fundo da aplicação (off-white com leve verde) |
| `bg/surface` | `#FFFFFF` | Cards, superfícies |
| `bg/surfaceAlt` | `#EEF1EE` | Superfície secundária / listras |
| `line/outline` | `#DCE3DD` | Bordas 1px, divisores |
| `text/primary` | `#1A211C` | Texto principal (quase-preto esverdeado) |
| `text/secondary` | `#5A625C` | Texto secundário/labels |
| `text/disabled` | `#9AA39C` | Desabilitado |
| `status/success` | `#2E7D5B` | Sucesso (concluído, presente) |
| `status/warning` | `#C9922B` | Alerta (atestado a vencer) |
| `status/error` | `#B3452F` | Erro suave (brick, não vermelho puro) |
| `status/faltou` | `#B3452F` | Falta |
| `status/agendado` | `#3B7A9E` | Agendado |
| `status/confirmado` | `#2E7D5B` | Confirmado/check-in |

### 7.2 Tokens de cor (dark)

| Token | Hex |
|---|---|
| `bg/base` | `#121714` |
| `bg/surface` | `#1A211D` |
| `line/outline` | `#2A322C` |
| `text/primary` | `#E6ECE8` |
| `brand/primary` | `#4FCB8B` (verde vivo clareado p/ contraste AA) |
| `brand/secondary` | `#E6C34C` |
| `accent/lime` | `#C3E436` (mesmo valor — é um fundo de card, não texto) |

### 7.3 Diretrizes de UX e tipografia
- **Contraste WCAG 2.1 AA** obrigatório em texto e ícones (validar cada par texto/fundo) — todos os tokens acima validados (ver `referencia-visual.md` para os valores estimados originais do IPASGO).
- **Raio de borda 20px no app** (cards/inputs/chips) **+ botões em pill** (raio total) — referência explícita "cantos muito arredondados". Admin mantém raio menor (~10–12px, rounded-2xl/22px nos cards de acesso rápido) por ser ferramenta de dados densa (tabelas, formulários longos).
- **Elevação leve** (sombras suaves) em vez de bordas "duras".
- **Tipografia do app:** **Poppins** (geométrica arredondada, amigável — troca do Inter original para casar com a referência); números de carga/reps/timer mantêm **JetBrains Mono**. **Admin mantém Inter** (densidade/legibilidade em tabelas prevalece sobre a estética "friendly" do app consumidor).
- **Padrão de card de acesso rápido:** grid 2 colunas, fundo `accent/lime`, selo circular `brand/secondary` com ícone no canto superior, rótulo bold no rodapé — aplicado na home da Academia (app) e no Painel (admin, "Acesso rápido").
- **Espaçamento generoso**, hierarquia clara, componentes grandes e tocáveis (público variado, inclui idosos).
- **Acessibilidade:** suporte a aumento de fonte (A-/A/A+) e alto contraste no admin, espelhando o padrão gov.br.

### 7.4 Entregáveis de design
- `design-tokens.json` (fonte única) → gerado para **Flutter** (`ColorScheme`/`ThemeData`) e **Web** (CSS custom properties / tema MUI ou Tailwind).
- Guia de componentes (botões, inputs, tabelas, badges de status, cards de estatística).

---

## 8. Modelo de dados unificado (PostgreSQL)

Unifica o domínio **treino** (`reps`) e **academia** (`academia-secami`). Convenções: `PK = uuid` (v7), `snake_case`, timestamps `timestamptz`, soft-delete via `deleted_at`, colunas de sync onde o app grava offline. FKs reais (o `academia-secami` não tinha — corrigido). Campos denormalizados (`student_name`, etc.) **eliminados** em favor de joins.

### 8.1 Identidade e organização

**`app_user`** — identidade unificada (servidores AD e alunos civis).
| coluna | tipo | notas |
|---|---|---|
| id | uuid PK | |
| ldap_guid | uuid null | `objectGUID` do AD (null p/ civis sem AD) |
| sam_account_name | text null unique | login AD (`samaccountname`) |
| email | text | |
| nome | text | |
| tipo_identidade | text | `ad` \| `local` (civil sem AD) |
| ativo | bool | default true |
| created_at / updated_at | timestamptz | |

**`user_role`** — papéis (N:N; um usuário pode ser professor **e** aluno).
| coluna | tipo | notas |
|---|---|---|
| user_id | uuid FK→app_user | |
| role | text | `admin`\|`gerente`\|`recepcao`\|`professor`\|`aluno` |
| PK (user_id, role) | | |

**`organizacao`** (academia) — do `reps` (coaching/org).
| id uuid PK · nome text · dono_user_id uuid FK→app_user · created_at |

**`membro_org`** — professores/admins de uma academia.
| id uuid PK · org_id FK · user_id FK · papel text (`professor`\|`admin`) · status text (`ativo`\|`pendente`) |

### 8.2 Aluno e cadastro

**`student`** (perfil de aluno; 1:1 opcional com `app_user`).
| coluna | tipo | notas |
|---|---|---|
| id | uuid PK | |
| user_id | uuid FK→app_user null | vínculo com identidade/login |
| full_name | text not null | |
| cpf | text unique | armazenar **normalizado** (só dígitos) + validado |
| matricula | text | crachá |
| student_type | text not null | `Civil`\|`Militar` (default Civil) |
| department_id | uuid FK→department null | (substitui match por nome) |
| phone / email | text | |
| birth_date | date | |
| weight_kg / height_cm | numeric null | |
| goal | text null | Emagrecimento\|Hipertrofia\|Condicionamento\|Saúde\|Reabilitação\|Força |
| photo_id | uuid FK→media null | foto p/ reconhecimento facial |
| atestado_numero | text null | |
| atestado_data | date null | validade = +1 ano |
| active | bool | default true |
| created_at / updated_at / deleted_at | timestamptz | |

> **Senha removida:** o `academia-secami` guardava `password` em texto puro. Autenticação passa a ser LDAP/JWT (§12); civis sem AD usam identidade local com hash forte (nunca texto puro).

**`department`** (secretarias/órgãos).
| id uuid PK · name text · sigla text · andar text · active bool · created_at/updated_at |

**`media`** (arquivos: fotos de aluno, gifs/fotos de exercício).
| id uuid PK · tipo text (`foto_aluno`\|`exercicio`) · storage_key text · content_type text · created_at |

### 8.3 Agendamento e presença (domínio academia)

**`slot_config`** — janelas de 1h configuráveis.
| coluna | tipo | notas |
|---|---|---|
| id uuid PK | | |
| slot_start / slot_end | text | "HH:MM" |
| max_capacity | int | default 40 (cap aplicado a **Civis**) |
| civil_restricted | bool | civis não podem marcar |
| blocked | bool | esconde a hora |
| block_reason | text | |
| created_at/updated_at | | |

**`blocked_date`** — bloqueio de dia inteiro ou de um slot.
| id uuid PK · date date · slot_start text null (null = dia todo) · reason text · created_at |

**`appointment`** — agendamento.
| coluna | tipo | notas |
|---|---|---|
| id uuid PK | | |
| student_id | uuid FK→student | |
| date | date | |
| slot_start / slot_end | text | |
| status | text | `agendado`\|`confirmado`\|`cancelado`\|`faltou` (default agendado) |
| forced | bool | staff forçou fora das regras |
| notes | text | |
| created_by | uuid FK→app_user | |
| created_at/updated_at/deleted_at | | |
| índice único parcial | (student_id, date, slot_start) where status ≠ cancelado |

**`check_in`** — presença (manual ou via catraca).
| id uuid PK · student_id FK · appointment_id FK null · date date · check_in_time text · check_out_time text null · notes text · created_by FK · created_at/updated_at |

**`frequencia`** — log bruto de acesso da catraca (auditoria/reconciliação).
| id uuid PK · student_id FK · data_hora timestamptz · tipo text (`entrada`\|`saida`) · origem text (`catraca`\|`manual`) · created_at |

### 8.4 Catálogo e prescrição de treino (domínio academia)

**`exercise`** — catálogo (mescla `Exercise` do secami + `custom_exercises` do reps).
| coluna | tipo | notas |
|---|---|---|
| id uuid PK | | |
| name | text | |
| muscle_group | text | Peito\|Costas\|Ombros\|Bíceps\|Tríceps\|Abdômen\|Quadríceps\|Posterior\|Glúteos\|Panturrilha\|Cardio\|Funcional |
| description | text | |
| equipment | text | |
| padrao_movimento | text null | (do reps) |
| video_url | text | |
| photo_id | uuid FK→media null | (gif/foto) |
| escopo | text | `global` (catálogo oficial) \| `custom` (criado por usuário) |
| owner_user_id | uuid FK null | quando custom |
| arquivado | bool | |
| created_at/updated_at | | |

**`workout_plan`** — ficha A–D prescrita (visão academia; do secami).
| id uuid PK · student_id FK · professor_id FK→app_user · sheet_label text (`A`\|`B`\|`C`\|`D`) · title text · active bool · valid_until date null · created_at/updated_at/deleted_at |

**`workout_plan_exercise`** — itens da ficha (normaliza o array JSON do secami).
| id uuid PK · workout_plan_id FK · exercise_id FK · ordem int · sets int · reps text · rest_seconds int · notes text |

**`workout_log`** — registro diário simples de execução da ficha (visão academia/aluno; do secami).
| id uuid PK · student_id FK · workout_plan_id FK · sheet_label text · date date · completed bool · created_at/updated_at |
| **`workout_log_exercise`** | id · workout_log_id FK · exercise_name text · load text · completed bool |

### 8.5 Treino avançado (domínio `reps` — offline-first)

Estas tabelas **espelham o Drift local** do app e carregam colunas de sync (`updated_at`, `deleted_at`, `device_id`, `dirty` no cliente; no servidor `dirty` não se aplica).

**`routine`** — rotina do reps.
| id uuid PK · user_id FK · nome text · tipo text (default `fixo`) · dias_da_semana jsonb (int[]) · ordem int · ativo bool · origem text (`propria`\|`atribuida`) · atribuido_por uuid FK null · created_at/updated_at/deleted_at · device_id text |

**`routine_exercise`**.
| id uuid PK · routine_id FK · exercise_id text · ordem int · series_planejadas jsonb · notas text · grupo_id text null · grupo_tipo text (`normal`\|`bi_set`\|`circuito`) · rounds int null · created_at/updated_at/deleted_at · device_id |

**`workout_session`**.
| id uuid PK · user_id FK · routine_id FK null · iniciado_em timestamptz · finalizado_em timestamptz null · duracao_total_segundos int null · notas text · sentimento int null · updated_at/deleted_at · device_id |

**`set_log`**.
| id uuid PK · session_id FK · exercise_id text · ordem_no_treino int · numero_serie int · reps_realizadas int null · carga_kg numeric null · duracao_segundos int null · rpe int null · tipo_serie text (default `normal`) · executada bool · motivo_pulo text null · substituido_de_exercise_id text null · created_at/updated_at/deleted_at · device_id |

**`cardio_session`** (com integração Health Connect/HealthKit).
| id uuid PK · user_id FK · modalidade text · duracao_minutos int · distancia_km numeric null · intensidade int null · fc_media int null · fc_max int null · calorias int null · external_source text null · external_id text null · synced_at timestamptz null · executado_em timestamptz · updated_at/deleted_at · device_id |

**`recommender_run`** (recomendador — dado de saúde sensível; LGPD).
| id uuid PK · user_id FK · versao_regras text · perfil_json jsonb · triagem_json jsonb **null** (só com consentimento) · treino_json jsonb · divisao text null · bloqueado bool · sincronizavel bool · created_at |

### 8.6 Coaching (professor ↔ aluno ↔ academia — do `reps`)

**`vinculo`** — relação professor↔aluno.
| id uuid PK · professor_id FK→app_user · aluno_id FK→app_user · status text (`ativo`\|`pendente`\|`encerrado`) · aceito_em timestamptz null · org_id uuid FK null · created_at/updated_at/deleted_at |

**`convite`** — código de convite (professor→aluno ou org→professor).
| id uuid PK · codigo text unique · tipo text (`professor_aluno`\|`org_professor`) · criado_por FK · org_id FK null · usos_max int · usos int · expira_em timestamptz · created_at |

### 8.7 Comunicação e auditoria

**`notice`** (avisos/informativos).
| id uuid PK · title text · content text · type text (`info`\|`warning`\|`success`) · active bool · target_roles jsonb (string[]) · created_by FK · created_at/updated_at |

**`audit_log`** (novo — trilha de auditoria de ações sensíveis).
| id uuid PK · actor_user_id FK · acao text · entidade text · entidade_id uuid · payload jsonb · created_at |

### 8.8 Índices e integridade (destaques)
- `student.cpf` unique (dígitos), `app_user.sam_account_name` unique, `app_user.ldap_guid` unique.
- `appointment`: índice único parcial `(student_id, date, slot_start) WHERE status <> 'cancelado'` (impede duplicidade — hoje só validado no front).
- Índices por `date`/`student_id` em `appointment`, `check_in`, `frequencia` (relatórios).
- FKs com `ON DELETE` adequado; nada de "match por nome" (department, professor).

---

## 9. Backend — Spring Boot (Java 21)

### 9.1 Stack
- **Spring Boot 3.x**, Java 21. **Spring Web** (REST), **Spring Data JPA/Hibernate**, **Spring Security** + **Spring LDAP**, **Flyway** (migrations), **springdoc-openapi** (Swagger), **MapStruct** (DTOs), **Bean Validation**. Testes: JUnit 5 + Testcontainers (Postgres) + REST Assured.
- Estrutura por módulos/domínios: `identity`, `academy` (alunos, agenda, checkin, catraca, avisos, secretarias), `training` (exercícios, rotinas, sessões, coaching, recomendador), `sync`, `reporting`, `integration` (catraca), `jobs`.

### 9.2 Segurança
- **Autenticação:** endpoint `/auth/login` faz **bind LDAP** (§12) e emite **JWT access** (~15 min) + **refresh** (rotativo). Filtro JWT em todas as rotas exceto `/auth/**` e webhooks (protegidos por API-key).
- **Autorização:** `@PreAuthorize` por papel; regras de recurso (ex.: aluno só acessa os próprios dados) no serviço.
- **Sem senha em texto puro.** Civis sem AD: hash Argon2/BCrypt (§12.4).
- Rate limiting em `/auth/login` e webhooks; CORS restrito ao domínio do admin e ao app.

### 9.3 Endpoints (visão por domínio — REST/JSON)

> Convenção: `GET` lista/detalha, `POST` cria, `PUT/PATCH` atualiza, `DELETE` soft-delete. Paginação `?page&size`, filtros por query.

**Auth & Identity**
- `POST /auth/login` · `POST /auth/refresh` · `POST /auth/logout` · `GET /me`
- `GET /users` · `PATCH /users/{id}/roles` (admin)

**Academia — Alunos**
- `GET /students` (busca por nome/CPF, filtros) · `GET /students/{id}` · `POST /students` · `PUT /students/{id}` · `DELETE /students/{id}` (admin)
- `POST /students/import` (Excel/CSV, admin) · `POST /students/deduplicate` (admin) · `POST /students/normalize-names` (admin)
- `GET /me/student` · `PUT /me/student` (aluno edita peso/altura/telefone/objetivo/foto)

**Academia — Secretarias / Slots / Datas bloqueadas**
- `GET/POST/PUT/DELETE /departments` · `GET/PUT /slot-configs` · `GET/POST/DELETE /blocked-dates`

**Academia — Agendamento**
- `GET /appointments?from&to&status&studentId` · `GET /schedule?week=` (grade Seg–Sex)
- `POST /appointments` (staff força; valida foto+atestado; §9.5) · `POST /me/appointments` (aluno; todas as regras §9.5) · `DELETE /appointments/{id}` (cancelar)
- `GET /me/appointments`

**Academia — Check-in / Presença**
- `POST /checkins` (recepção: check-in) · `PATCH /checkins/{id}/checkout` · `DELETE /checkins/{id}` (desfazer)
- `PATCH /appointments/{id}/falta` · `PATCH /appointments/{id}/desfazer-falta`

**Academia — Avisos**
- `GET/POST/PUT/DELETE /notices` · `POST /notices/email-broadcast` (admin/gerente)

**Treino — Exercícios & Fichas**
- `GET /exercises` (busca + filtro grupo) · `POST/PUT/DELETE /exercises` (admin/professor) · upload de mídia
- `GET /students/{id}/workout-plans` · `POST/PUT/DELETE /workout-plans` (professor)
- `GET /me/workout-plans` · `POST /me/workout-logs` (aluno registra execução diária)

**Treino — Coaching**
- `POST /coach/invites` (professor gera código) · `POST /coach/invites/redeem` (aluno resgata)
- `GET /coach/students` (alunos do professor) · `GET /coach/trainers` (treinadores do aluno)
- `GET /coach/students/{id}/evolution` (evolução 30d, read-only) · `POST /coach/students/{id}/assign-routine`
- Organização: `GET/POST /orgs` · `GET/POST /orgs/{id}/members`

**Treino avançado — Sync (app)** (§10.3)
- `GET /sync/pull?since=` · `POST /sync/push` (lote de mudanças com `updated_at`/`deleted_at`)
- Entidades sincronizadas: `routine`, `routine_exercise`, `workout_session`, `set_log`, `cardio_session`, `exercise(custom)`, `recommender_run`(se `sincronizavel`).

**Recomendador**
- `POST /recommender/run` (gera treino; grava `recommender_run`; respeita consentimento p/ `triagem_json`)

**Relatórios**
- `GET /reports/attendance?from&to&status&cpf` · `GET /reports/summary` · `GET /reports/checkins-7d` · `GET /reports/frequencia` · `GET /reports/export` (xlsx)

**Integração catraca (webhooks — API-key)** (§9.6)
- `POST /integration/access` (equiv. `registrarAcesso`) · `GET /integration/active-appointments` · `POST /integration/photo-sync`

### 9.4 Regras de negócio — agendamento (preservadas do `academia-secami`, movidas p/ servidor)

**Modelo de slots:** janelas fixas de 1h, **07:00–22:00** (15 janelas). Grade de Seg–Sex. `slot_end = slot_start + 1h`.
> Corrigir a inconsistência do secami (UI dizia "07:00–18:00" para civis, mas gerava até 22:00). A verdade passa a ser `slot_config` no banco.

**Auto-agendamento do aluno** — slot ofertado só se **todas**:
1. `slotDateTime > agora` **e** `slotDateTime ≤ agora + 48h`.
2. `slot_config.blocked = false`.
3. Não (`student_type = Civil` **e** `slot_config.civil_restricted`).
4. Sem `blocked_date` para a data (dia todo ou aquele `slot_start`).

Confirmação bloqueada, salvo se **todas**:
- **Foto obrigatória** (`student.photo_id` presente) — reconhecimento facial da catraca.
- Janela 48h revalidada no submit.
- **Atestado (só Civil):** `atestado_data` presente e **≤ 1 ano**. Militar é isento.
- **Máx. 2 agendamentos ativos** (data ≥ hoje, status ≠ cancelado).
- **1 por dia** (sem outro agendamento ativo na mesma data).
- **Sem duplicado** exato (data+slot).
- **Capacidade Civil:** ativos no slot com `student_type = Civil` ≥ `max_capacity` → "horário cheio para civis". **Militar não** tem limite de capacidade.
- Sucesso → `status = agendado`, `forced = false`.
- Cancelar → soft-delete/`status = cancelado`.

**Force-book (staff):** exige **foto** e (Civil) **atestado** válido; **pula** 48h/2-ativos/1-por-dia/capacidade; cria `forced = true`.

### 9.5 Regras — check-in, faltas, presença
- **Check-in manual** (recepção): cria `check_in` com `check_in_time = agora (HH:mm)`, liga `appointment_id` do dia se houver.
- **Check-out:** grava `check_out_time`. Registro com in+out = "Concluído".
- **Falta:** `appointment.status = faltou`; "desfazer falta" → `agendado`. "Desfazer check-in" apaga o `check_in`.
- **Marcação automática de falta (job):** varre `appointment.status = agendado`:
  - Data passada sem `check_in` → `faltou`.
  - Hoje, se passaram **60 min** de `slot_start` sem `check_in` → `faltou`. (Manter o limiar real de 60 min; parametrizável.)
- **Alerta de "overtime":** aluno com check-in, **sem** check-out, e agora ≥ `slot_end + 15 min` → destacar minutos excedidos (widget no admin, refresh 60s).
- **Lembrete (job ~5 min):** e-mail a quem tem `slot_start` **57–62 min** à frente ("seu treino começa em 1 hora"). Fuso `America/Sao_Paulo`.

### 9.6 Integração catraca / reconhecimento facial — **FASE FUTURA** (check-in automático)
> **Decisão do cliente:** no MVP o **check-in é manual** (recepção, §9.5). O **check-in automático via catraca** é uma **evolução futura** (épico E11, pós-MVP). O modelo de dados já contempla isso (tabela `frequencia`, `check_in.appointment_id`, foto obrigatória no agendamento), então nada precisa ser refeito depois — apenas ativar a integração.

Contrato planejado (preservado do `academia-secami`, a implementar na fase futura):
- `POST /integration/access` (header `x-hardware-api-key`): casa aluno por CPF normalizado, grava **`frequencia`** (`entrada`/`saida`). Depois: em `entrada`, se há agendamento ativo (`agendado`/`confirmado`) no dia → cria `check_in` (idempotente) e vira o agendamento para **`confirmado`**; em `saida`, grava `check_out_time`. Sem agendamento ativo → sem check-in.
- `GET /integration/active-appointments` (API-key): retorna agendamentos ativos hoje+futuro com CPF real + `student_type` para o cache da catraca. Fuso `America/Sao_Paulo`.
- `POST /integration/photo-sync`: envia foto (base64) do aluno ao servidor facial. Manter o **contrato** atual (o `academia-secami` fazia via `cadastroFoto`/`cadastroDados`/`webhookAgendamento`); parametrizar a URL do servidor facial por config (sem ngrok fixo).

### 9.7 Jobs agendados (Spring `@Scheduled`, fuso America/Sao_Paulo)
| Job | Frequência | Ação |
|---|---|---|
| `markAbsences` | a cada 15 min | Marca faltas (regra §9.5) |
| `sendAppointmentReminders` | a cada 5 min | E-mail "treino em 1h" |
| `dailyBackupEmail` (ou export para storage) | diário | Export JSON/DB dos dados |
| `purgeSoftDeleted` (LGPD) | diário | Expurga contas marcadas p/ exclusão após 30 dias |

---

## 10. App Flutter — evolução do `reps`

### 10.1 O que se mantém
- Arquitetura (core/data/domain/features), **Riverpod**, **go_router**, **Drift** local, **fl_chart**, integração **Health**, notificações locais, observabilidade (Sentry/PostHog opcionais).
- Features de treino: **workout** (sessão ativa), **routines** (builder com bi-set/circuito), **history**, **insights** (volume semanal), **library**, **cardio**, **records** (PRs), **recommender** (com consentimento LGPD), **settings**, **coaching**.
- Use cases de domínio: `one_rm` (Epley), `pr_detector`, `progression_engine`, `substitute_exercise`, `volume_aggregator` — **preservar** (lógica de valor).

### 10.2 O que muda
1. **Transport de dados: Supabase → REST** do novo backend. Substituir `SupabaseConfig`/`auth_service`/`coach_repository` e os providers de sync por um `ApiClient` (Dio/http) + repositórios REST. Manter as **interfaces** de repositório para minimizar impacto nas telas.
2. **Auth: Supabase Auth → LDAP/JWT.** Telas `sign_in`/`sign_up`/`forgot_password`/`account` passam a: login por usuário AD + senha (§12); armazenar JWT com refresh seguro; "sign-up" institucional some para servidores (provisionamento vem do AD) — manter cadastro só para o fluxo de aluno civil se aplicável.
3. **Re-tema total** para a paleta Casa Militar (§7): reescrever `app_theme.dart` (novo `ColorScheme`, raio 10–12px, elevação suave, tipografia gov.br). Remover a direção "brutalist".
4. **Sync contra o novo contrato** `/sync/pull|push` (§10.3), mantendo `updated_at`/`deleted_at`/`device_id`/`dirty`.

### 10.3 Contrato de sincronização (offline-first)
- **Pull:** `GET /sync/pull?since=<timestamp>` retorna, por entidade sincronizável, registros com `updated_at > since` (inclui soft-deletes via `deleted_at`).
- **Push:** `POST /sync/push` envia lote de registros `dirty` do device; servidor resolve conflito por **last-write-wins** em `updated_at` (documentar; casos especiais de coaching abaixo).
- **Dados de coaching e de outros alunos NUNCA entram no Drift local** (privacidade — como já é no `reps`): permanecem **online-only** via endpoints `/coach/**`.
- **Recomendador:** `recommender_run` só sobe se `sincronizavel = true` (consentimento no momento da geração) — manter a regra LGPD do `reps`.

### 10.4 Novas telas (aluno de academia dentro do app)
Trazer para o app o que o aluno hoje faz no `academia-secami`:
- **Minha Agenda** (`/agenda`): agendar/cancelar slot com as regras §9.4; ver próximos/histórico.
- **Meu Treino (ficha)** (`/meu-treino`): ver ficha A–D atribuída pelo professor, marcar exercícios concluídos + carga (gera `workout_log`). (Complementa o fluxo `reps` de rotina/sessão.)
- **Avisos** (`/avisos`): informativos por papel; alerta de atestado a vencer (≤30 dias) / vencido.
- **Meu Perfil**: editar peso/altura/telefone/objetivo/foto (foto obrigatória p/ agendar).
- **Check-in/QR** (opcional): exibir identidade p/ recepção; o acesso principal é pela catraca facial.

---

## 11. Admin — React (TypeScript)

Reaproveita as **ideias e telas** do `academia-secami` (mesmas rotas conceituais), com tema Casa Militar, RBAC server-side e as adições de treino/coaching.

### 11.1 Matriz de permissões (RBAC)

| Recurso / Ação | admin | gerente | recepcao | professor | aluno* |
|---|:--:|:--:|:--:|:--:|:--:|
| Dashboard | ✔ | ✔ | ✔ | ✔ | ✔ |
| Alunos — listar/ver | ✔ | ✔ | ✔ | ✔ (ro) | próprio |
| Alunos — criar/editar | ✔ | ✔ | – | – | próprio perfil |
| Alunos — excluir | ✔ | – | – | – | – |
| Agenda (grade) | ✔ | ✔ | ✔ | ✔ | ver/marcar |
| Force-book / excluir agendamento | ✔ | ✔ | ✔ | – | – |
| Config. de horários (slots) | ✔ | ✔ | – | – | – |
| Datas bloqueadas | ✔ | ✔ | – | – | – |
| Secretarias | ✔ | ✔ | – | – | – |
| Check-in / presença | ✔ | – | ✔ | ✔ | – |
| Exercícios (catálogo) | ✔ | – | – | ✔ | ver |
| Fichas de treino | ✔ | – | – | ✔ | própria |
| Coaching (vínculos/evolução) | ✔ | – | – | ✔ | próprio |
| Avisos | ✔ | ✔ | – | – | ver |
| Relatórios / export | ✔ | ✔ | – | – | – |
| Migração/dados (import, dedup) | ✔ | – | – | – | – |

\* Aluno normalmente usa o **app**; o acesso "aluno" no admin é mínimo (ver próprio). Enforcement é **no backend** (não só no menu).

### 11.2 Telas do admin

**Gestão da academia (do `academia-secami`):**
- **Dashboard** — KPIs (alunos ativos, agendamentos hoje, check-ins hoje), widget de overtime, lista de agendamentos do dia, avisos por papel.
- **Alunos** — lista/busca (nome/CPF mascarado), CRUD conforme papel, perfil, foto, atestado.
- **Agenda** — grade Seg–Sex 07:00–22:00; visão contagem vs nomes; force-book; contagem Civil `x/max` e Militar por slot; respeita slots bloqueados e datas bloqueadas.
- **Config. de Horários** — CRUD `slot_config` (blocked, civil_restricted, max_capacity).
- **Check-in** — console da recepção por data; check-in/out, marcar/desfazer falta, desfazer check-in; foto.
- **Datas Bloqueadas** — dia inteiro ou slot, com motivo.
- **Secretarias** — CRUD (nome, sigla, andar).
- **Avisos** — CRUD + broadcast de e-mail aos alunos ativos.
- **Relatórios** — cards-resumo; gráfico de check-ins 7 dias; tabela de frequência (merge agendamentos+check-ins) com filtros (período, status, CPF); **export xlsx**; **nova aba de Frequência (catraca)** usando a tabela `frequencia` (hoje não exposta).

**Gestão de treino / coaching (necessidades do app + do reps):**
- **Exercícios** — catálogo (grid, busca, filtro por grupo, mídia gif/vídeo), CRUD (admin/professor).
- **Fichas de Treino** — montar/editar fichas A–D por aluno (séries/reps/descanso), com base no catálogo.
- **Coaching** — professor vê seus alunos vinculados, **evolução (30d)** (sessões, séries, volume por grupo), e **prescreve/atribui rotina** ao aluno; geração de **convites**; gestão de **organização** (academia) e membros.
- **Recomendador (admin)** — visão/gestão das execuções do motor de recomendação (auditoria `recommender_run`).

### 11.3 Stack do admin
- React 18 + TypeScript + Vite. Roteamento `react-router` v6. **TanStack Query** para dados. Componentes: **MUI** ou **shadcn/ui** (decidir no E6) tematizados com os tokens §7. Gráficos: Recharts. Export: SheetJS (xlsx). Formulários: React Hook Form + Zod. i18n pt-BR.

---

## 12. Autenticação e autorização — LDAP (AD Goiás)

### 12.1 Configuração (de `ldap.md`)
```yaml
ldap:
  enabled: true
  host: dc2-dcsrv05.goias.intra
  protocol: ldaps
  port: 636
  ssl: true
  baseDn: "OU=Usuarios,OU=SGG,OU=GOVERNADORIA (SGG),OU=ORGAOS,DC=goias,DC=intra"
  bindDn: "sistemas.sgg@sistemas.goias.gov.br"
  bindPassword: "<via secret manager — NÃO versionar>"
  loginAttribute: "samaccountname"
  syncAttribute: "objectguid"
  userFilter: "(&(objectClass=user)(objectCategory=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
```
> ⚠️ **Segredo:** `bindPassword` (e todo segredo) vai para **variável de ambiente / secret manager**, nunca no repositório. A senha presente em `ldap.md` deve ser **rotacionada** e o arquivo tratado como sensível.

### 12.2 Fluxo de login
1. Front (app/admin) envia `samAccountName` + senha para `POST /auth/login`.
2. Backend faz **bind** com a conta de serviço, busca o usuário sob `baseDn` com `userFilter` + `samaccountname`.
3. Faz **re-bind** com o DN do usuário + senha informada (valida credencial). Só usuários **ativos** (o filtro exclui `userAccountControl` desabilitado).
4. **Provisionamento just-in-time:** casa/atualiza `app_user` por `objectGUID` (`ldap_guid`); cria se novo.
5. Emite **JWT access + refresh**; resposta inclui papéis e perfil.

### 12.3 Mapeamento de papéis
- **Decisão do cliente (Q3 resolvida): gestão manual no admin.** Papel **não** vem do AD automaticamente. Modelo: `user_role` no Postgres, gerenciado por **admin** no painel. Default de primeiro acesso = `aluno`.
- Mapeamento de grupos AD → papéis fica como evolução futura (não no MVP), caso a TI Goiás crie grupos dedicados (ex.: `GG-ACADEMIA-PROFESSORES`).

### 12.4 Identidade — LDAP único para todos
**Decisão do cliente (Q1 resolvida): todos logam via LDAP (AD Goiás).** Não há mais provedor local.
- App e admin usam **um único provedor de autenticação: LDAP**. Toda identidade é `tipo_identidade = ad` (a coluna fica no schema apenas como reserva para uma eventual necessidade futura).
- **Dependência (novo risco Q10):** os alunos **civis** também precisam ter conta no **AD Goiás** para logar. Isso exige provisionamento dessas contas pela TI/infra Goiás **antes** do go-live para o público civil. Confirmar o processo e o prazo de criação dessas contas.
- A coluna `password` do legado **não** é migrada (era texto puro) — a senha é sempre validada pelo AD via bind.

### 12.5 Autorização
- JWT carrega `sub` (user_id) e papéis. Backend valida por `@PreAuthorize` e por dono do recurso.
- App: guard de rotas por papel (professor vê coaching; aluno vê agenda/treino).

---

## 13. Migração de dados (CSV → PostgreSQL)

Fonte: `dados tabelas/*.csv` (export do `academia-secami`/Base44). Ferramenta: **rotina de importação idempotente** (job Spring `import` ou script), executada em ambiente de migração. Ordem respeita FKs.

### 13.1 Volumes (referência)
| CSV | Registros | Destino |
|---|---:|---|
| Student_export.csv | 492 | `student` (+ `app_user` p/ os que logam) |
| Department_export.csv | 13 | `department` |
| SlotConfig_export.csv | 15 | `slot_config` |
| BlockedDate_export.csv | 1 | `blocked_date` |
| Exercise_export.csv | 223 | `exercise` (escopo `global`) |
| WorkoutPlan_export.csv | 102 | `workout_plan` + `workout_plan_exercise` (explode array) |
| WorkoutLog_export.csv | 282 | `workout_log` + `workout_log_exercise` (explode arrays) |
| Appointment_export.csv | 3.817 | `appointment` |
| CheckIn_export.csv | 3.864 | `check_in` |
| Frequencia_export.csv | 196 | `frequencia` |
| Notice_export.csv | 2 | `notice` |

### 13.2 Mapeamento e transformações
- **IDs Base44 (hex de 24)** → preservar como `legacy_id` (coluna auxiliar durante a migração) e gerar `uuid` novo; construir tabela de-para `legacy_id → uuid` para religar FKs (`student_id`, `workout_plan_id`, `appointment_id`).
- **CPF:** normalizar para dígitos; validar; de-dup por CPF (manter o mais antigo — regra `deduplicateStudents`).
- **Denormalizados** (`student_name`, `professor_name`, `student_type` em appointment) → resolver para FKs; descartar as cópias.
- **`WorkoutPlan.exercises` (JSON array)** → linhas em `workout_plan_exercise`, religando `exercise_id` pelo de-para (fallback: casar por `exercise_name`).
- **`WorkoutLog.completed_exercises` / `exercise_loads` (JSON)** → `workout_log_exercise`.
- **`student_type`** distintos observados: `Civil` (487), `Militar` (5).
- **`appointment.status`:** `agendado` (3.658), `confirmado` (35), `faltou` (124) — mapear 1:1 (+ `cancelado` quando aplicável).
- **`frequencia.tipo`:** `entrada` (112), `saida` (84).
- **Datas** `created_date`/`updated_date` → `created_at`/`updated_at` (timestamptz, fuso Sao_Paulo).
- **`is_sample = true`** → ignorar (dados de exemplo).
- **`password` (texto puro)** → **NÃO migrar**; alunos que logam recebem identidade AD (servidores) ou fluxo de definição de senha local (civis, se Opção A).

### 13.3 Ordem de carga
1. `department` → 2. `app_user`/`student` (de-dup) → 3. `slot_config`, `blocked_date` → 4. `exercise` → 5. `workout_plan` (+itens) → 6. `appointment` → 7. `check_in` → 8. `frequencia` → 9. `notice` → 10. `workout_log` (+itens).

### 13.4 Qualidade e reconciliação
- Relatório de importação: contagens origem vs destino, órfãos (FK não resolvida), duplicados removidos.
- Idempotência por `legacy_id` (re-rodar não duplica).
- **Compatibilidade contínua com CSV:** manter um **endpoint/serviço de importação CSV** no admin (`POST /students/import`, e um importador genérico) para a **migração final** e cargas pontuais, aceitando o layout desses exports (headers conhecidos).

### 13.5 Fotos e mídia
- **Decisão do cliente (Q2 resolvida): re-baixar antes do desligamento.** Fotos de aluno e gifs de exercício hoje apontam para `base44.app`.
- Rodar um job de migração de mídia **enquanto o Base44 ainda está no ar**: baixar cada URL, gravar no storage próprio (`media`) e atualizar `photo_id` em `student`/`exercise`.
- Gerar relatório de mídia não baixada (URL morta) para recadastro manual. Esta etapa vira **pré-requisito da janela de cutover** (não desligar o Base44 antes de concluí-la).

---

## 14. Requisitos não-funcionais

- **Segurança / LGPD:** dados sensíveis de saúde (triagem do recomendador) só com consentimento; exclusão de conta em 30 dias (job); sem senha em texto puro; segredos em secret manager; TLS ponta a ponta (LDAPS já é SSL); auditoria (`audit_log`) de ações sensíveis; CPF mascarado nas listagens.
- **Performance:** paginação server-side; índices §8.8; grade de agenda e relatórios com consultas otimizadas; app offline-first (latência zero percebida em treino).
- **Observabilidade:** logs estruturados no backend; métricas (Actuator/Prometheus); Sentry no app (opcional, no-op se sem chave).
- **Timezone:** todos os jobs/regras em `America/Sao_Paulo`; armazenar em UTC.
- **Acessibilidade:** WCAG AA; ajuste de fonte e alto contraste no admin; alvos de toque grandes no app.
- **i18n:** pt-BR; textos centralizados.
- **Testes:** unitários (regras de agendamento/faltas/atestado/capacidade), integração (Testcontainers Postgres + LDAP mock), e2e do admin (Playwright) e do app (integration_test).
- **CI/CD:** pipeline com build+test+migrations (Flyway) + lint; ambientes dev/homolog/prod.

---

## 15. Riscos e questões em aberto

| ID | Questão / Risco | Impacto | Encaminhamento |
|---|---|---|---|
| ~~Q1~~ | ✅ **Resolvida:** **todos logam via LDAP** (provedor único; sem identidade local). | — | Ver §12.4 |
| ~~Q2~~ | ✅ **Resolvida:** **re-baixar mídia** do base44 antes do desligamento (pré-req do cutover). | — | Ver §13.5 |
| ~~Q3~~ | ✅ **Resolvida:** papéis por **gestão manual no admin** (`user_role`); grupos AD ficam para depois. | — | Ver §12.3 |
| ~~Q4~~ | ✅ **Resolvida:** admin em **shadcn/ui**. | — | Ver ADR-02 |
| **Q10** | Alunos **civis** precisam de conta no **AD Goiás** para logar (decorrência de Q1). Qual o processo/prazo de provisionamento pela TI? | Alto | Confirmar com infra Goiás **antes** do go-live civil |
| **Q5** | App: manter **Health Connect/HealthKit**? (permissões corporativas) | Baixo | Manter; é opcional/no-op |
| **Q6** | Servidor **facial/catraca**: URL fixa/estável na infra Goiás? | Médio | Parametrizar por config; validar rede |
| **Q7** | Volume futuro (muitos órgãos) exige HA/replicação do Postgres? | Médio | Dimensionar na infra estadual |
| **Q8** | E-mail broadcast: qual SMTP/serviço institucional? | Médio | Definir provedor de e-mail gov |
| **Q9** | Senha de bind em `ldap.md` exposta | Alto (segurança) | **Rotacionar** e mover p/ secret manager |

---

## 16. Roadmap (fases sugeridas)

- **Fase 0 — Fundação:** E1 (schema+Flyway+projeto), E2 (LDAP/JWT). Decidir Q1, Q4.
- **Fase 1 — Backend de domínio:** E3 (academia) + E4 (treino/coaching/sync) com testes.
- **Fase 2 — Migração:** E5 (CSV→Postgres) em ambiente de homolog; reconciliação.
- **Fase 3 — Admin:** E6 (shell/tema/auth) → E7 (gestão) → E8 (treino/coaching).
- **Fase 4 — App:** E9 (transport+auth+tema) → E10 (telas de aluno de academia).
- **Fase 5 — Operação:** E11 (jobs agendados) + E12 (hardening LGPD/observabilidade/e2e).
- **Go-live:** migração final de dados (importador CSV) + re-download de mídia + cutover do Base44.
- **Pós-MVP:** ativar **check-in automático via catraca / reconhecimento facial** (E11, integração §9.6).

---

## 17. Critérios de aceitação (amostra por épico)

- **E2 (LDAP):** usuário AD ativo loga no app e no admin com a mesma credencial; usuário desabilitado é negado; JWT expira e refresha; papéis aplicados server-side.
- **E3 (Agendamento):** aluno Civil sem atestado válido **não** agenda; Civil não agenda slot `civil_restricted`; capacidade Civil respeitada; Militar isento de capacidade; máx. 2 ativos e 1/dia; force-book do staff ignora limites mas exige foto+atestado.
- **E3 (Faltas):** agendamento sem check-in vira `faltou` conforme regra de 60 min/data passada; check-in manual da recepção liga ao agendamento do dia. *(Confirmação automática via catraca é validada no E11, pós-MVP.)*
- **E4 (Coaching):** professor gera convite; aluno resgata e cria vínculo; professor atribui rotina (aparece como `origem=atribuida` no app do aluno); professor vê evolução 30d **sem** acessar o banco local do aluno.
- **E5 (Migração):** contagens origem=destino (descontando `is_sample` e duplicados); FKs resolvidas; nenhum `password` migrado.
- **E9 (App):** app funciona offline e sincroniza ao reconectar (pull/push); tema Casa Militar aplicado; login LDAP.
- **Design:** todos os pares texto/fundo passam contraste AA; nenhuma cor "forte" em grandes áreas.

---

### Anexos de referência
- **Fonte de análise:** `reps/` (Flutter: Riverpod, Drift, go_router, fl_chart, health, coaching Stage-4, recomendador), `academia-secami/` (React/Base44: entidades, papéis, regras de agenda/check-in/catraca/relatórios), `dados tabelas/*.csv` (dados de produção p/ migração), `ldap.md` (config AD).
- **Convenções:** UUID v7 · timestamptz UTC · soft-delete · sync (`updated_at`/`deleted_at`/`device_id`/`dirty`) · pt-BR · America/Sao_Paulo.
