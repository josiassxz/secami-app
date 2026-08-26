# 07 – Riscos e mitigações

| Risco | Prob. | Impacto | Mitigação |
|---|---|---|---|
| Curadoria de 100 GIFs estoura prazo | Alta | Alto | Iniciar curadoria na **semana 1** em paralelo ao código. Aceitar GIFs de baixa qualidade no MVP, refinar pós-lançamento. Fallback: ilustrações geradas por IA para a V0. |
| Sync local-first introduz bugs sutis de conflito | Média | Alto | Usar bibliotecas consolidadas (Drift) em vez de implementação própria. Cobertura de testes em cenários de sync (edição em 2 devices, offline → online, soft delete + restore). |
| Usuários abandonam por fricção de cadastro | Média | Alto | **Modo convidado é o padrão.** Cadastro só é oferecido após 3+ treinos OU tentativa de uso em 2º device. |
| Concorrentes (Strong, Hevy, Jefit) cobrem grande parte do escopo | Alta | Médio | Não competir em quantidade. Foco nos 3 diferenciais: substituição inteligente, progressão automática, modo execução otimizado em pt-BR. |
| Custos de infra escalam com sucesso | Baixa (MVP) | Médio | Free tier de Supabase cobre 50k MAU + 1GB. Compressão agressiva de GIFs (≤ 200kb cada). Plano de migração para tier pago documentado. |
| Sugestão automática de progressão causa lesão | Baixa | Alto (reputacional + legal) | Sugestão é **só sugestão**, sempre editável. Disclaimer no onboarding ("o app não substitui acompanhamento profissional"). Limite máximo de incremento por sessão (+5kg compostos, +2kg isoladores). |
| Loja recusa app por falta de info de privacidade | Média | Médio | Política de privacidade clara em URL pública antes de submeter. Permissões do app pedidas em runtime com justificativa. |
| Login social Apple complica review (sandbox + setup) | Média | Médio | Implementar Apple Sign In **na semana 3** para dar tempo de iterar. Não bloquear MVP se atrasar — Google + e-mail/senha são suficientes. |
| Vibração não dispara em background no Android moderno | Média | Médio | Documentar como limitação. Bipe ainda funciona. Sugerir manter app aberto durante descanso. |
| Performance ruim em listas longas (histórico de 1000+ séries) | Média | Baixo | Usar `ListView.builder` + paginação no Drift (limit/offset). Index em `(user_id, executado_em desc)`. |
| Time pequeno fica sem energia entre Fase 2 e Fase 3 | Alta | Alto | Fase 2 termina com produto **utilizável** — pode lançar beta privado antes da Fase 3. Win cedo evita burnout. |

## Plano de contingência

- **Se atrasar 2 semanas na Fase 1**: cortar curadoria para 50 exercícios essenciais, completar na Fase 2.
- **Se atrasar na Fase 2**: lançar Stage 2 como beta privado sem os diferenciais, coletar feedback enquanto Stage 3 é desenvolvido.
- **Se Supabase free tier não der conta**: migrar para tier pago ($25/mês cobre até centenas de milhares de MAUs).
- **Se concorrente lançar feature idêntica antes**: dobrar em UX (modo execução), não em paridade de feature.

## O que não é risco (e por que)

- **Single dev quitting**: documentação completa em `docs/` permite continuação.
- **Apple/Google removendo de loja**: produto não é controverso, sem ad-tech, sem dark patterns.
- **GDPR fora do Brasil**: MVP foca pt-BR. Estrutura de exclusão de conta já cobre LGPD, GDPR vira ajuste pequeno.
