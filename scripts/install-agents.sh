#!/usr/bin/env bash

set -euo pipefail

source_path="${BASH_SOURCE[0]}"
while [[ -L "$source_path" ]]; do
  source_directory="$(cd -P -- "$(dirname -- "$source_path")" && pwd -P)"
  linked_path="$(readlink "$source_path")"
  if [[ "$linked_path" == /* ]]; then
    source_path="$linked_path"
  else
    source_path="$source_directory/$linked_path"
  fi
done
script_root="$(cd -P -- "$(dirname -- "$source_path")/.." && pwd -P)"

codex_config_dir="${CODEX_CONFIG_DIR:-$(printf '%s' ~)/.codex}"
agents_directory="$codex_config_dir/agents"
backup_parent="$codex_config_dir/agent-migration-backups"
backup_directory=""
manager_source="$script_root/ai/agents/ai_manager.toml"
developer_source="$script_root/ai/agents/ai_developer.toml"

die() {
  echo "Erro: $*" >&2
  exit 1
}

for source in "$manager_source" "$developer_source"; do
  [[ -f "$source" && ! -L "$source" ]] || die "fontes dos agents ausentes ou inválidas: '$source'."
done

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

is_expected_link() {
  local link_path="$1"
  local expected_source="$2"
  local normalized=""

  [[ -L "$link_path" ]] || return 1
  normalized="$(normalize_link_target "$link_path" 2>/dev/null)" || return 1
  [[ "$normalized" == "$expected_source" ]]
}

manager_legacy_source="$script_root/ai/agents/Manager.toml"
developer_legacy_source="$script_root/ai/agents/Developer.toml"
manager_legacy_link=false
developer_legacy_link=false
manager_destination="$agents_directory/ai_manager.toml"
developer_destination="$agents_directory/ai_developer.toml"

if [[ -L "$agents_directory" ]]; then
  die "o diretório de agentes '$agents_directory' é um symlink; verifique o destino manualmente."
fi
if [[ -e "$agents_directory" && ! -d "$agents_directory" ]]; then
  die "o destino '$agents_directory' existe e não é um diretório."
fi

if [[ -L "$agents_directory/Manager.toml" ]]; then
  normalized="$(normalize_link_target "$agents_directory/Manager.toml" 2>/dev/null || true)"
  if [[ "$normalized" == "$manager_legacy_source" ]]; then
    manager_legacy_link=true
  else
    echo "Preservado link legado de terceiros: '$agents_directory/Manager.toml'"
  fi
elif [[ -e "$agents_directory/Manager.toml" ]]; then
  echo "Preservado destino legado existente: '$agents_directory/Manager.toml'"
fi

if [[ -L "$agents_directory/Developer.toml" ]]; then
  normalized="$(normalize_link_target "$agents_directory/Developer.toml" 2>/dev/null || true)"
  if [[ "$normalized" == "$developer_legacy_source" ]]; then
    developer_legacy_link=true
  else
    echo "Preservado link legado de terceiros: '$agents_directory/Developer.toml'"
  fi
elif [[ -e "$agents_directory/Developer.toml" ]]; then
  echo "Preservado destino legado existente: '$agents_directory/Developer.toml'"
fi

backup_needed=false
for destination in "$manager_destination" "$developer_destination"; do
  expected_source="$manager_source"
  [[ "$destination" == "$developer_destination" ]] && expected_source="$developer_source"
  if ! is_expected_link "$destination" "$expected_source" && [[ -e "$destination" || -L "$destination" ]]; then
    backup_needed=true
  fi
done
if [[ "$manager_legacy_link" == true || "$developer_legacy_link" == true ]]; then
  backup_needed=true
fi

if [[ "$backup_needed" == true ]]; then
  if [[ -L "$backup_parent" ]]; then
    die "o diretório pai de backup '$backup_parent' é um symlink; nenhuma migração foi iniciada."
  fi
  if [[ -e "$backup_parent" && ! -d "$backup_parent" ]]; then
    die "o caminho de backup '$backup_parent' existe e não é um diretório; nenhuma migração foi iniciada."
  fi
fi

if ! mkdir -p "$agents_directory"; then
  die "não foi possível criar o diretório de agents '$agents_directory'."
fi
[[ ! -L "$agents_directory" && -d "$agents_directory" ]] || die "o diretório de agents '$agents_directory' mudou durante a validação."

prepare_backup_directory() {
  if [[ -n "$backup_directory" ]]; then
    return 0
  fi
  if [[ -L "$backup_parent" || ( -e "$backup_parent" && ! -d "$backup_parent" ) ]]; then
    die "o caminho de backup '$backup_parent' mudou e não é seguro."
  fi
  if ! mkdir -p "$backup_parent"; then
    die "não foi possível criar o diretório pai de backup '$backup_parent'."
  fi
  [[ ! -L "$backup_parent" && -d "$backup_parent" ]] || die "o diretório pai de backup '$backup_parent' não é um diretório seguro."
  backup_directory="$(mktemp -d "$backup_parent/migration.XXXXXXXX")" || die "não foi possível criar um diretório exclusivo de backup em '$backup_parent'."
  [[ ! -L "$backup_directory" && -d "$backup_directory" ]] || die "o diretório exclusivo de backup '$backup_directory' não é seguro."
}

install_agent_link() {
  local destination="$1"
  local source="$2"
  local name="$3"

  if is_expected_link "$destination" "$source"; then
    echo "Agent já configurado: '$destination'"
    return 0
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    prepare_backup_directory
    if ! mv "$destination" "$backup_directory/$name"; then
      die "não foi possível mover o conflito '$destination' para backup; os dados originais foram preservados."
    fi
    echo "Backup: '$destination' -> '$backup_directory/$name'"
  fi

  if ! ln -s "$source" "$destination"; then
    die "não foi possível criar o link do agent '$destination'; backups anteriores foram preservados."
  fi
  echo "Agent instalado: '$destination' -> '$source'"
}

archive_owned_legacy_link() {
  local destination="$1"
  local expected_source="$2"
  local name="$3"
  local normalized=""

  [[ -L "$destination" ]] || return 0
  normalized="$(normalize_link_target "$destination" 2>/dev/null || true)"
  [[ "$normalized" == "$expected_source" ]] || return 0

  prepare_backup_directory
  if ! mv "$destination" "$backup_directory/$name"; then
    die "não foi possível arquivar o link legado '$destination'; o link original foi preservado."
  fi
  echo "Link legado próprio arquivado: '$destination' -> '$backup_directory/$name'"
}

install_agent_link "$manager_destination" "$manager_source" ai_manager.toml
install_agent_link "$developer_destination" "$developer_source" ai_developer.toml
archive_owned_legacy_link "$agents_directory/Manager.toml" "$manager_legacy_source" Manager.toml
archive_owned_legacy_link "$agents_directory/Developer.toml" "$developer_legacy_source" Developer.toml

echo "Agents globais configurados em: $agents_directory"
if [[ -n "$backup_directory" ]]; then
  echo "Recuperação: os destinos substituídos e links próprios antigos foram preservados em '$backup_directory'."
fi
