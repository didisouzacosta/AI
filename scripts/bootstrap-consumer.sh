#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Uso: bootstrap-consumer.sh [--migrate-existing] [CAMINHO_DO_PROJETO]

Configura um projeto consumidor em uma única operação:
  1. instala os subagents Manager e Developer no diretório do Codex;
  2. adiciona/configura a base AI como submodule no projeto;
  3. preserva PROJECT_BRIEF.md e PROJECT_GUIDE.md no projeto consumidor.

Opções:
  --migrate-existing   migra cópias existentes dos arquivos compartilhados
                       para links, preservando-as em backups

Variáveis opcionais:
  CODEX_CONFIG_DIR     diretório da configuração do Codex (padrão: ~/.codex)
  AI_BASE_REMOTE       remote da base AI usado pelo submodule
EOF
}

migrate_existing=false
project_argument=""
for argument in "$@"; do
  case "$argument" in
    --migrate-existing)
      migrate_existing=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      usage >&2
      exit 2
      ;;
    *)
      if [[ -n "$project_argument" ]]; then
        usage >&2
        exit 2
      fi
      project_argument="$argument"
      ;;
  esac
done

if [[ -z "$project_argument" ]]; then
  project_argument="."
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
codex_config_dir="${CODEX_CONFIG_DIR:-$(printf '%s' ~)/.codex}"
agents_directory="$codex_config_dir/agents"

if [[ ! -f "$script_root/ai/agents/Manager.toml" || ! -f "$script_root/ai/agents/Developer.toml" ]]; then
  echo "Erro: execute este script a partir de uma cópia completa da base AI." >&2
  exit 1
fi

project_root="$(cd -- "$project_argument" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Erro: '$project_argument' deve existir e ser a raiz ou uma subpasta de um projeto Git." >&2
  exit 1
}

mkdir -p "$agents_directory"
backup_directory=""
prepare_backup_directory() {
  if [[ -z "$backup_directory" ]]; then
    backup_directory="$agents_directory/.ai-base-migration-backup/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_directory"
  fi
}

install_agent_link() {
  local agent_name="$1"
  local source="$script_root/ai/agents/$agent_name.toml"
  local destination="$agents_directory/$agent_name.toml"

  if [[ -L "$destination" && "$(readlink "$destination")" == "$source" ]]; then
    echo "Já configurado: '$destination'"
    return 0
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    prepare_backup_directory
    mv "$destination" "$backup_directory/$agent_name.toml"
    echo "Backup: '$destination' -> '$backup_directory/$agent_name.toml'"
  fi

  ln -s "$source" "$destination"
  echo "Instalado: '$destination' -> '$source'"
}

install_agent_link Manager
install_agent_link Developer

cd "$project_root"
if [[ "$migrate_existing" == true ]]; then
  bash "$script_root/scripts/setup-consumer.sh" --migrate-existing
else
  bash "$script_root/scripts/setup-consumer.sh"
fi

cat <<EOF

Projeto configurado: $project_root
Subagents configurados em: $agents_directory

Próximos passos:
  cd "$project_root"
  git add .gitmodules ai AGENTS.md
  git commit -m "chore: configura base compartilhada de IA"
EOF

if [[ -n "$backup_directory" ]]; then
  echo "Backups dos subagents anteriores: '$backup_directory'"
  echo "Revise-os e não os adicione ao commit."
fi
