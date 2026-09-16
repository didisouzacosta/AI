#!/usr/bin/env bash

set -euo pipefail

remote_url="${AI_BASE_REMOTE:-https://github.com/didisouzacosta/AI.git}"
shared_path="ai/shared"
branch="main"

usage() {
  cat <<'EOF'
Uso: setup-consumer.sh [--update]

Instala a base AI como submodule em ai/shared e cria os links dos arquivos
compartilhados. PROJECT_BRIEF.md e PROJECT_GUIDE.md são sempre locais ao
projeto consumidor e só são criados a partir dos templates quando ausentes.

Opções:
  --update             atualiza ai/shared para a versão mais recente de main
  --migrate-existing   move cópias compartilhadas para backup e cria os links
EOF
}

update_dependency=false
migrate_existing=false
for argument in "$@"; do
  case "$argument" in
    --update)
      update_dependency=true
      ;;
    --migrate-existing)
      migrate_existing=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

project_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Erro: execute este script dentro da raiz de um projeto Git consumidor." >&2
  exit 1
}
cd "$project_root"

if git config -f .gitmodules --get "submodule.${shared_path}.path" >/dev/null 2>&1; then
  git submodule update --init "$shared_path"
else
  if [[ -e "$shared_path" ]]; then
    echo "Erro: '$shared_path' já existe e não está configurado como submodule." >&2
    exit 1
  fi
  git submodule add -b "$branch" "$remote_url" "$shared_path"
fi

if [[ "$update_dependency" == true ]]; then
  if [[ -n "$(git -C "$shared_path" status --porcelain)" ]]; then
    echo "Erro: o submodule '$shared_path' possui alterações locais." >&2
    echo "Finalize ou preserve essas alterações antes de usar --update." >&2
    exit 1
  fi

  git -C "$shared_path" fetch origin "$branch"
  if git -C "$shared_path" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$shared_path" switch "$branch"
  else
    git -C "$shared_path" switch --create "$branch" --track "origin/$branch"
  fi
  git -C "$shared_path" pull --ff-only origin "$branch"
fi

required_files=(
  "AGENTS.md"
  "ai/CODEX_ORCHESTRATOR.md"
  "ai/SWIFT_REFERENCE.md"
)
for file in "${required_files[@]}"; do
  if [[ ! -f "$shared_path/$file" ]]; then
    echo "Erro: a dependência não contém '$file'." >&2
    exit 1
  fi
done

mkdir -p ai

backup_directory=""
prepare_backup_directory() {
  if [[ -z "$backup_directory" ]]; then
    backup_directory=".ai-base-migration-backup/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_directory"
  fi
}

link_shared_file() {
  local source="$1"
  local destination="$2"

  if [[ -L "$destination" ]]; then
    return 0
  fi
  if [[ -e "$destination" ]]; then
    if [[ "$migrate_existing" != true ]]; then
      echo "Preservado: '$destination' já existe; use --migrate-existing para migrá-lo."
      return 0
    fi
    prepare_backup_directory
    mkdir -p "$backup_directory/$(dirname "$destination")"
    mv "$destination" "$backup_directory/$destination"
    echo "Backup: '$destination' -> '$backup_directory/$destination'"
  fi

  ln -s "../shared/$source" "$destination"
}

if [[ ! -L "AGENTS.md" && -e "AGENTS.md" && "$migrate_existing" == true ]]; then
  prepare_backup_directory
  mv "AGENTS.md" "$backup_directory/AGENTS.md"
  echo "Backup: 'AGENTS.md' -> '$backup_directory/AGENTS.md'"
fi
if [[ ! -e "AGENTS.md" ]]; then
  ln -s "ai/shared/AGENTS.md" "AGENTS.md"
elif [[ ! -L "AGENTS.md" ]]; then
  echo "Preservado: 'AGENTS.md' já existe; use --migrate-existing para migrá-lo."
fi
link_shared_file "ai/CODEX_ORCHESTRATOR.md" "ai/CODEX_ORCHESTRATOR.md"
link_shared_file "ai/SWIFT_REFERENCE.md" "ai/SWIFT_REFERENCE.md"

if [[ -L "ai/skills" ]]; then
  :
elif [[ -e "ai/skills" ]]; then
  if [[ "$migrate_existing" == true ]]; then
    prepare_backup_directory
    mkdir -p "$backup_directory/ai"
    mv "ai/skills" "$backup_directory/ai/skills"
    ln -s "shared/ai/skills" "ai/skills"
    echo "Backup: 'ai/skills' -> '$backup_directory/ai/skills'"
  else
    echo "Preservado: 'ai/skills' já existe; use --migrate-existing para migrá-lo."
  fi
else
  ln -s "shared/ai/skills" "ai/skills"
fi

if [[ -L "ai/agents" ]]; then
  :
elif [[ -e "ai/agents" ]]; then
  if [[ "$migrate_existing" == true ]]; then
    prepare_backup_directory
    mkdir -p "$backup_directory/ai"
    mv "ai/agents" "$backup_directory/ai/agents"
    ln -s "shared/ai/agents" "ai/agents"
    echo "Backup: 'ai/agents' -> '$backup_directory/ai/agents'"
  else
    echo "Preservado: 'ai/agents' já existe; use --migrate-existing para migrá-lo."
  fi
else
  ln -s "shared/ai/agents" "ai/agents"
fi

for document in PROJECT_BRIEF PROJECT_GUIDE; do
  local_document="ai/${document}.md"
  template="${shared_path}/ai/${document}.template.md"

  if [[ -e "$local_document" ]]; then
    echo "Preservado: '$local_document' é específico deste projeto."
  else
    cp "$template" "$local_document"
    echo "Criado: '$local_document' a partir do template compartilhado."
  fi
done

cat <<'EOF'

Base AI configurada.

Para registrar a versão no projeto consumidor:
  git add .gitmodules ai/shared AGENTS.md ai
  git commit -m "chore: adiciona base compartilhada de IA"

Para atualizar a dependência:
  ai/shared/scripts/setup-consumer.sh --update
  git add ai/shared
  git commit -m "chore: atualiza base compartilhada de IA"
EOF

if [[ -n "$backup_directory" ]]; then
  echo ""
  echo "Arquivos compartilhados anteriores foram preservados em '$backup_directory'."
  echo "Revise o backup e não o adicione ao commit do projeto consumidor."
fi
