#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Uso: update-consumer.sh [CAMINHO_DO_PROJETO]

Atualiza o submodule ai/shared para a versão mais recente de main e valida os
links compartilhados. PROJECT_BRIEF.md e PROJECT_GUIDE.md não são
alterados. Se o projeto ainda usa o layout legado ai -> .ai-project, execute
ai-bootstrap primeiro para preservar a cópia de recuperação antes da atualização.
EOF
}

project_argument="${1:-.}"
if [[ "$project_argument" == "-h" || "$project_argument" == "--help" ]]; then
  usage
  exit 0
fi
if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

source_path="${BASH_SOURCE[0]}"
while [[ -L "$source_path" ]]; do
  source_directory="$(cd -- "$(dirname -- "$source_path")" && pwd)"
  linked_path="$(readlink "$source_path")"
  if [[ "$linked_path" == /* ]]; then
    source_path="$linked_path"
  else
    source_path="$source_directory/$linked_path"
  fi
done
script_root="$(cd -- "$(dirname -- "$source_path")/.." && pwd)"

normalize_link_target() {
  local link_path="$1"
  local target=""
  local target_directory=""
  local target_base=""
  local parent_directory=""
  target="$(readlink "$link_path")" || return 1
  if [[ "$target" == /* ]]; then
    target_directory="$(dirname -- "$target")"
    target_base="$(basename -- "$target")"
  else
    target_directory="$(dirname -- "$link_path")/$(dirname -- "$target")"
    target_base="$(basename -- "$target")"
  fi
  parent_directory="$(cd -P -- "$target_directory" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s\n' "$parent_directory" "$target_base"
}

project_root="$(cd -- "$project_argument" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Erro: '$project_argument' deve existir e ser um projeto Git." >&2
  exit 1
}

if [[ -L "$project_root/ai" ]]; then
  legacy_target="$(normalize_link_target "$project_root/ai" 2>/dev/null || true)"
  if [[ -e "$project_root/ai" && "$legacy_target" == "$project_root/.ai-project" ]]; then
    echo "Erro: o projeto ainda usa o layout legado 'ai -> .ai-project'." >&2
    echo "Diagnóstico: ai-update não atualiza esse layout para evitar escrever através do symlink." >&2
    echo "Recuperação: execute ai-bootstrap no projeto; '.ai-project' será preservado." >&2
    exit 1
  fi
  if [[ ! -e "$project_root/ai" ]]; then
    echo "Erro: o link 'ai' está quebrado; corrija o layout antes de atualizar." >&2
    exit 1
  fi
fi

if [[ ! -d "$project_root/ai/shared" ]]; then
  echo "Erro: o projeto não possui o submodule 'ai/shared'. Execute ai-bootstrap primeiro." >&2
  exit 1
fi

cd "$project_root"
bash "$script_root/scripts/setup-consumer.sh" --update

cat <<EOF

Dependência AI atualizada em: $project_root

Revise e registre a nova versão no projeto consumidor:
  git status
  git add ai/shared ai/CODEX_ORCHESTRATOR.md ai/SWIFT_REFERENCE.md
  git commit -m "chore: atualiza base compartilhada de IA"
EOF
