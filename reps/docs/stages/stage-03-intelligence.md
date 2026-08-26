# Stage 3 – Inteligência (semanas 10–13)

**Objetivo de saída:** diferenciais competitivos prontos. App pronto para **beta fechado** e em seguida lançamento público.

## Pré-requisitos

- [ ] Stage 2 com todos os critérios de aceite ✅

## Entregáveis

### E3.1 – Timer de descanso fullscreen
- `RestTimerOverlay` em rota com `fullscreenDialog: true`
- Barra de progresso circular grande (≥ 60% da tela) + tempo restante numérico
- Inicia automaticamente após "concluir série"
- Tempo padrão = `descanso_segundos` da série planejada
- Botões: +15s, −15s, "pular descanso", "pausar"
- Ao zerar: `vibration` (padrão de 1s) + bipe via `audioplayers` (som configurável em Settings)
- Funciona com tela bloqueada (best-effort: `wakelock_plus` mantém tela ativa)
- Configurável em Settings: ligar/desligar vibração, escolher som, ligar/desligar bipe

### E3.2 – Substituição inteligente
- Botão "substituir" no card do exercício no modo execução
- `SubstituteSheet`:
  - Mostra 3–5 alternativas com mesmo `padrao_movimento` + mesmo `grupo_muscular_primario`
  - Ordenação:
    1. Exercícios com histórico do usuário (mostra última carga)
    2. Mesmo `equipamento`
    3. Alternativas mais distantes
  - Cada card mostra: nome, GIF preview, "última carga: 60kg" se houver
- Ao escolher substituto:
  - `set_logs` daqui em diante na sessão atual: `exercise_id = novo`, `substituido_de_exercise_id = original`
  - Herda `series_planejadas` (nº séries + faixa de reps)
  - Carga = última carga registrada do substituto OU campo vazio
- Evento PostHog: `exercise_substituted`

### E3.3 – Motor de progressão
- Service `ProgressionEngine` em `lib/domain/usecases/progression_engine.dart`
- Ao iniciar treino, calcula carga sugerida por exercício baseado na última sessão:

| Cenário | Sugestão |
|---|---|
| Todas as séries no topo da faixa | +2,5kg compostos / +1kg isoladores |
| ≥ 50% das séries na faixa | manter |
| Maioria abaixo do mínimo | −5% |

- Compostos = padrões empurrada_*, puxada_*, agachamento, dobradica_quadril
- Isoladores = padrão `isolador`
- Sugestão entra como `carga_alvo` no modo execução, **editável**
- Quando usuário sobrescreve sugestão ≥ 3× para o mesmo exercício, ajustar incremento padrão localmente (campo `incremento_kg` em `routine_exercises.notas` ou tabela separada)

### E3.4 – Detecção de PR
- Após cada `set_logged`, comparar com histórico do exercício:
  - PR de carga máxima (maior carga em 1 série, qualquer reps)
  - PR de volume (carga × reps em 1 série)
  - PR de reps na carga atual
- Se detectado, toast persistente "🏆 PR de carga máxima!" (apenas o emoji se usuário pediu emoji-free)
- Tela `RecordsScreen` lista todos os PRs por exercício
- Evento PostHog: `pr_detected` com tipo

### E3.5 – Módulo cardio
- Aba `CardioScreen` na navegação principal
- `CardioFormSheet`: modalidade (dropdown), duração, distância, intensidade (slider 1–10), FC média/máx, calorias
- Persiste em `cardio_sessions` (Drift + Supabase)
- Aparece na linha do tempo do histórico junto com musculação

### E3.6 – Exportação CSV/JSON
- `SettingsScreen` → "Exportar dados"
- Gera dois arquivos:
  - `reps-export-YYYY-MM-DD.csv`: uma linha por `set_log` + sessões de cardio
  - `reps-export-YYYY-MM-DD.json`: estrutura aninhada por sessão
- Usa `share_plus` para compartilhar via sistema operacional
- Funciona inclusive em modo convidado
- Evento PostHog: `data_exported`

### E3.7 – Templates de treino
- `content/templates.json` com 3 templates: PPL (6 dias), Upper/Lower (4 dias), Full Body (3 dias)
- No onboarding ou em "+ Nova rotina", botão "Usar template" → cria as rotinas instantaneamente
- Cada template referencia exercícios da biblioteca por slug

### E3.8 – Resumo semanal de volume
- `WeeklyVolumeScreen`:
  - Gráfico de barras: volume total por grupo muscular na semana corrente
  - Comparação com semana anterior (diff em %)
  - Útil para identificar desequilíbrios (ex.: "panturrilha 0 séries há 3 semanas")

### E3.9 – Polimento e beta
- Tema escuro + claro (sistema)
- Splash com logo "reps"
- Ícone do app
- Política de privacidade (página estática)
- Build de release Android (`.aab`) + iOS (`.ipa`)
- Submissão TestFlight + Google Play internal testing

## Critérios de aceite (gate para lançamento público)

- [x] `flutter analyze` 0 issues e 22/22 testes passando
- [x] Motor de progressão: 5/5 testes cobrindo cenários do doc (+2.5/+1/manter/-5%/sem logs)
- [x] Detecção de PR: 3/3 testes (primeira série, carga máx, reps na carga)
- [x] Substituição: 2/2 testes garantem mesmo padrão + grupo + ordem por equipamento
- [x] Exportação CSV/JSON gera arquivo e dispara share sheet
- [x] Templates PPL, Upper/Lower, Full Body em `assets/templates/templates.json` aplicáveis em 1 toque
- [ ] Timer dispara vibração ao zerar mesmo com tela bloqueada (validar em dispositivo físico)
- [ ] Crashes por sessão < 0,5% em 10 usuários de beta por 7 dias (beta ainda não rodou)
- [ ] Retenção D7 do beta > 60% (idem)
