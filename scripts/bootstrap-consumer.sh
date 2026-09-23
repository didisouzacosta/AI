#!/usr/bin/env bash
set -euo pipefail
usage() { echo "Uso: ai-bootstrap [CAMINHO_DO_PROJETO]"; }
[[ "${1:-}" != "--migrate-existing" ]] || { echo "Erro: a migração automática do layout ai foi removida." >&2; exit 2; }
[[ $# -le 1 ]] || { usage >&2; exit 2; }
path="${1:-.}"
source="${BASH_SOURCE[0]}"
while [[ -L "$source" ]]; do d="$(cd "$(dirname "$source")" && pwd)"; target="$(readlink "$source")"; [[ "$target" = /* ]] && source="$target" || source="$d/$target"; done
root="$(cd "$(dirname "$source")/.." && pwd)"
project="$(cd "$path" 2>/dev/null && git rev-parse --show-toplevel)" || { echo "Erro: '$path' deve estar em um projeto Git." >&2; exit 1; }
cd "$project"
bash "$root/scripts/setup-consumer.sh"
cat <<EOF

Próximos passos:
  preencha .ia/PROJECT_BRIEF.md e .ia/PROJECT_GUIDE.md
  git add .gitmodules .ia/shared .ia .codex .agents AGENTS.md AGENTS_backup.md
EOF
