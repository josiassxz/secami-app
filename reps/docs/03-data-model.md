# 03 – Modelo de dados

Sete coleções. Projetado para escala razoável, sync local-first, flexibilidade para técnicas avançadas sem refatoração estrutural.

Todos os registros possuem três campos comuns para sync:

- `updated_at` (timestamptz) – usado em last-write-wins
- `deleted_at` (timestamptz, nullable) – soft delete
- `device_id` (text) – origem da última edição

## users

Identidade e preferências do usuário.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | mesmo id do `auth.users` do Supabase |
| `email` | text | único |
| `nome` | text | exibido em saudações |
| `unidade_peso` | enum('kg','lb') | default 'kg' |
| `unidade_distancia` | enum('km','mi') | default 'km' |
| `som_timer` | text | nome do som escolhido |
| `vibracao_timer` | bool | default true |
| `criado_em` | timestamptz | |
| `plano` | enum('free','pro') | 'pro' reservado para V2 |

## exercises

Biblioteca global + customizados do usuário.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `nome` | text | pt-BR |
| `descricao` | text | uma frase |
| `gif_url` | text | URL no bucket Storage |
| `grupo_muscular_primario` | enum | peito, costas, ombros, biceps, triceps, quadriceps, posterior, gluteos, panturrilha, core |
| `grupo_muscular_secundario` | enum[] | array |
| `padrao_movimento` | enum | puxada_vertical, puxada_horizontal, empurrada_vertical, empurrada_horizontal, agachamento, dobradica_quadril, isolador |
| `equipamento` | enum | barra, halter, maquina, cabo, peso_corporal, kettlebell, anilha |
| `criado_por` | uuid FK users.id | null = biblioteca global |
| `arquivado` | bool | |

**Substituição inteligente** usa: mesmo `padrao_movimento` + mesmo `grupo_muscular_primario`, priorizando exercícios com histórico do usuário.

## routines

Treinos do usuário.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid FK | |
| `nome` | text | ex.: "Peito e Tríceps" |
| `tipo` | enum('fixo','avulso') | |
| `dias_da_semana` | int[] | 0=domingo … 6=sábado, vazio se avulso |
| `ordem` | int | ordenação dentro da pasta |
| `ativo` | bool | |

Relação 1-N com `routine_exercises`.

## routine_exercises

Configuração de cada exercício dentro de uma rotina.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `routine_id` | uuid FK | |
| `exercise_id` | uuid FK | |
| `ordem` | int | |
| `series_planejadas` | jsonb | array de `{numero, reps_alvo_min, reps_alvo_max, carga_alvo, descanso_segundos, tipo_serie, aquecimento, duracao_alvo_segundos}` (`duracao_alvo_segundos` = alvo de tempo p/ séries por tempo, null caso contrário) |
| `notas` | text | tempo sob tensão, cadência, etc. |
| `grupo_id` | uuid | exercícios com mesmo `grupo_id` formam um bloco bi-set/circuito; null = solo |
| `grupo_tipo` | text | `normal` \| `bi_set` \| `circuito` |
| `rounds` | int | rodadas do circuito; null em bi-set (deriva do nº de séries) |

`tipo_serie` ∈ {normal, drop_set, superset, rest_pause}.

## workout_sessions

Cada execução real de um treino.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid FK | |
| `routine_id` | uuid FK | nullable (treino avulso direto) |
| `iniciado_em` | timestamptz | |
| `finalizado_em` | timestamptz | null = em andamento |
| `duracao_total_segundos` | int | |
| `notas` | text | |
| `sentimento` | int | escala 1–5, opcional |

## set_logs

Cada série individual executada. Granularidade essencial para análise.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `session_id` | uuid FK | |
| `exercise_id` | uuid FK | |
| `ordem_no_treino` | int | |
| `numero_serie` | int | |
| `reps_realizadas` | int | null em séries medidas por tempo |
| `duracao_segundos` | int | duração executada (prancha/isometria); null em séries por repetição |
| `carga_kg` | numeric | |
| `rpe` | int | 1–10, opcional |
| `tipo_serie` | enum | igual a `routine_exercises.series_planejadas[].tipo_serie` |
| `executada` | bool | false = pulada |
| `motivo_pulo` | enum | equipamento_ocupado, fadiga, lesao, dor, outro |
| `substituido_de_exercise_id` | uuid FK | rastreio de substituições |

## cardio_sessions

Sessões de cardio. Modelo isolado da musculação.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `user_id` | uuid FK | |
| `modalidade` | enum | esteira, bicicleta, escada, corrida_ar_livre, remo, eliptico, outros |
| `duracao_minutos` | int | |
| `distancia_km` | numeric | nullable |
| `intensidade` | int | 1–10 |
| `fc_media` | int | nullable |
| `fc_max` | int | nullable |
| `calorias` | int | estimativa |
| `external_source` | text | reservado V2: garmin, apple_health, strava |
| `external_id` | text | id no sistema externo |
| `synced_at` | timestamptz | reservado V2 |
| `executado_em` | timestamptz | |

## Estratégia de sync

- Cliente mantém SQLite local (via Drift) com as mesmas colunas, mais um espelho.
- Endpoints REST do Supabase: `GET /rest/v1/<tabela>?updated_at=gt.<ts>` (pull) e `POST/PATCH` (push).
- Resolução de conflito: **last-write-wins por linha**, baseado em `updated_at`.
- Soft delete via `deleted_at` para permitir reconciliação.
- Conflitos raros (mesma série editada em dois devices ao mesmo tempo) → o último wins, sem prompt para o usuário.
- Row-Level Security no Postgres: `user_id = auth.uid()` em todas as tabelas exceto `exercises` global (que tem leitura pública, escrita só por service role).

## Diagrama de relações

```
users 1───N routines 1───N routine_exercises N───1 exercises
  │                                                     ▲
  │ 1                                                   │ substituido_de
  └───N workout_sessions 1───N set_logs ────────────────┘
  │
  └───N cardio_sessions
```
