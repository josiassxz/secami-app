#!/usr/bin/env bash
# Limpa usuarios do Supabase Auth via Admin API.
#
# Deletar de auth.users CASCATEIA: public.users e TODOS os dados do usuario
# (rotinas, sessoes, series, vinculos...) somem junto, por causa dos FKs
# `on delete cascade`. Operacao IRREVERSIVEL.
#
# Precisa da service_role key (Dashboard > Project Settings > API > service_role).
# NUNCA commite essa chave. Passe por variavel de ambiente.
#
# Uso:
#   export SUPABASE_SERVICE_ROLE_KEY=ey...            # service_role (secreta!)
#   ./scripts/clean-test-users.sh                     # lista TODOS (dry-run)
#   ./scripts/clean-test-users.sh 'mateusjos'         # mostra quem casa com o padrao (dry-run)
#   ./scripts/clean-test-users.sh 'mateusjos' --apply # DELETA quem casa com o padrao
#   ./scripts/clean-test-users.sh '.' --apply         # DELETA todos (padrao '.' casa tudo)
#
# O padrao e uma regex aplicada ao e-mail (Python re.search).
set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:-https://shxphqrnlkhyjxkzrtpd.supabase.co}"
KEY="${SUPABASE_SERVICE_ROLE_KEY:?Defina SUPABASE_SERVICE_ROLE_KEY (Dashboard > Settings > API > service_role)}"
PATTERN="${1:-}"
APPLY="${2:-}"

auth=(-H "apikey: $KEY" -H "Authorization: Bearer $KEY")

echo "Projeto: $SUPABASE_URL"
echo "Filtro de e-mail (regex): '${PATTERN:-<todos>}'"
echo

users_json="$(curl -s "${auth[@]}" "$SUPABASE_URL/auth/v1/admin/users?per_page=1000")"

# Filtra id<TAB>email pelos que casam com o padrao.
# JSON e padrao vao por env (stdin fica pro programa Python do heredoc).
rows="$(USERS_JSON="$users_json" PATTERN="$PATTERN" python - <<'PY'
import os, sys, json, re
data = json.loads(os.environ["USERS_JSON"])
users = data.get("users", data) if isinstance(data, dict) else data
pat = os.environ.get("PATTERN", "")
if not isinstance(users, list):
    sys.stderr.write("Resposta inesperada da Admin API (service_role correta?).\n")
    sys.exit(1)
for u in users:
    em = u.get("email") or "(sem email)"
    if pat and not re.search(pat, em):
        continue
    print(u["id"] + "\t" + em)
PY
)"

if [[ -z "$rows" ]]; then
  echo "Nenhum usuario casou com o filtro. Nada a fazer."
  exit 0
fi

count="$(printf '%s\n' "$rows" | grep -c . || true)"
echo "Usuarios que casam ($count):"
printf '%s\n' "$rows" | awk -F'\t' '{print "  - "$2"  ("$1")"}'
echo

if [[ "$APPLY" != "--apply" ]]; then
  echo "DRY-RUN. Nada foi deletado."
  echo "Pra DELETAR esses $count usuarios (e todos os dados deles), rode de novo com --apply:"
  echo "  ./scripts/clean-test-users.sh '${PATTERN}' --apply"
  exit 0
fi

echo ">>> DELETANDO $count usuarios (irreversivel)..."
while IFS=$'\t' read -r id email; do
  [[ -z "$id" ]] && continue
  status="$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "${auth[@]}" "$SUPABASE_URL/auth/v1/admin/users/$id")"
  echo "  [$status] $email"
done <<<"$rows"
echo "Concluido."
