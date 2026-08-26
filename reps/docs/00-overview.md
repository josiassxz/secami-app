# 00 – Visão geral

## O que é

**reps** é um diário de treino técnico para praticantes intermediários e avançados de musculação. Não é app social. Não é app de iniciante. É a ferramenta que substitui a planilha de Excel e o caderno físico, com inteligência embutida para os três problemas mais recorrentes na academia.

## Os três problemas que o MVP resolve

| # | Dor | Solução no MVP |
|---|---|---|
| 1 | Perda de progressão por falta de histórico estruturado | Histórico granular por série + motor de sugestão de carga |
| 2 | Equipamento ocupado interrompe o treino | Substituição inteligente por tag de movimento, com herança de séries/reps |
| 3 | Má gestão do tempo de descanso | Timer automático em tela cheia, com vibração e som configurável |

## Princípios de produto

1. **Local-first.** Sync nunca bloqueia interação.
2. **Atrito zero na execução.** Máximo 2 toques para registrar série.
3. **Dado é dono.** Exportação CSV/JSON sempre disponível, mesmo no plano free.
4. **Performance > estética.** GIFs nunca atrasam UI.
5. **Onboarding com valor imediato.** Biblioteca pré-populada + templates → usuário treina em ≤ 60s.

## Posicionamento

| | Apps comuns | **reps** |
|---|---|---|
| Substituição de exercício | Manual, busca por nome | Automática por tag de movimento, herda séries/reps |
| Progressão de carga | Registro manual sem feedback | Sugestão automática baseada na sessão anterior |
| Offline | Parcial ou inexistente | Local-first integral, sync em background |
| Timer de descanso | Fixo por exercício, sem alerta tátil | Configurável por série, com vibração e som |
| Onboarding | Cadastro obrigatório, biblioteca vazia | Modo convidado, biblioteca pronta, templates |

## Público-alvo

- Frequência semanal: 3–6 treinos
- Já entende periodização básica e progressão
- Valoriza dado estruturado, é hostil a anúncios, cético com features sociais
- Geralmente usa hoje: Excel, caderno, ou app genérico que ignora a realidade da academia brasileira

## Fora de escopo no MVP

Itens estruturalmente previstos no modelo de dados, mas adiados para V2+:

- Integração com Garmin / Apple Health / Strava
- Periodização programada (ciclos de carga e deload)
- Plano de treino gerado por IA
- Compartilhamento de rotinas via link
- Versão web read-only
- Apple Watch / Wear OS
