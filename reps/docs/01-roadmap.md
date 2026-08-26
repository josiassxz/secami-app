# 01 – Roadmap

13 semanas, 3 fases sequenciais. Cada fase termina com build testável internamente. Ordem é obrigatória — não pular.

## Fase 1 – Alicerce (semanas 1–4)

**Objetivo de saída:** usuário cadastra, navega pela biblioteca de exercícios, vê GIFs. Ainda não treina.

- [ ] Projeto Flutter scaffold + CI/CD básico
- [ ] Schema completo aplicado no Supabase com Row-Level Security
- [ ] Auth: cadastro, login, login social (Google + Apple), recuperação de senha, modo convidado
- [ ] Tela de biblioteca de exercícios com busca + filtros (grupo muscular, padrão de movimento)
- [ ] Curadoria dos 100 exercícios iniciais com GIFs (trabalho de conteúdo, em paralelo ao código)
- [ ] Sentry + PostHog configurados

Detalhe completo: [stages/stage-01-foundation.md](stages/stage-01-foundation.md).

## Fase 2 – O motor (semanas 5–9)

**Objetivo de saída:** o app já é utilizável na academia, mesmo sem os diferenciais.

- [ ] Construtor de rotinas (adicionar, reordenar, remover exercícios)
- [ ] Séries planejadas por exercício (reps, carga, descanso, tipo de série, notas)
- [ ] Atribuição de rotinas a dias da semana
- [ ] Modo execução com check-off de série e registro de carga/reps
- [ ] Histórico de treinos + página por exercício com gráfico de evolução
- [ ] Sincronização local-first (push/pull contra Supabase) funcionando offline-first

Detalhe completo: [stages/stage-02-engine.md](stages/stage-02-engine.md).

## Fase 3 – Inteligência (semanas 10–13)

**Objetivo de saída:** diferenciais competitivos + refinamentos. Pronto para beta fechado.

- [ ] Timer automático em tela cheia, vibração e som configurável
- [ ] Substituição inteligente por tags, com herança de séries e reps
- [ ] Motor de progressão (sugestão automática de cargas)
- [ ] Detecção e exibição de PRs
- [ ] Módulo cardio (registro manual)
- [ ] Exportação CSV/JSON
- [ ] Templates de treino prontos (PPL, upper-lower, full body)
- [ ] Resumo semanal de volume por grupo muscular

Detalhe completo: [stages/stage-03-intelligence.md](stages/stage-03-intelligence.md).

## Pós-MVP (V2)

Não construir agora. Estruturalmente já previsto no modelo de dados.

- Integrações Garmin / Apple Health / Strava
- Periodização programada (ciclos de carga + deload)
- Geração de plano por IA com base em objetivos
- Compartilhamento de rotinas por link
- Versão web read-only
- Apple Watch / Wear OS
