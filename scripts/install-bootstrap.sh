#!/usr/bin/env bash

set -euo pipefail

script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
user_home="$(printf '%s' ~)"
bin_directory="${AI_BIN_DIR:-$user_home/.local/bin}"
command_path="$bin_directory/ai-bootstrap"
source_path="$script_root/scripts/bootstrap-consumer.sh"
update_source_path="$script_root/scripts/update-consumer.sh"

if [[ ! -x "$source_path" || ! -x "$update_source_path" ]]; then
  echo "Erro: não encontrei os comandos bootstrap/update executáveis na base AI." >&2
  exit 1
fi

mkdir -p "$bin_directory"
bin_directory="$(cd -- "$bin_directory" && pwd)"
command_path="$bin_directory/ai-bootstrap"

install_command_link() {
  local command_name="$1"
  local command_source="$2"
  local command_target="$bin_directory/$command_name"

  if [[ -L "$command_target" && "$(readlink "$command_target")" == "$command_source" ]]; then
    echo "Comando já instalado: '$command_target'"
    return 0
  fi
  if [[ -e "$command_target" || -L "$command_target" ]]; then
    echo "Erro: '$command_target' já existe e não aponta para esta base AI." >&2
    echo "Remova-o ou defina AI_BIN_DIR para outro diretório." >&2
    exit 1
  fi
  ln -s "$command_source" "$command_target"
  echo "Comando instalado: '$command_target'"
}

install_command_link ai-bootstrap "$source_path"
install_command_link ai-update "$update_source_path"

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

echo "Use: ai-bootstrap para configurar um projeto."
echo "Use: ai-update para atualizar um projeto configurado."
