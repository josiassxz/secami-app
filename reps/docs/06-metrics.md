# 06 – Métricas de sucesso do MVP

Coletadas via PostHog desde o primeiro dia. Sem métricas de vaidade: cada uma responde uma pergunta de produto.

## Metas para 90 dias pós-lançamento

| Métrica | O que mede | Meta MVP |
|---|---|---|
| Sessões de treino / semana / usuário ativo | Retenção real (não login) | **≥ 2,5** |
| Taxa de conclusão de treino | Quantos treinos iniciados são finalizados | **≥ 80%** |
| Uso do timer de descanso | % de treinos com timer usado ≥ 1× | **≥ 60%** |
| Uso de substituição | % de usuários que substituem ≥ 1× por mês | **≥ 30%** |
| Retenção D30 | Usuários ativos 30 dias após cadastro | **≥ 35%** |
| Crashes por sessão | Qualidade técnica | **< 0,5%** |

## Eventos PostHog (definição)

```
app_open
  ─ source: cold | warm | notification
  ─ guest: bool

workout_started
  ─ routine_id: uuid | null
  ─ tipo: fixo | avulso

workout_completed
  ─ duracao_segundos: int
  ─ num_exercicios: int
  ─ num_series: int
  ─ percent_completas: float (0-1)

set_logged
  ─ exercise_id: uuid
  ─ reps: int
  ─ carga_kg: numeric
  ─ tipo_serie: enum
  ─ substituido: bool

set_skipped
  ─ motivo: enum

exercise_substituted
  ─ from_exercise_id: uuid
  ─ to_exercise_id: uuid

timer_used
  ─ duracao_segundos: int
  ─ skipped: bool

pr_detected
  ─ exercise_id: uuid
  ─ tipo: carga_max | volume | reps

data_exported
  ─ formato: csv | json
  ─ num_sessoes: int

account_created
  ─ provider: email | google | apple
  ─ from_guest: bool

account_deleted
```

## Dashboards a criar no PostHog

### Dashboard 1: Saúde do produto (diário)
- DAU / WAU / MAU
- Funil: `app_open` → `workout_started` → `workout_completed`
- Taxa de crash (via integração Sentry)

### Dashboard 2: Engagement
- Sessões de treino por usuário ativo (média semanal)
- Distribuição de duração de treino
- % de usuários que usaram timer / substituição / cardio

### Dashboard 3: Retenção
- Coortes semanais → curva de retenção
- D1, D7, D30, D90

### Dashboard 4: Aquisição
- Origem de novos usuários (orgânico vs. social vs. referência direta)
- Tempo até primeiro treino (TTFV – Time to First Value)
- Conversão guest → conta

## Anti-métricas (sinais ruins)

Monitorar e investigar se aparecerem:

- **Tempo médio de sessão > 90 minutos**: pode indicar usuários esquecendo de finalizar
- **% de sessões com 0 séries registradas**: usuário abre e desiste
- **Crashes > 0,5%**: degradação
- **Substituições > 50% dos exercícios da sessão**: planejamento ruim ou bug na biblioteca

## Definição de "usuário ativo"

Para evitar gaming das métricas:

- **Ativo na semana** = registrou ≥ 1 `set_log` na semana corrente
- **Não conta como ativo**: apenas abrir o app, navegar na biblioteca, mexer em configurações

## Frequência de revisão

- Sprint review (a cada 2 semanas): olhar dashboards 1 e 2
- Mensal: revisão completa com dashboards 3 e 4
- Trimestral: avaliação contra metas de 90 dias e decisão de pivôs
