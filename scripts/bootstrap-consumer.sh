#!/usr/bin/env bash
set -euo pipefail
source="${BASH_SOURCE[0]}"
while [[ -L "$source" ]]; do d="$(cd "$(dirname "$source")" && pwd)"; target="$(readlink "$source")"; [[ "$target" = /* ]] && source="$target" || source="$d/$target"; done
root="$(cd "$(dirname "$source")/.." && pwd)"
# Keep the local AI checkout on the latest main before running (see self-update-base.sh).
[[ ! -f "$root/scripts/self-update-base.sh" ]] || { . "$root/scripts/self-update-base.sh"; self_update_base "$root" "$source" "$@"; }
usage() { echo "Uso: ai-bootstrap [--adopt-lint-config] [CAMINHO_DO_PROJETO]"; }
setup_args=(); path=""
for arg in "$@"; do case "$arg" in --adopt-lint-config) setup_args+=("$arg");; -*) usage >&2; exit 2;; *) [[ -z "$path" ]] || { usage >&2; exit 2; }; path="$arg";; esac; done
path="${path:-.}"
project="$(cd "$path" 2>/dev/null && git rev-parse --show-toplevel)" || { echo "Erro: '$path' deve estar em um projeto Git." >&2; exit 1; }
cd "$project"
bash "$root/scripts/setup-consumer.sh" ${setup_args[@]+"${setup_args[@]}"}
echo
echo "Próximos passos:"
echo "  preencha .ai/PROJECT_BRIEF.md e .ai/PROJECT_GUIDE.md"
# Printed from the freshly updated submodule so the guidance matches the installed files.
[ ! -f .ai/shared/scripts/consumer-next-steps.txt ] || cat .ai/shared/scripts/consumer-next-steps.txt
