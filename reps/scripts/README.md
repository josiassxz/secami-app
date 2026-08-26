# scripts/

Dois scripts orquestram a construção do MVP **sem intervenção manual** (exceto passos marcados `🛑 HUMAN STEP` nos prompts, que precisam de conta em serviços externos).

## bootstrap.ps1

Faz o **scaffold mecânico**, antes do Claude entrar:

1. Verifica se Flutter SDK está instalado (`flutter --version`)
2. Verifica se Claude Code CLI está instalado (`claude --version`)
3. Verifica se Git está instalado
4. Inicializa repositório git se ainda não estiver
5. Cria `.env.example` com placeholders das chaves necessárias
6. Cria `scripts/.run-log.txt` e `scripts/.state.json` (estado do pipeline)

Uso:
```powershell
.\scripts\bootstrap.ps1
```

Saída esperada: tudo verde, instruções de próximos passos.

## run-autonomous.ps1

Executa Claude Code em modo **headless** sobre cada prompt em `prompts/`, em sequência. Cada chamada usa `--dangerously-skip-permissions` para evitar approval prompts.

Comportamento:
- Lê estado em `scripts/.state.json` (qual prompt rodar)
- Roda Claude Code com o prompt da etapa atual
- Aguarda conclusão (foreground)
- Verifica saída (existência de `scripts/.stage-0X-summary.md`)
- Avança estado e segue para próxima etapa
- Em caso de erro, marca a etapa como `failed` e para
- Log completo em `scripts/.run-log.txt`

Uso:
```powershell
# Roda a etapa atual (não-completa) e segue até o fim
.\scripts\run-autonomous.ps1

# Força reset e roda do começo
.\scripts\run-autonomous.ps1 -Reset

# Roda só uma etapa específica
.\scripts\run-autonomous.ps1 -OnlyStage 2
```

## Por que isso é "autônomo" mas não 100% automatizado

Foram cortados ao máximo. Sobrou só o essencial:

### Obrigatório antes do Stage 1
| Item | Custo |
|---|---|
| Criar projeto no Supabase em [supabase.com](https://supabase.com) | ~2 min |
| Copiar `SUPABASE_URL` + `SUPABASE_ANON_KEY` para `.env` | ~30s |
| Aplicar `supabase/migrations/0001_init.sql` no SQL Editor do console (Claude gera o arquivo) | ~1 min copy-paste |

**Esses 3 passos + ~5 minutos é tudo que você precisa fazer pra rodar o pipeline inteiro.**

### Opcional (sem isso o app roda igual; SDKs viram no-op)
- `SENTRY_DSN` em [sentry.io](https://sentry.io) – para crash reporting
- `POSTHOG_API_KEY` em [posthog.com](https://posthog.com) – para analytics

### Adiados para V1.1 (não fazer agora)
- Configurar OAuth Google/Apple no Supabase (MVP só com e-mail/senha)
- Subir GIFs a bucket Storage (MVP usa assets locais em `assets/exercises/`)
- Submeter a TestFlight / Play Console

O Claude **detecta** chaves faltando e segue com no-op nos serviços opcionais. Só para se `SUPABASE_URL` ou `SUPABASE_ANON_KEY` estiverem vazios.

## Estado

`scripts/.state.json`:

```json
{
  "current_stage": 1,
  "stages": {
    "1": { "status": "pending|in_progress|done|failed", "started_at": "...", "finished_at": "..." },
    "2": { "status": "pending" },
    "3": { "status": "pending" }
  },
  "last_error": null
}
```

## Logs

`scripts/.run-log.txt` recebe append de cada invocação do Claude com timestamp, etapa, e exit code.
