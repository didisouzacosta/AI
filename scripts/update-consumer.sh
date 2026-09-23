#!/usr/bin/env bash
set -euo pipefail
[[ $# -le 1 ]] || { echo "Uso: ai-update [CAMINHO_DO_PROJETO]" >&2; exit 2; }
path="${1:-.}"; source="${BASH_SOURCE[0]}"
while [[ -L "$source" ]]; do d="$(cd "$(dirname "$source")" && pwd)"; target="$(readlink "$source")"; [[ "$target" = /* ]] && source="$target" || source="$d/$target"; done
root="$(cd "$(dirname "$source")/.." && pwd)"
project="$(cd "$path" 2>/dev/null && git rev-parse --show-toplevel)" || { echo "Erro: '$path' deve estar em um projeto Git." >&2; exit 1; }
[[ ! -e "$project/ai" && ! -L "$project/ai" ]] || { echo "Erro: layout legado ai detectado; faça a migração manual." >&2; exit 1; }
[[ -d "$project/.ai/shared" ]] || { echo "Erro: .ai/shared não está configurado; execute ai-bootstrap." >&2; exit 1; }
cd "$project"
bash "$root/scripts/setup-consumer.sh" --update
echo "Dependência AI atualizada. Revise e registre .ai/shared, .ai/managed-files.sha256, .codex, .agents, .swiftlint.yml, .swift-format, scripts de lint e o workflow Swift."
