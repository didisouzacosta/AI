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
  preencha .ai/PROJECT_BRIEF.md e .ai/PROJECT_GUIDE.md
  execute scripts/lint-swift.sh localmente e conecte-o ao CI do consumidor
  git add .gitmodules .ai/shared .ai .codex .agents .swiftlint.yml .swift-format scripts/lint-swift.sh scripts/test-required-class-marks.sh .github/workflows/swift-lint.yml AGENTS.md AGENTS_backup.md
EOF
