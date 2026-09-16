#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
user_home="$(printf '%s' ~)"
bin_directory="${AI_BIN_DIR:-$user_home/.local/bin}"
command_path="$bin_directory/ai-bootstrap"
source_path="$script_root/scripts/bootstrap-consumer.sh"

if [[ ! -x "$source_path" ]]; then
  echo "Erro: não encontrei o bootstrap executável em '$source_path'." >&2
  exit 1
fi

mkdir -p "$bin_directory"
bin_directory="$(cd -- "$bin_directory" && pwd)"
command_path="$bin_directory/ai-bootstrap"

if [[ -L "$command_path" && "$(readlink "$command_path")" == "$source_path" ]]; then
  echo "Comando já instalado: '$command_path'"
else
  if [[ -e "$command_path" || -L "$command_path" ]]; then
    echo "Erro: '$command_path' já existe e não aponta para esta base AI." >&2
    echo "Remova-o ou defina AI_BIN_DIR para outro diretório." >&2
    exit 1
  fi
  ln -s "$source_path" "$command_path"
  echo "Comando instalado: '$command_path'"
fi

ensure_zsh_path() {
  local profile_path="$1"
  local path_line="export PATH=\"$bin_directory:\$PATH\""

  if [[ -f "$profile_path" ]] && grep -Fqx "$path_line" "$profile_path"; then
    echo "PATH já configurado em '$profile_path'"
    return 0
  fi

  if [[ -s "$profile_path" ]]; then
    printf '\n' >> "$profile_path"
  fi
  printf '%s\n' "$path_line" >> "$profile_path"
  echo "PATH configurado em '$profile_path'"
}

case ":${PATH}:" in
  *":$bin_directory:"*)
    echo "O diretório já está no PATH desta sessão."
    ;;
  *)
    ensure_zsh_path "$user_home/.zprofile"
    ensure_zsh_path "$user_home/.zshrc"
    echo "O PATH será carregado automaticamente nas próximas sessões do zsh."
    echo "Para disponibilizar agora nesta sessão, execute:"
    echo "  export PATH=\"$bin_directory:\$PATH\""
    echo "Feche e abra o terminal para carregar o comando automaticamente."
  ;;
esac

echo "Use: ai-bootstrap ."
