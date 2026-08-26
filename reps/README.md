# reps

Diário de treino técnico, local-first, focado em performance e progressão de carga.

> Documento de origem: [Workout_Tracker_MVP_Documentacao.docx](Workout_Tracker_MVP_Documentacao.docx)
> Nome de produto final: **reps** (anteriormente "Workout Tracker")

## Sobre

App mobile para praticantes intermediários e avançados de musculação. Os três problemas que ele resolve:

1. **Perda de progressão** por falta de histórico estruturado de cargas
2. **Interrupção do treino** quando o equipamento desejado está ocupado
3. **Má gestão do descanso** entre séries

Stack alvo: **Flutter + Supabase** (decisão herdada do doc de MVP).

## Como navegar

| Caminho | O que tem |
|---|---|
| [docs/00-overview.md](docs/00-overview.md) | Visão geral, princípios, posicionamento |
| [docs/01-roadmap.md](docs/01-roadmap.md) | Cronograma de 13 semanas em 3 fases |
| [docs/02-stack.md](docs/02-stack.md) | Stack técnica, justificativas, comandos de setup |
| [docs/03-data-model.md](docs/03-data-model.md) | Modelo de dados completo (7 coleções) |
| [docs/04-features-spec.md](docs/04-features-spec.md) | Especificação por feature |
| [docs/05-seo-marketing.md](docs/05-seo-marketing.md) | SEO, ASO, palavras-chave, landing page |
| [docs/06-metrics.md](docs/06-metrics.md) | Métricas de sucesso do MVP (PostHog) |
| [docs/07-risks.md](docs/07-risks.md) | Riscos e mitigações |
| [docs/stages/stage-01-foundation.md](docs/stages/stage-01-foundation.md) | Fase 1 – Alicerce (semanas 1–4) |
| [docs/stages/stage-02-engine.md](docs/stages/stage-02-engine.md) | Fase 2 – O motor (semanas 5–9) |
| [docs/stages/stage-03-intelligence.md](docs/stages/stage-03-intelligence.md) | Fase 3 – Inteligência (semanas 10–13) |
| [prompts/](prompts/) | Prompts encadeados para execução autônoma por Claude Code |
| [scripts/](scripts/) | Scripts de bootstrap e execução autônoma |
| [CLAUDE.md](CLAUDE.md) | Instruções de projeto para Claude Code |

## Execução autônoma

Dois scripts orquestram a construção do app **sem interação manual**:

```powershell
# 1. Scaffold mecânico: cria projeto Flutter, adiciona dependências, prepara estado
.\scripts\bootstrap.ps1

# 2. Execução autônoma: Claude Code roda cada etapa em sequência, sem pedir aprovação
.\scripts\run-autonomous.ps1
```

Detalhes em [scripts/README.md](scripts/README.md).

## O que você precisa fazer manualmente (≈ 5 minutos)

Só 3 coisas, todas no [Supabase](https://supabase.com):

1. Criar projeto free tier
2. Copiar `.env.example` para `.env` e preencher Project URL + anon key (e `AUTH_REDIRECT_URL` se usar confirmação por e-mail)
3. Após o Stage 1 gerar `supabase/migrations/0001_init.sql`, colar no SQL Editor e executar

**Opcionais** (deixe vazio em `.env` se não usar — SDKs viram no-op): Sentry DSN, PostHog API key.

**Adiado para V1.1** (não fazer agora): OAuth Google/Apple, bucket Storage para GIFs, submissão à App Store/Play Store.

## Status

**MVP completo (Stages 1, 2 e 3)** ✅

- Stage 1: scaffold Flutter, biblioteca 100 exercícios, auth, observabilidade
- Stage 2: Drift local, sync engine, rotinas, modo execução, histórico
- Stage 3: timer fullscreen, substituição inteligente, motor de progressão, detecção de PR, cardio, exportação CSV/JSON, templates, resumo semanal
- `flutter analyze` 0 issues, suíte `flutter test` verde, build web OK
- Pronto para **beta fechado**. V1.1: GIFs reais, login social, integrações Garmin/Strava

Como rodar o app agora:

```powershell
flutter run -d chrome    # mais rápido pra testar
# ou: flutter run -d <device-android>
```
