# 05 – SEO, ASO e marketing

Plano de aquisição low-effort para os primeiros 6 meses. Sem orçamento de ads. Foco em **conteúdo + comunidades + ASO**.

## Posicionamento de marca

- **Nome**: reps
- **Tagline pt-BR**: *Seu diário de treino, sem firula.*
- **Tagline en (V2)**: *Your training journal. No fluff.*
- **Tom**: técnico, direto, sem hype. Falo com quem já treina sério.
- **Voz**: pt-BR coloquial mas preciso. "Carga", "série", "PR" — vocabulário de quem está na academia, não de quem leu blog fitness.

## Palavras-chave alvo (pt-BR)

### Volume alto, intenção comercial

| Termo | Volume estimado / mês | Dificuldade |
|---|---|---|
| app de treino academia | ~8.000 | média |
| diário de treino musculação | ~2.500 | baixa |
| planilha de treino app | ~3.000 | média |
| app para anotar treino | ~4.500 | baixa |
| controle de carga treino | ~1.200 | baixa |

### Cauda longa, intenção investigativa

- "app que sugere quanto peso colocar"
- "como saber se evoluí na musculação"
- "substituir exercício na academia equipamento ocupado"
- "alternativa ao hevy em português"
- "alternativa ao strong app brasileiro"

## Landing page

Stack: **Astro** (estático, deploy Cloudflare Pages, free), no diretório `marketing/` (a criar em V1.1, fora do MVP). Páginas:

1. **Home** (`/`)
   - Hero: tagline + screenshot do modo execução
   - 3 colunas: "Sugere carga", "Substitui exercício", "Timer no pulso"
   - CTA: download iOS + Android
2. **Como funciona** (`/como-funciona`)
   - Explicação do motor de progressão (com exemplo numérico)
   - Demonstração da substituição inteligente
   - Vídeo curto (≤ 30s) do modo execução
3. **Privacidade** (`/privacidade`)
   - LGPD: o que coletamos (pouca coisa), por que, como deletar
4. **Exportar dados** (`/exportar`)
   - SEO: "como exportar dados do app de treino" — explica que é nativo, sem paywall
5. **Blog** (`/blog`)
   - 1 post/semana nos 3 primeiros meses (lista de pautas abaixo)

## Pautas do blog (3 meses iniciais)

| # | Título | Palavra-chave alvo |
|---|---|---|
| 1 | Como saber se você está progredindo de verdade na musculação | "como saber se evoluí na musculação" |
| 2 | Carga ideal: 5 estratégias quando o peso certo não está disponível | "carga ideal musculação" |
| 3 | O que é RPE e por que parar de contar reps no automático | "rpe musculação o que é" |
| 4 | Substituir exercício sem perder estímulo: guia prático | "substituir exercício musculação" |
| 5 | Tempo de descanso entre séries: o que a ciência diz vs. o que funciona | "tempo descanso entre séries" |
| 6 | Por que sua planilha está te atrapalhando | "planilha de treino" |
| 7 | 1RM estimado: como calcular sem testar até a falha | "1rm estimado calculadora" |
| 8 | PPL, Upper/Lower, Full Body: qual escolher para seu objetivo | "ppl upper lower full body" |
| 9 | Periodização para intermediários sem complicar | "periodização musculação" |
| 10 | Como exportar e analisar seu histórico de treino em 5 minutos | "exportar histórico treino" |
| 11 | Erros de progressão de carga que travam intermediários | "estagnação musculação" |
| 12 | Volume semanal por grupo muscular: encontrando o seu sweet spot | "volume semanal musculação" |

## Estratégia ASO (App Store Optimization)

### Google Play

- **Título**: `reps – Diário de treino`
- **Descrição curta** (80 chars): `Sugere carga, substitui exercício, timer no pulso. Sem firula.`
- **Descrição completa**: 4000 chars começando com hooks dos 3 problemas resolvidos, palavras-chave naturais espalhadas, sem keyword stuffing
- **Keywords ocultas**: `musculação, treino, hipertrofia, academia, ppl, upper lower, full body, planilha treino, hevy, strong, jefit, fitness, força, powerlifting`
- **Screenshots** (8): execução, biblioteca, substituição, timer, histórico, gráfico de evolução, recordes, exportação

### App Store

- **Subtítulo** (30 chars): `Treino sério, sem firula`
- **Promotional text** (170 chars): `Progressão automática de carga, substituição inteligente de exercício e timer com vibração. Local-first, exporta seus dados sempre.`

## Estratégia de comunidades (primeiros 90 dias)

### Reddit
- r/Hipertrofia (~30k, pt-BR) – participar 4 semanas antes de mencionar app
- r/musculacao – mesma regra
- r/Brasil – cautela, só para milestones
- r/loseit-ptbr – mencionar como ferramenta de tracking

### Discord
- Servidores brasileiros de musculação (procurar por "treino", "hipertrofia")
- Oferecer beta acesso primeiro, feedback gera bug reports

### WhatsApp / Instagram
- Stories de amigos que testam (orgânico)
- Reels curtos (15s) mostrando substituição inteligente

## Programa de indicação (V1.1)

Não implementar no MVP. Estrutura prevista:
- Cada usuário com 10+ treinos ganha link de indicação
- 5 indicações com 1+ treino = badge "Veterano" (gamification leve, opcional, esconde se incomoda)

## Métricas de marketing

| Métrica | Meta 90 dias |
|---|---|
| Instalações orgânicas | 5.000 |
| Sessões blog (mensal no fim do período) | 8.000 |
| CTR Play Store (visita → install) | > 25% |
| Avaliação Play Store | ≥ 4.5 ⭐ |
| Avaliação App Store | ≥ 4.6 ⭐ |
| Backlinks orgânicos | ≥ 10 |

## Press kit (esperar V1.1)

- Logo SVG (versão clara + escura)
- 4 screenshots em alta resolução
- Texto pronto: 100, 250 e 500 palavras
- Bio do fundador (1 parágrafo)
- Contato de imprensa

## Sitemap básico (para `marketing/`)

```
/
/como-funciona
/privacidade
/termos
/exportar
/blog
/blog/[slug]
/imprensa
/contato
```

Schema.org: `SoftwareApplication` na home, `Article` nos posts, `Organization` no rodapé.
