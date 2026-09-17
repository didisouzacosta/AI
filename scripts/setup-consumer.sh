#!/usr/bin/env bash

set -euo pipefail

remote_url="${AI_BASE_REMOTE:-https://github.com/didisouzacosta/AI.git}"
shared_path="ai/shared"
branch="main"
update_dependency=false
migrate_existing=false
project_root=""
lock_directory=""
lock_owned=false
staging_directory=""
gitmodules_index_file=""
phase_name="preflight"
backup_directory=""
legacy_ai=false
legacy_ai_tracked=false
legacy_root_agents_allowed=false
legacy_root_agents_target=""
legacy_link_records=""
mutation_started=false

usage() {
  cat <<'EOF'
Uso: setup-consumer.sh [--update] [--migrate-existing]

Configura a base AI como submodule em ai/shared e cria os links canônicos.
Um layout legado em que ai é um link direto para .ai-project é migrado
automaticamente, preservando .ai-project e os arquivos do projeto consumidor.
PROJECT_BRIEF.md e PROJECT_GUIDE.md são sempre locais ao projeto.

Opções:
  --update             atualiza ai/shared para a versão mais recente de main
  --migrate-existing   move cópias reais compartilhadas para backup antes
                       de criar os links canônicos
EOF
}

die() {
  echo "Erro: $*" >&2
  exit 1
}

phase() {
  phase_name="$1"
  if [[ "$lock_owned" == true && -n "$lock_directory" && -d "$lock_directory" ]]; then
    printf '%s\n' "$phase_name" > "$lock_directory/phase"
  fi
}

cleanup() {
  local status="$1"
  if [[ "$status" -ne 0 ]]; then
    if [[ "$mutation_started" == false ]]; then
      echo "Preflight falhou na fase '$phase_name'; nenhuma mutação foi aplicada." >&2
    else
      echo "Falha na fase '$phase_name'; o checkout pode estar em estado parcial." >&2
      echo "Os dados existentes foram preservados e nenhum rollback automático foi aplicado." >&2
    fi
    echo "Verifique o projeto antes de repetir." >&2
  fi

  if [[ -n "$staging_directory" && -d "$staging_directory" ]]; then
    rm -rf "$staging_directory"
  fi
  if [[ -n "$gitmodules_index_file" && -f "$gitmodules_index_file" ]]; then
    rm -f "$gitmodules_index_file"
  fi
  if [[ "$lock_owned" == true && -n "$lock_directory" && -d "$lock_directory" ]]; then
    rm -rf "$lock_directory"
  fi
  exit "$status"
}

on_signal() {
  echo "Interrupção recebida; encerrando sem apagar a cópia de recuperação." >&2
  exit 130
}

trap 'cleanup $?' EXIT
trap 'on_signal' INT TERM

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

lock_directory="$project_root/.ai-base-setup.lock"
if ! mkdir "$lock_directory" 2>/dev/null; then
  die "já existe um lock em '$lock_directory'; outra configuração pode estar em andamento ou precisa ser recuperada manualmente."
fi
lock_owned=true
chmod 700 "$lock_directory"
phase preflight

normalize_link_target() {
  local link_path="$1"
  local target target_directory target_base parent_directory

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

path_is_inside() {
  local path="$1"
  local root="$2"
  [[ "$path" == "$root" || "$path" == "$root"/* ]]
}

normalize_existing_path() {
  local path="$1"
  local path_directory=""
  local path_base=""

  if [[ "$path" == /* ]]; then
    path_directory="$(dirname -- "$path")"
    path_base="$(basename -- "$path")"
  else
    path_directory="$(dirname -- "$path")"
    path_base="$(basename -- "$path")"
  fi
  path_directory="$(cd -P -- "$path_directory" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s\n' "$path_directory" "$path_base"
}

is_known_legacy_link() {
  local destination="$1"
  local expected_local_root="$project_root/.ai-project"
  local normalized=""
  local codex_agents=""

  normalized="$(normalize_link_target "$destination" 2>/dev/null)" || return 1
  if [[ "$destination" == "$project_root/AGENTS.md" ]]; then
    codex_agents="${HOME:-}/.codex/AGENTS.md"
    if [[ -n "${HOME:-}" ]]; then
      if [[ "$normalized" == "$codex_agents" ]]; then
        return 0
      fi
    fi
  fi

  if path_is_inside "$normalized" "$expected_local_root"; then
    return 0
  fi
  return 1
}

validate_no_special_files() {
  local source_directory="$1"
  local special_path=""
  special_path="$(find "$source_directory" \( -type b -o -type c -o -type p -o -type s \) -print -quit 2>/dev/null)" || {
    die "não foi possível inspecionar '$source_directory' com segurança."
  }
  if [[ -n "$special_path" ]]; then
    die "o layout legado contém arquivo especial não preservável: '$special_path'."
  fi
}

validate_ai_layout() {
  local ai_path="$project_root/ai"
  local target=""
  local index_entries=""
  local index_mode=""
  local index_path=""

  if [[ -L "$ai_path" ]]; then
    [[ -e "$ai_path" ]] || die "'ai' é um link quebrado; recuperação manual necessária antes do setup."
    target="$(normalize_link_target "$ai_path" 2>/dev/null)" || die "não foi possível normalizar o destino de 'ai'."
    [[ "$target" == "$project_root/.ai-project" ]] || die "'ai' aponta para '$target'; somente o link direto para '$project_root/.ai-project' é migrado automaticamente."
    [[ -d "$project_root/.ai-project" && ! -L "$project_root/.ai-project" ]] || die "'.ai-project' precisa ser um diretório real, sem encadeamento de links."
    validate_no_special_files "$project_root/.ai-project"
    legacy_ai=true

    index_entries="$(git ls-files --stage -- ai 2>/dev/null || true)"
    if [[ -n "$index_entries" ]]; then
      index_mode="$(printf '%s\n' "$index_entries" | awk 'NR == 1 { print $1 }')"
      index_path="$(printf '%s\n' "$index_entries" | awk 'NR == 1 { print $4 }')"
      [[ "$index_mode" == "120000" && "$index_path" == "ai" ]] || die "a entrada rastreada de 'ai' não é exclusivamente o symlink legado esperado."
      [[ "$(printf '%s\n' "$index_entries" | wc -l | tr -d ' ')" == "1" ]] || die "há entradas Git adicionais sob o symlink legado 'ai'; o índice não será alterado."
      legacy_ai_tracked=true
    fi
  elif [[ -e "$ai_path" ]]; then
    [[ -d "$ai_path" ]] || die "'ai' existe mas não é um diretório real."
    [[ ! -L "$ai_path" ]] || die "'ai' possui um encadeamento de links ambíguo."
  fi
}

validate_git_layout() {
  local configured_path=""
  local configured_url=""
  local configured_branch=""
  local entries=""
  local mode=""
  local entry_path=""
  local key=""
  local path_value=""
  local metadata_key=""
  local metadata_value=""

  if [[ -L "$project_root/.gitmodules" ]]; then
    die "'.gitmodules' é um link; a configuração não seguirá esse destino."
  fi

  if [[ -e "$project_root/.gitmodules" && ! -f "$project_root/.gitmodules" ]]; then
    die "'.gitmodules' precisa ser um arquivo regular."
  fi

  if [[ -f "$project_root/.gitmodules" ]]; then
    if ! git config -f .gitmodules --list >/dev/null 2>&1; then
      die "'.gitmodules' inválido; corrija a sintaxe antes do setup."
    fi
    while IFS=' ' read -r key path_value; do
      if [[ -n "$path_value" && "$path_value" == "$shared_path" && "$key" != "submodule.ai/shared.path" ]]; then
        die "'.gitmodules' possui uma seção conflitante para '$shared_path'."
      fi
    done <<EOF
$(gitmodules_get_regexp '\.path$')
EOF
    configured_path="$(gitmodules_get 'submodule.ai/shared.path')"
    configured_url="$(gitmodules_get 'submodule.ai/shared.url')"
    configured_branch="$(gitmodules_get 'submodule.ai/shared.branch')"
    while IFS=' ' read -r metadata_key metadata_value; do
      case "$metadata_key" in
        submodule.ai/shared.path|submodule.ai/shared.url|submodule.ai/shared.branch|submodule.ai/shared.update|submodule.ai/shared.fetchrecursesubmodules|submodule.ai/shared.ignore|submodule.ai/shared.shallow)
          ;;
        submodule.ai/shared.*)
          die "metadado desconhecido '$metadata_key' no submodule '$shared_path'."
          ;;
      esac
    done <<EOF
$(gitmodules_get_regexp '^submodule\.ai/shared\.')
EOF
    if [[ -z "$configured_path" && -n "$(gitmodules_get_regexp '^submodule\.ai/shared\.')" ]]; then
      die "'.gitmodules' possui metadados para '$shared_path' sem um path válido."
    fi
  fi

  while IFS=' ' read -r metadata_key metadata_value; do
    case "$metadata_key" in
      submodule.ai/shared.url|submodule.ai/shared.active|submodule.ai/shared.branch|submodule.ai/shared.update|submodule.ai/shared.fetchrecursesubmodules|submodule.ai/shared.ignore|submodule.ai/shared.shallow)
        ;;
      submodule.ai/shared.*)
        die "metadado Git local desconhecido '$metadata_key' no submodule '$shared_path'."
        ;;
    esac
  done <<EOF
$(git config --local --get-regexp '^submodule\.ai/shared\.' 2>/dev/null || true)
EOF

  entries="$(git ls-files --stage -- "$shared_path" 2>/dev/null || true)"
  if [[ -n "$configured_path" ]]; then
    [[ "$configured_path" == "$shared_path" && -n "$configured_url" ]] || die "metadados desconhecidos ou incompletos para o submodule '$shared_path'."
    [[ -z "$configured_branch" || "$configured_branch" == "$branch" ]] || die "o submodule '$shared_path' usa branch '$configured_branch', não '$branch'."
    [[ -n "$entries" ]] || die "'.gitmodules' declara '$shared_path', mas o gitlink não está no índice."
    mode="$(printf '%s\n' "$entries" | awk 'NR == 1 { print $1 }')"
    entry_path="$(printf '%s\n' "$entries" | awk 'NR == 1 { print $4 }')"
    [[ "$mode" == "160000" && "$entry_path" == "$shared_path" ]] || die "'$shared_path' possui uma entrada Git que não é um gitlink válido."
    [[ "$(printf '%s\n' "$entries" | wc -l | tr -d ' ')" == "1" ]] || die "há múltiplas entradas Git para '$shared_path'."
    if [[ -L "$project_root/$shared_path" ]]; then
      die "'$shared_path' é um symlink; o submodule precisa ser um diretório real."
    fi
    if [[ -e "$project_root/$shared_path" && ! -d "$project_root/$shared_path" ]]; then
      die "'$shared_path' existe mas não é um diretório de submodule."
    fi
    validate_existing_submodule
  else
    [[ -z "$entries" ]] || die "há um gitlink para '$shared_path' sem metadados correspondentes em '.gitmodules'."
    [[ ! -e "$project_root/$shared_path" && ! -L "$project_root/$shared_path" ]] || die "'$shared_path' já existe sem configuração válida de submodule."
  fi
}

validate_existing_submodule() {
  local submodule_root="$project_root/$shared_path"
  local git_marker="$submodule_root/.git"
  local project_git_common_dir=""
  local expected_git_dir=""
  local gitfile_line=""
  local gitfile_extra=""
  local gitfile_line_count=""
  local gitfile_target=""
  local actual_git_dir=""
  local actual_common_dir=""
  local actual_worktree=""

  if [[ ! -d "$submodule_root" || ( ! -e "$submodule_root/.git" && ! -L "$submodule_root/.git" ) ]]; then
    return 0
  fi
  [[ ! -L "$git_marker" ]] || die "o metadado .git de '$shared_path' é um symlink; a associação do submodule é ambígua."

  project_git_common_dir="$(git -C "$project_root" rev-parse --git-common-dir 2>/dev/null)" || die "não foi possível determinar o diretório Git comum do projeto consumidor."
  if [[ "$project_git_common_dir" != /* ]]; then
    project_git_common_dir="$project_root/$project_git_common_dir"
  fi
  project_git_common_dir="$(normalize_existing_path "$project_git_common_dir")" || die "não foi possível normalizar o diretório Git comum do projeto consumidor."
  expected_git_dir="$(normalize_existing_path "$project_git_common_dir/modules/$shared_path")" || die "não foi possível determinar os metadados esperados do submodule '$shared_path'."

  if [[ -f "$git_marker" ]]; then
    gitfile_line="$(sed -n '1p' "$git_marker")"
    gitfile_extra="$(sed -n '2p' "$git_marker")"
    gitfile_line_count="$(awk 'END { print NR }' "$git_marker")"
    [[ "$gitfile_line_count" == "1" && -n "$gitfile_line" && -z "$gitfile_extra" ]] || die "o gitfile de '$shared_path' é ambíguo; a associação do submodule não será seguida."
    [[ "$gitfile_line" == gitdir:* ]] || die "o gitfile de '$shared_path' é inválido; a associação do submodule não será seguida."
    gitfile_target="${gitfile_line#gitdir:}"
    gitfile_target="${gitfile_target#${gitfile_target%%[![:space:]]*}}"
    [[ -n "$gitfile_target" ]] || die "o gitfile de '$shared_path' não informa um gitdir."
    if [[ "$gitfile_target" != /* ]]; then
      gitfile_target="$submodule_root/$gitfile_target"
    fi
    gitfile_target="$(normalize_existing_path "$gitfile_target")" || die "não foi possível normalizar o gitfile de '$shared_path'."
    [[ "$gitfile_target" == "$expected_git_dir" ]] || die "o repositório existente em '$shared_path' possui um gitfile apontando para '$gitfile_target', fora da associação esperada '$expected_git_dir'."
elif [[ ! -d "$git_marker" ]]; then
    die "o metadado .git de '$shared_path' não é um diretório ou gitfile válido."
  fi

  if ! git -C "$shared_path" rev-parse --git-dir >/dev/null 2>&1; then
    die "o repositório existente em '$shared_path' é inválido; corrija o metadado .git antes do setup."
  fi
  actual_git_dir="$(git -C "$shared_path" rev-parse --git-dir 2>/dev/null)" || die "não foi possível ler o gitdir de '$shared_path'."
  if [[ "$actual_git_dir" != /* ]]; then
    actual_git_dir="$submodule_root/$actual_git_dir"
  fi
  actual_git_dir="$(normalize_existing_path "$actual_git_dir")" || die "não foi possível normalizar o gitdir de '$shared_path'."
  if [[ -f "$git_marker" ]]; then
    [[ "$actual_git_dir" == "$expected_git_dir" ]] || die "os metadados Git de '$shared_path' não estão associados ao submodule esperado."
  else
    [[ "$actual_git_dir" == "$(normalize_existing_path "$git_marker")" ]] || die "os metadados Git de '$shared_path' não pertencem ao seu worktree."
  fi
  actual_common_dir="$(git -C "$shared_path" rev-parse --git-common-dir 2>/dev/null)" || die "não foi possível ler o diretório Git comum de '$shared_path'."
  if [[ "$actual_common_dir" != /* ]]; then
    actual_common_dir="$submodule_root/$actual_common_dir"
  fi
  actual_common_dir="$(normalize_existing_path "$actual_common_dir")" || die "não foi possível normalizar o diretório Git comum de '$shared_path'."
  [[ "$actual_common_dir" == "$actual_git_dir" ]] || die "os metadados Git de '$shared_path' usam um worktree vinculado ambíguo."
  actual_worktree="$(git -C "$shared_path" rev-parse --show-toplevel 2>/dev/null)" || die "não foi possível determinar o worktree de '$shared_path'."
  actual_worktree="$(normalize_existing_path "$actual_worktree")" || die "não foi possível normalizar o worktree de '$shared_path'."
  [[ "$actual_worktree" == "$(normalize_existing_path "$submodule_root")" ]] || die "o worktree de '$shared_path' está associado a outro caminho."
  if ! git -C "$shared_path" status --porcelain >/dev/null 2>&1; then
    die "o repositório existente em '$shared_path' não pôde ser lido pelo Git."
  fi
}

gitmodules_without_target_section() {
  local config_file="$1"

  if ! git config -f "$config_file" --list >/dev/null 2>&1; then
    die "uma versão de '.gitmodules' é inválida; preserve-a ou corrija-a antes do setup."
  fi
  awk '
    function is_target_header(line) {
      return line ~ /^[[:space:]]*\[[Ss][Uu][Bb][Mm][Oo][Dd][Uu][Ll][Ee][[:space:]]+"ai\/shared"\][[:space:]]*([#;].*)?$/
    }

    /^[[:space:]]*\[/ {
      skip_target = is_target_header($0)
    }
    !skip_target { print }
  ' "$config_file"
}

gitmodules_has_external_submodule_section() {
  local config_file="$1"

  awk '
    function is_target_header(line) {
      return line ~ /^[[:space:]]*\[[Ss][Uu][Bb][Mm][Oo][Dd][Uu][Ll][Ee][[:space:]]+"ai\/shared"\][[:space:]]*([#;].*)?$/
    }

    /^[[:space:]]*\[[Ss][Uu][Bb][Mm][Oo][Dd][Uu][Ll][Ee][[:space:]]+"[^"]+"\][[:space:]]*([#;].*)?$/ {
      if (!is_target_header($0)) {
        found = 1
      }
    }

    END { exit !found }
  ' "$config_file"
}

validate_gitmodules_staging() {
  local staged_mode=""
  local staged_entries=""
  local worktree_entries=""

  staged_entries="$(git ls-files --stage -- .gitmodules 2>/dev/null || true)"
  if [[ ! -f "$project_root/.gitmodules" ]]; then
    if [[ -n "$staged_entries" ]]; then
      die "'.gitmodules' está presente no índice, mas ausente no worktree; preserve a divergência antes do setup."
    fi
    return 0
  fi
  if [[ -z "$staged_entries" ]]; then
    if ! git config -f "$project_root/.gitmodules" --list >/dev/null 2>&1; then
      die "'.gitmodules' inválido; corrija a sintaxe antes do setup."
    fi
    if gitmodules_has_external_submodule_section "$project_root/.gitmodules" || git config -f "$project_root/.gitmodules" --get-regexp '^submodule\.' 2>/dev/null | awk '$1 !~ /^submodule\.ai\/shared\./ { found = 1 } END { exit !found }'; then
      die "'.gitmodules' possui configuração de submodule alheia sem entrada no índice; preserve-a ou faça staging deliberado antes do setup."
    fi
    return 0
  fi

  staged_mode="$(printf '%s\n' "$staged_entries" | awk 'NR == 1 { print $1 }')"
  [[ "$staged_mode" == "100644" ]] || die "a entrada staged de '.gitmodules' não é um arquivo regular; preserve-a antes do setup."
  [[ "$(printf '%s\n' "$staged_entries" | wc -l | tr -d ' ')" == "1" ]] || die "há múltiplas entradas staged para '.gitmodules'; preserve a resolução antes do setup."
  gitmodules_index_file="$(mktemp "${TMPDIR:-/tmp}/ai-gitmodules.XXXXXX")" || die "não foi possível preparar a comparação staged de '.gitmodules'."
  git show :".gitmodules" > "$gitmodules_index_file" || die "não foi possível ler a versão staged de '.gitmodules'."
  staged_entries="$(gitmodules_without_target_section "$gitmodules_index_file")"
  worktree_entries="$(gitmodules_without_target_section "$project_root/.gitmodules")"
  if [[ "$staged_entries" != "$worktree_entries" ]]; then
    die "'.gitmodules' possui alterações staged e unstaged em seções fora de 'ai/shared'; preserve-as ou resolva a divergência antes do setup."
  fi
}

gitmodules_get() {
  local key="$1"
  local value=""
  local status=0
  if value="$(git config -f .gitmodules --get "$key" 2>/dev/null)"; then
    printf '%s' "$value"
    return 0
  else
    status=$?
  fi
  [[ "$status" -eq 1 ]] || die "não foi possível ler a chave '$key' de '.gitmodules'."
}

gitmodules_get_regexp() {
  local pattern="$1"
  local value=""
  local status=0
  if value="$(git config -f .gitmodules --get-regexp "$pattern" 2>/dev/null)"; then
    printf '%s\n' "$value"
    return 0
  else
    status=$?
  fi
  [[ "$status" -eq 1 ]] || die "não foi possível ler '.gitmodules' com segurança."
}

validate_document_destination() {
  local destination="$1"
  if [[ -L "$destination" ]]; then
    die "documento local '$destination' é um symlink; ele não será substituído."
  fi
  if [[ -e "$destination" && ! -f "$destination" ]]; then
    die "documento local '$destination' não é um arquivo regular."
  fi
}

validate_link_destination() {
  local destination="$1"
  local canonical_target="$2"
  local normalized=""

  if [[ -L "$destination" ]]; then
    if [[ "$(readlink "$destination")" == "$canonical_target" ]]; then
      return 0
    fi
    if [[ ! -e "$destination" ]]; then
      die "link quebrado em '$destination'; corrija-o antes do setup."
    fi
    normalized="$(normalize_link_target "$destination" 2>/dev/null || true)"
    if is_known_legacy_link "$destination"; then
      if [[ "$destination" == "$project_root/AGENTS.md" ]]; then
        legacy_root_agents_allowed=true
        legacy_root_agents_target="$(readlink "$destination")"
      elif [[ "$legacy_ai" == true && -n "$legacy_link_records" ]]; then
        printf '%s\t%s\t%s\n' "${destination#$project_root/}" "$(readlink "$destination")" "$normalized" >> "$legacy_link_records"
      fi
      return 0
    fi
    die "link inesperado em '$destination' (destino '$normalized'); nenhuma substituição externa é permitida."
  fi

  if [[ -e "$destination" ]]; then
    if [[ "$canonical_target" == "shared/ai/skills" || "$canonical_target" == "shared/ai/agents" ]]; then
      [[ -d "$destination" ]] || die "'$destination' não é um diretório compatível com o link canônico."
    else
      [[ -f "$destination" ]] || die "'$destination' não é um arquivo regular compatível com o link canônico."
    fi
  fi
}

validate_all_destinations() {
  local candidate_ai="$project_root/ai"

  validate_document_destination "$candidate_ai/PROJECT_BRIEF.md"
  validate_document_destination "$candidate_ai/PROJECT_GUIDE.md"
  validate_link_destination "$project_root/AGENTS.md" "ai/shared/AGENTS.md"
  validate_link_destination "$candidate_ai/CODEX_ORCHESTRATOR.md" "shared/ai/CODEX_ORCHESTRATOR.md"
  validate_link_destination "$candidate_ai/SWIFT_REFERENCE.md" "shared/ai/SWIFT_REFERENCE.md"
  validate_link_destination "$candidate_ai/skills" "shared/ai/skills"
  validate_link_destination "$candidate_ai/agents" "shared/ai/agents"
}

prepare_legacy_staging() {
  if [[ "$legacy_ai" != true ]]; then
    return 0
  fi
  staging_directory="$(mktemp -d "${TMPDIR:-/tmp}/ai-consumer-setup.XXXXXX")" || die "não foi possível criar staging seguro para o layout legado."
  chmod 700 "$staging_directory"
  legacy_link_records="$staging_directory/legacy-links"
  : > "$legacy_link_records"
  cp -RP "$project_root/.ai-project" "$staging_directory/ai" || die "não foi possível copiar o layout legado sem seguir symlinks."
  [[ -d "$staging_directory/ai" && ! -L "$staging_directory/ai" ]] || die "a cópia de staging do layout legado não é um diretório real."
  validate_no_special_files "$staging_directory/ai"
  preserve_staged_modes "$project_root/.ai-project" "$staging_directory/ai"
}

preserve_staged_modes() {
  local source_root="$1"
  local target_root="$2"
  local source_path=""
  local relative_path=""
  local target_path=""
  local mode=""

  while IFS= read -r -d '' source_path; do
    if [[ -L "$source_path" ]]; then
      continue
    fi
    if [[ "$source_path" == "$source_root" ]]; then
      target_path="$target_root"
    else
      relative_path="${source_path#$source_root/}"
      target_path="$target_root/$relative_path"
    fi
    mode="$(stat -f '%Lp' "$source_path" 2>/dev/null || stat -c '%a' "$source_path" 2>/dev/null)" || die "não foi possível ler as permissões de '$source_path'."
    chmod "$mode" "$target_path" || die "não foi possível preservar as permissões de '$source_path'."
  done < <(find "$source_root" -print0)
}

validate_backup_parent() {
  local parent="$project_root/.ai-base-migration-backup"

  if [[ -L "$parent" || ( -e "$parent" && ! -d "$parent" ) ]]; then
    die "o destino de backup '$parent' é conflitante ou é um symlink."
  fi
}

validate_backup_destinations() {
  local destination=""
  local backup_required=false

  [[ "$migrate_existing" == true ]] || return 0
  for destination in \
    "$project_root/AGENTS.md" \
    "$project_root/ai/CODEX_ORCHESTRATOR.md" \
    "$project_root/ai/SWIFT_REFERENCE.md" \
    "$project_root/ai/skills" \
    "$project_root/ai/agents"; do
    if [[ -e "$destination" && ! -L "$destination" ]]; then
      backup_required=true
      break
    fi
  done
  if [[ "$backup_required" == true ]]; then
    validate_backup_parent
  fi
}

prepare_backup_directory() {
  local parent="$project_root/.ai-base-migration-backup"
  local candidate=""
  local stamp="$(date +%Y%m%d-%H%M%S)"
  local suffix=0

  validate_backup_parent
  mkdir -p "$parent"
  while :; do
    if [[ "$suffix" -eq 0 ]]; then
      candidate="$parent/$stamp"
    else
      candidate="$parent/$stamp-$suffix"
    fi
    if [[ ! -e "$candidate" && ! -L "$candidate" ]]; then
      if ! mkdir "$candidate"; then
        die "não foi possível criar o diretório de backup '$candidate'."
      fi
      backup_directory="$candidate"
      chmod 700 "$backup_directory"
      return 0
    fi
    suffix=$((suffix + 1))
  done
}

backup_existing() {
  local destination="$1"
  local relative="$2"
  local backup_path=""
  local backup_parent=""

  if [[ "$migrate_existing" != true ]]; then
    echo "Preservado: '$relative' já existe; use --migrate-existing para criar o link canônico."
    return 0
  fi
  if [[ -z "$backup_directory" ]]; then
    prepare_backup_directory
  fi
  backup_path="$backup_directory/$relative"
  backup_parent="$(dirname -- "$backup_path")"
  mkdir -p "$backup_parent"
  mv "$destination" "$backup_path"
  echo "Backup preservado: '$relative' -> '$backup_path'"
}

create_or_normalize_link() {
  local source_target="$1"
  local destination="$2"
  local relative="$3"

  if [[ -L "$destination" ]]; then
    if [[ "$(readlink "$destination")" == "$source_target" && -e "$destination" ]]; then
      echo "Já configurado: '$relative'"
      return 0
    fi
    if ! is_known_legacy_link "$destination"; then
      if ! legacy_link_was_validated "$destination" && [[ "$destination" != "$project_root/AGENTS.md" || "$legacy_root_agents_allowed" != true || "$(readlink "$destination")" != "$legacy_root_agents_target" ]]; then
        die "o link '$relative' mudou depois do preflight; estado ambíguo, sem rollback automático."
      fi
    fi
    rm "$destination"
  elif [[ -e "$destination" ]]; then
    backup_existing "$destination" "$relative"
    if [[ -e "$destination" || -L "$destination" ]]; then
      return 0
    fi
  fi

  [[ ! -e "$destination" && ! -L "$destination" ]] || die "não foi possível liberar '$relative' para o link canônico."
  ln -s "$source_target" "$destination"
  echo "Link criado: '$relative' -> '$source_target'"
}

legacy_link_was_validated() {
  local destination="$1"
  local relative="${destination#$project_root/}"
  local record_relative=""
  local record_target=""
  local original_normalized=""
  local expected_normalized=""
  local current_normalized=""

  [[ "$legacy_ai" == true && -n "$legacy_link_records" && -f "$legacy_link_records" ]] || return 1
  while IFS=$'\t' read -r record_relative record_target original_normalized; do
    if [[ "$record_relative" == "$relative" && "$(readlink "$destination" 2>/dev/null)" == "$record_target" ]]; then
      if [[ "$original_normalized" == "$project_root/.ai-project"/* ]]; then
        expected_normalized="$project_root/ai/${original_normalized#"$project_root/.ai-project/"}"
        current_normalized="$(normalize_link_target "$destination" 2>/dev/null || true)"
        [[ "$current_normalized" == "$expected_normalized" ]] || return 1
      fi
      return 0
    fi
  done < "$legacy_link_records"
  return 1
}

create_documents() {
  local document=""
  local destination=""
  local template=""
  for document in PROJECT_BRIEF PROJECT_GUIDE; do
    destination="ai/${document}.md"
    template="$shared_path/ai/${document}.template.md"
    if [[ -e "$destination" ]]; then
      echo "Preservado: '$destination' é específico deste projeto."
    else
      [[ ! -L "$destination" ]] || die "documento '$destination' mudou para um symlink durante a configuração."
      cp "$template" "$destination"
      echo "Criado: '$destination' a partir do template compartilhado."
    fi
  done
}

remove_tracked_legacy_ai() {
  if [[ "$legacy_ai_tracked" != true ]]; then
    return 0
  fi
  phase remove-legacy-gitlink
  git rm --cached -- ai >/dev/null || die "não foi possível remover somente o symlink legado 'ai' do índice."
  echo "Índice: removida somente a entrada rastreada do symlink legado 'ai'."
}

migrate_legacy_ai() {
  if [[ "$legacy_ai" != true ]]; then
    if [[ ! -e "$project_root/ai" && ! -L "$project_root/ai" ]]; then
      mkdir "$project_root/ai"
      echo "Criado: diretório real 'ai'."
    fi
    return 0
  fi

  phase migrate-legacy
  mutation_started=true
  [[ -L "$project_root/ai" && -e "$project_root/ai" ]] || die "o symlink legado 'ai' mudou antes da migração."
  [[ "$(normalize_link_target "$project_root/ai" 2>/dev/null)" == "$project_root/.ai-project" ]] || die "o destino do symlink legado 'ai' mudou antes da migração."
  remove_tracked_legacy_ai
  rm "$project_root/ai"
  mv "$staging_directory/ai" "$project_root/ai"
  echo "Migração concluída: 'ai' agora é um diretório real; '.ai-project' foi preservado como cópia de recuperação."
}

ensure_submodule() {
  local configured_path=""
  local submodule_status=""

  phase submodule
  mutation_started=true
  configured_path="$(git config -f .gitmodules --get 'submodule.ai/shared.path' 2>/dev/null || true)"
  if [[ -n "$configured_path" ]]; then
    if [[ ! -d "$shared_path" ]]; then
      git submodule update --init -- "$shared_path" || die "não foi possível inicializar o submodule '$shared_path'; o estado foi preservado."
    elif [[ ! -d "$shared_path/.git" && ! -f "$shared_path/.git" ]]; then
      git submodule update --init -- "$shared_path" || die "o diretório '$shared_path' não pôde ser validado como submodule."
    fi
  else
    git submodule add -b "$branch" "$remote_url" "$shared_path" || die "não foi possível adicionar '$shared_path' como submodule; confira o estado parcial de Git antes de repetir."
  fi

  [[ -d "$shared_path" && ! -L "$shared_path" ]] || die "'$shared_path' não é um diretório real após a configuração do submodule."
  if ! submodule_status="$(git -C "$shared_path" status --porcelain 2>/dev/null)"; then
    die "o submodule '$shared_path' não pôde ser lido pelo Git; o estado foi preservado."
  fi
  if [[ "$update_dependency" == true && -n "$submodule_status" ]]; then
    die "o submodule '$shared_path' possui alterações locais; --update não as sobrescreverá."
  fi
}

update_submodule() {
  if [[ "$update_dependency" != true ]]; then
    return 0
  fi

  phase update
  git -C "$shared_path" fetch origin "$branch" || die "não foi possível buscar '$branch' no submodule; a configuração do projeto foi preservada."
  if git -C "$shared_path" show-ref --verify --quiet "refs/heads/$branch"; then
    git -C "$shared_path" switch "$branch" || die "não foi possível selecionar a branch '$branch' no submodule."
  else
    git -C "$shared_path" switch --create "$branch" --track "origin/$branch" || die "não foi possível criar a branch local '$branch' no submodule."
  fi
  git -C "$shared_path" pull --ff-only origin "$branch" || die "não foi possível atualizar o submodule com fast-forward."
}

validate_required_shared_files() {
  local required_file=""
  for required_file in AGENTS.md ai/CODEX_ORCHESTRATOR.md ai/SWIFT_REFERENCE.md ai/agents/Manager.toml ai/agents/Developer.toml; do
    [[ -f "$shared_path/$required_file" ]] || die "a dependência não contém '$required_file'."
  done
}

phase prepare
validate_ai_layout
validate_gitmodules_staging
prepare_legacy_staging
validate_git_layout
validate_all_destinations
validate_backup_destinations

phase migrate
migrate_legacy_ai

phase configure
ensure_submodule
update_submodule
validate_required_shared_files

create_or_normalize_link "ai/shared/AGENTS.md" "$project_root/AGENTS.md" "AGENTS.md"
create_or_normalize_link "shared/ai/CODEX_ORCHESTRATOR.md" "$project_root/ai/CODEX_ORCHESTRATOR.md" "ai/CODEX_ORCHESTRATOR.md"
create_or_normalize_link "shared/ai/SWIFT_REFERENCE.md" "$project_root/ai/SWIFT_REFERENCE.md" "ai/SWIFT_REFERENCE.md"
create_or_normalize_link "shared/ai/skills" "$project_root/ai/skills" "ai/skills"
create_or_normalize_link "shared/ai/agents" "$project_root/ai/agents" "ai/agents"
create_documents

phase complete
echo ""
echo "Base AI configurada com segurança em: $project_root"
echo "Diagnóstico: os documentos locais e os extras existentes foram preservados."
echo "Recuperação: '$project_root/.ai-project' permanece intacto quando o layout legado foi migrado."
echo ""
echo "Para registrar a versão no projeto consumidor:"
echo "  git add .gitmodules ai/shared AGENTS.md ai"
echo "  git commit -m \"chore: configura base compartilhada de IA\""
echo ""
echo "Para atualizar a dependência:"
echo "  ai/shared/scripts/setup-consumer.sh --update"
echo "  git add ai/shared"
echo "  git commit -m \"chore: atualiza base compartilhada de IA\""

if [[ -n "$backup_directory" ]]; then
  echo ""
  echo "Cópias reais substituídas foram preservadas em '$backup_directory'."
  echo "Revise o backup e não o adicione ao commit do projeto consumidor."
fi
