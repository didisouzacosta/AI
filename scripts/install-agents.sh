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
manager_source="$script_root/ai/agents/ai_manager.toml"
developer_source="$script_root/ai/agents/ai_developer.toml"
temporary_file=""

die() {
  echo "Erro: $*" >&2
  exit 1
}

cleanup_temporary_file() {
  if [[ -n "$temporary_file" && -e "$temporary_file" && ! -L "$temporary_file" ]]; then
    rm -f -- "$temporary_file"
  fi
}
trap cleanup_temporary_file EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

for source in "$manager_source" "$developer_source"; do
  [[ -f "$source" && ! -L "$source" ]] || die "fontes dos agents ausentes ou inválidas: '$source'."
done

if [[ -L "$agents_directory" ]]; then
  die "o diretório de agents '$agents_directory' é um symlink; use uma configuração local limpa."
fi
if [[ -e "$agents_directory" && ! -d "$agents_directory" ]]; then
  die "o destino '$agents_directory' existe e não é um diretório."
fi
if ! mkdir -p "$agents_directory"; then
  die "não foi possível criar o diretório de agents '$agents_directory'."
fi
[[ ! -L "$agents_directory" && -d "$agents_directory" ]] || die "o diretório de agents '$agents_directory' mudou durante a validação."

install_agent_file() {
  local destination="$1"
  local source="$2"

  if [[ -L "$destination" || ( -e "$destination" && ! -f "$destination" ) ]]; then
    die "o destino canônico '$destination' não é um arquivo regular; limpe a configuração local antes de instalar."
  fi
  if [[ -f "$destination" ]] && cmp -s "$destination" "$source"; then
    echo "Agent já configurado: '$destination'"
    return 0
  fi

  temporary_file="$(mktemp "$agents_directory/.agent.XXXXXXXX")" || die "não foi possível preparar a cópia temporária do agent '$destination'."
  if ! cp "$source" "$temporary_file"; then
    die "não foi possível copiar o agent '$source'; o destino existente foi preservado."
  fi
  if ! cmp -s "$temporary_file" "$source"; then
    die "a fonte '$source' mudou durante a cópia; o destino existente foi preservado."
  fi
  if [[ -L "$agents_directory" || ! -d "$agents_directory" ]]; then
    die "o diretório de agents '$agents_directory' mudou durante a instalação."
  fi
  if [[ -L "$destination" || ( -e "$destination" && ! -f "$destination" ) ]]; then
    die "o destino canônico '$destination' mudou durante a instalação."
  fi
  if ! mv -f "$temporary_file" "$destination"; then
    die "não foi possível publicar a cópia do agent '$destination'; o destino anterior foi preservado."
  fi
  temporary_file=""
  echo "Agent instalado como cópia regular: '$destination'"
}

install_agent_file "$agents_directory/ai_manager.toml" "$manager_source"
install_agent_file "$agents_directory/ai_developer.toml" "$developer_source"

echo "Agents globais configurados em: $agents_directory"
