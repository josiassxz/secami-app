# supabase/

Migrações e seeds do banco Postgres do reps.

## Como aplicar

1. Abra seu projeto em [supabase.com](https://supabase.com)
2. Vá em **SQL Editor**
3. Cole o conteúdo de `migrations/0001_init.sql` e clique **Run**
4. Cole o conteúdo de `seeds/0001_exercises_seed.sql` e clique **Run**

Após isso o banco está pronto para a Fase 1.

## Verificação

Em **Database → Tables** você deve ver:

- `users`
- `exercises` (com ~100 linhas após o seed)
- `routines`
- `routine_exercises`
- `workout_sessions`
- `set_logs`
- `cardio_sessions`

Todas com **RLS ativado** (cadeado azul ao lado do nome).

## Convenções

- Nomes em pt-BR, snake_case
- Toda tabela tem `updated_at`, `deleted_at`, `device_id` para sync
- Triggers automáticos atualizam `updated_at`
- Trigger `on_auth_user_created` insere uma linha em `users` quando alguém se cadastra
- Biblioteca global = `exercises` com `criado_por IS NULL` (leitura pública)
- Customizados = `exercises` com `criado_por = auth.uid()` (privados)

## Regenerar o seed

O seed é gerado a partir de `lib/features/library/data/exercises_seed.dart`. Para regerar:

```powershell
dart run tool/seed_exercises.dart
```
