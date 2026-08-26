#!/usr/bin/env bash
# =============================================================
# Harness de teste de RLS (isolamento professor<->aluno).
#
# Sobe um Postgres efemero em container, aplica o shim de auth + as migrations
# 0001..0008 + grants + seed, e roda os casos de RLS. Falha (exit != 0) se
# qualquer assercao quebrar (psql -v ON_ERROR_STOP=1).
#
# Requer apenas Docker. Roda igual local (Git Bash/WSL/macOS/Linux) e no CI
# (ubuntu-latest tem Docker pre-instalado).
#
#   bash supabase/tests/run_rls_tests.sh
# =============================================================
set -euo pipefail

CONTAINER=reps_rls_pg
IMAGE=postgres:16
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIG="$ROOT/supabase/migrations"
TESTS="$ROOT/supabase/tests"

cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

echo "==> subindo Postgres efemero ($IMAGE)"
docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=postgres "$IMAGE" >/dev/null

echo "==> aguardando o banco aceitar conexoes"
ready=
for _ in $(seq 1 60); do
  if docker exec "$CONTAINER" psql -U postgres -d postgres -c 'select 1' \
       >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ -z "$ready" ]; then
  echo "ERRO: Postgres nao ficou pronto a tempo." >&2
  exit 1
fi

run() { docker exec -i "$CONTAINER" \
          psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q; }

echo "==> shim de auth (schema auth + roles)"
run < "$TESTS/01_auth_shim.sql"

echo "==> aplicando migrations 0001..0008"
for f in "$MIG"/0001_*.sql "$MIG"/0002_*.sql "$MIG"/0003_*.sql \
         "$MIG"/0004_*.sql "$MIG"/0005_*.sql "$MIG"/0006_*.sql \
         "$MIG"/0007_*.sql "$MIG"/0008_*.sql; do
  echo "    -> $(basename "$f")"
  run < "$f"
done

echo "==> grants para o role authenticated"
run < "$TESTS/02_grants.sql"

echo "==> seed do cenario"
run < "$TESTS/03_seed.sql"

echo "==> rodando casos de RLS"
run < "$TESTS/10_rls_cases.sql"

echo "==> OK: todos os casos de RLS passaram."
