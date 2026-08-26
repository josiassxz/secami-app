# Protocolo de execução autônoma

Este documento define como cada prompt em `prompts/` deve ser executado por Claude Code em modo headless.

## Regras de execução (válidas para todos os prompts)

1. **Não pergunte.** O usuário autorizou execução autônoma. Tome decisões e siga em frente.
2. **Não pule etapas.** Cada prompt depende de critérios de aceite do anterior.
3. **Falhe alto.** Se um comando falhar (build, test, migração), pare e registre o erro em `scripts/.run-log.txt` antes de tentar novamente. Após 3 falhas no mesmo passo, abortar a etapa.
4. **Stack é fechada.** Flutter + Supabase + Drift + Riverpod. Não trocar.
5. **Português pt-BR** em toda string visível ao usuário. Em código, nomes em pt-BR para campos de dados (`carga_kg`, `series_planejadas`), em inglês para infra (`SyncEngine`, `Repository`).
6. **Critérios de aceite são checklist.** Marque `[x]` no doc da etapa correspondente ao terminar cada item.
7. **Commits frequentes.** Commit por entregável (E1.1, E1.2…) com mensagem `feat(stage-X): <entregável>`.
8. **Lint + test no fim de cada entregável.** `dart format .`, `flutter analyze`, `flutter test`. Todos devem passar antes de seguir.

## Sequência

1. [01-stage-01.md](01-stage-01.md) – Alicerce
2. [02-stage-02.md](02-stage-02.md) – O motor
3. [03-stage-03.md](03-stage-03.md) – Inteligência

## Como rodar

Via script PowerShell:

```powershell
.\scripts\run-autonomous.ps1
```

Ou manualmente, prompt a prompt, via CLI do Claude Code:

```powershell
claude -p "$(Get-Content prompts\01-stage-01.md -Raw)" --dangerously-skip-permissions
```

## Quando intervir manualmente

Estes passos **exigem** ação humana fora do Claude:

- Criar conta Supabase / Sentry / PostHog (não há API pública para signup)
- Configurar OAuth Google/Apple no console Supabase
- Submeter à App Store / Play Store
- Adicionar dispositivo físico para testar vibração

Esses pontos estão marcados como **🛑 HUMAN STEP** dentro dos prompts.
