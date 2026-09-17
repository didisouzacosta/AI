#!/usr/bin/env bash

set -u

SCRIPT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ai-consumer-tests.XXXXXX")"
REMOTE_ROOT="$TEST_ROOT/AI remote.git"
SEED_ROOT="$TEST_ROOT/AI seed"
CONSUMER_ROOT="$TEST_ROOT/consumer with spaces"

failures=0

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT INT TERM

fail() {
  echo "FALHA: $*" >&2
  failures=$((failures + 1))
}

assert_file() {
  if [[ ! -f "$1" ]]; then
    fail "arquivo ausente: $1"
  fi
}

assert_directory() {
  if [[ ! -d "$1" || -L "$1" ]]; then
    fail "diretório real esperado: $1"
  fi
}

assert_symlink_target() {
  local path="$1"
  local expected="$2"
  if [[ ! -L "$path" || "$(readlink "$path")" != "$expected" ]]; then
    fail "link inesperado em $path (esperado '$expected')"
  fi
}

assert_not_exists() {
  if [[ -e "$1" || -L "$1" ]]; then
    fail "caminho não deveria existir: $1"
  fi
}

assert_mode() {
  local path="$1"
  local expected="$2"
  local actual=""
  actual="$(stat -f '%Lp' "$path" 2>/dev/null || stat -c '%a' "$path" 2>/dev/null || true)"
  if [[ "$actual" != "$expected" ]]; then
    fail "permissão inesperada em $path (esperado $expected, obtido $actual)"
  fi
}

assert_contains() {
  local path="$1"
  local expected="$2"
  if ! grep -F "$expected" "$path" >/dev/null 2>&1; then
    fail "'$expected' não encontrado em $path"
  fi
}

make_consumer() {
  local path="$1"
  mkdir -p "$path"
  git init "$path" >/dev/null
  git -C "$path" config user.email test@example.com
  git -C "$path" config user.name Tests
}

run_setup() {
  local path="$1"
  shift
  (cd "$path" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE_ROOT" bash "$SCRIPT_ROOT/scripts/setup-consumer.sh" "$@") >"$TEST_ROOT/last.out" 2>&1
}

run_bootstrap() {
  local path="$1"
  shift
  (cd "$path" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE_ROOT" CODEX_CONFIG_DIR="$TEST_ROOT/codex config" bash "$SCRIPT_ROOT/scripts/bootstrap-consumer.sh" "$@") >"$TEST_ROOT/last.out" 2>&1
}

run_update() {
  local path="$1"
  (cd "$path" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE_ROOT" bash "$SCRIPT_ROOT/scripts/update-consumer.sh") >"$TEST_ROOT/last.out" 2>&1
}

assert_canonical_links() {
  local path="$1"
  assert_symlink_target "$path/AGENTS.md" 'ai/shared/AGENTS.md'
  assert_symlink_target "$path/ai/CODEX_ORCHESTRATOR.md" 'shared/ai/CODEX_ORCHESTRATOR.md'
  assert_symlink_target "$path/ai/SWIFT_REFERENCE.md" 'shared/ai/SWIFT_REFERENCE.md'
  assert_symlink_target "$path/ai/skills" 'shared/ai/skills'
  assert_symlink_target "$path/ai/agents" 'shared/ai/agents'
}

setup_remote() {
  git init --bare "$REMOTE_ROOT" >/dev/null
  mkdir -p "$SEED_ROOT/ai/agents" "$SEED_ROOT/ai/skills"
  printf '%s\n' '# AGENTS compartilhado' > "$SEED_ROOT/AGENTS.md"
  printf '%s\n' '# Orquestrador compartilhado' > "$SEED_ROOT/ai/CODEX_ORCHESTRATOR.md"
  printf '%s\n' '# Referência Swift' > "$SEED_ROOT/ai/SWIFT_REFERENCE.md"
  printf '%s\n' 'manager' > "$SEED_ROOT/ai/agents/Manager.toml"
  printf '%s\n' 'developer' > "$SEED_ROOT/ai/agents/Developer.toml"
  printf '%s\n' '# skills' > "$SEED_ROOT/ai/skills/README.md"
  printf '%s\n' '# brief' > "$SEED_ROOT/ai/PROJECT_BRIEF.template.md"
  printf '%s\n' '# guide' > "$SEED_ROOT/ai/PROJECT_GUIDE.template.md"
  git -C "$SEED_ROOT" init >/dev/null
  git -C "$SEED_ROOT" config user.email test@example.com
  git -C "$SEED_ROOT" config user.name Tests
  git -C "$SEED_ROOT" add .
  git -C "$SEED_ROOT" commit -m 'base' >/dev/null
  git -C "$SEED_ROOT" branch -M main
  git -C "$SEED_ROOT" remote add origin "$REMOTE_ROOT"
  git -C "$SEED_ROOT" push -u origin main >/dev/null
}

test_legacy_symlink_is_migrated() {
  mkdir -p "$CONSUMER_ROOT/.ai-project"
  git init "$CONSUMER_ROOT" >/dev/null
  git -C "$CONSUMER_ROOT" config user.email test@example.com
  git -C "$CONSUMER_ROOT" config user.name Tests
  printf '%s\n' 'brief local' > "$CONSUMER_ROOT/.ai-project/PROJECT_BRIEF.md"
  printf '%s\n' 'guide local' > "$CONSUMER_ROOT/.ai-project/PROJECT_GUIDE.md"
  printf '%s\n' 'extra' > "$CONSUMER_ROOT/.ai-project/extra.txt"
  chmod 640 "$CONSUMER_ROOT/.ai-project/extra.txt"
  ln -s extra.txt "$CONSUMER_ROOT/.ai-project/extra-link"
  ln -s .ai-project "$CONSUMER_ROOT/ai"

  if ! (cd "$CONSUMER_ROOT" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE_ROOT" bash "$SCRIPT_ROOT/scripts/setup-consumer.sh") >"$TEST_ROOT/setup.out" 2>&1; then
    cat "$TEST_ROOT/setup.out" >&2
    fail 'setup deveria migrar o link legado ai -> .ai-project'
    return
  fi

  assert_directory "$CONSUMER_ROOT/ai"
  assert_directory "$CONSUMER_ROOT/.ai-project"
  assert_file "$CONSUMER_ROOT/ai/PROJECT_BRIEF.md"
  assert_file "$CONSUMER_ROOT/ai/PROJECT_GUIDE.md"
  assert_file "$CONSUMER_ROOT/ai/extra.txt"
  assert_symlink_target "$CONSUMER_ROOT/ai/extra-link" 'extra.txt'
  assert_mode "$CONSUMER_ROOT/ai/extra.txt" '640'
  assert_file "$CONSUMER_ROOT/.ai-project/extra.txt"
  assert_symlink_target "$CONSUMER_ROOT/.ai-project/extra-link" 'extra.txt'
  assert_mode "$CONSUMER_ROOT/.ai-project/extra.txt" '640'
  assert_canonical_links "$CONSUMER_ROOT"
  assert_directory "$CONSUMER_ROOT/ai/shared"
  if [[ ! -f "$CONSUMER_ROOT/ai/shared/.git" && ! -d "$CONSUMER_ROOT/ai/shared/.git" ]]; then
    fail "ai/shared não foi inicializado como submodule"
  fi
}

test_untracked_legacy_symlink() {
  local path="$TEST_ROOT/untracked legacy"
  make_consumer "$path"
  mkdir -p "$path/.ai-project"
  printf '%s\n' 'untracked extra' > "$path/.ai-project/extra.txt"
  ln -s .ai-project "$path/ai"
  run_setup "$path" || fail 'symlink legado não rastreado deveria ser migrado'
  assert_directory "$path/ai"
  assert_file "$path/ai/extra.txt"
  assert_directory "$path/.ai-project"
  assert_canonical_links "$path"
}

test_tracked_legacy_symlink_only_index_entry() {
  local path="$TEST_ROOT/tracked legacy"
  make_consumer "$path"
  mkdir -p "$path/.ai-project"
  printf '%s\n' 'tracked outside' > "$path/outside.txt"
  printf '%s\n' 'tracked extra' > "$path/.ai-project/extra.txt"
  ln -s .ai-project "$path/ai"
  git -C "$path" add ai outside.txt
  git -C "$path" commit -m initial >/dev/null
  run_setup "$path" || fail 'symlink legado rastreado deveria ser migrado'
  if [[ -n "$(git -C "$path" ls-files --stage -- ai | awk '$4 == "ai" {print}')" ]]; then
    fail "a entrada rastreada antiga de ai deveria ter sido removida do índice"
  fi
  if [[ "$(git -C "$path" ls-files -- outside.txt)" != "outside.txt" ]]; then
    fail 'a entrada fora do escopo foi removida do índice'
  fi
  assert_file "$path/outside.txt"
  assert_file "$path/ai/extra.txt"
}

test_idempotence_does_not_use_remote_or_backup() {
  local path="$TEST_ROOT/idempotent"
  local gitlink_before=""
  local backup_count_before=0
  local backup_count_after=0
  make_consumer "$path"
  run_setup "$path" || fail 'setup inicial da idempotência falhou'
  gitlink_before="$(git -C "$path" ls-files --stage -- ai/shared)"
  if [[ -d "$path/.ai-base-migration-backup" ]]; then
    backup_count_before="$(find "$path/.ai-base-migration-backup" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  fi
  if ! (cd "$path" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$TEST_ROOT/remote-inexistente" bash "$SCRIPT_ROOT/scripts/setup-consumer.sh") >"$TEST_ROOT/last.out" 2>&1; then
    fail 'repetição sem --update não deveria depender do remote configurado'
  fi
  if [[ "$(git -C "$path" ls-files --stage -- ai/shared)" != "$gitlink_before" ]]; then
    fail 'repetição mudou o gitlink sem --update'
  fi
  if [[ -d "$path/.ai-base-migration-backup" ]]; then
    backup_count_after="$(find "$path/.ai-base-migration-backup" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
  fi
  if [[ "$backup_count_after" != "$backup_count_before" ]]; then
    fail 'repetição criou backup adicional'
  fi
}

test_existing_copies_and_migrate_backup() {
  local path="$TEST_ROOT/existing copies"
  local backup_root=""
  make_consumer "$path"
  mkdir -p "$path/ai/skills" "$path/ai/agents"
  printf '%s\n' 'local agents' > "$path/AGENTS.md"
  printf '%s\n' 'local orchestrator' > "$path/ai/CODEX_ORCHESTRATOR.md"
  printf '%s\n' 'local swift' > "$path/ai/SWIFT_REFERENCE.md"
  printf '%s\n' 'local skill' > "$path/ai/skills/local.md"
  printf '%s\n' 'local agent' > "$path/ai/agents/local.toml"
  run_setup "$path" || fail 'setup com cópias reais falhou'
  if [[ -L "$path/AGENTS.md" || -L "$path/ai/CODEX_ORCHESTRATOR.md" ]]; then
    fail 'cópias reais foram substituídas sem --migrate-existing'
  fi
  assert_not_exists "$path/.ai-base-migration-backup"
  run_setup "$path" --migrate-existing || fail 'migração explícita de cópias falhou'
  assert_canonical_links "$path"
  backup_root="$(find "$path/.ai-base-migration-backup" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [[ -n "$backup_root" ]] || fail 'backup datado não foi criado'
  assert_file "$backup_root/AGENTS.md"
  assert_file "$backup_root/ai/CODEX_ORCHESTRATOR.md"
  assert_file "$backup_root/ai/SWIFT_REFERENCE.md"
  assert_file "$backup_root/ai/skills/local.md"
  assert_file "$backup_root/ai/agents/local.toml"
}

test_missing_documents_are_created() {
  local path="$TEST_ROOT/missing documents"
  make_consumer "$path"
  run_setup "$path" || fail 'setup sem documentos falhou'
  assert_file "$path/ai/PROJECT_BRIEF.md"
  assert_file "$path/ai/PROJECT_GUIDE.md"
}

test_known_legacy_root_link_is_replaced() {
  local path="$TEST_ROOT/known root link"
  make_consumer "$path"
  ln -s "${HOME}/.codex/AGENTS.md" "$path/AGENTS.md"
  run_setup "$path" || fail 'link legado conhecido de AGENTS.md deveria ser substituído'
  assert_symlink_target "$path/AGENTS.md" 'ai/shared/AGENTS.md'
}

test_unexpected_and_broken_links_abort_before_git_mutation() {
  local path="$TEST_ROOT/unexpected link"
  local external="$TEST_ROOT/external.txt"
  make_consumer "$path"
  mkdir -p "$path/ai"
  printf '%s\n' external > "$external"
  ln -s "$external" "$path/ai/CODEX_ORCHESTRATOR.md"
  if run_setup "$path"; then
    fail 'link externo inesperado deveria abortar'
  fi
  assert_not_exists "$path/.gitmodules"

  path="$TEST_ROOT/broken link"
  make_consumer "$path"
  mkdir -p "$path/ai"
  ln -s missing "$path/ai/skills"
  if run_setup "$path"; then
    fail 'link quebrado deveria abortar'
  fi
  assert_not_exists "$path/.gitmodules"
}

test_preflight_rejects_ambiguous_and_local_document_links() {
  local path="$TEST_ROOT/ambiguous link"
  make_consumer "$path"
  mkdir -p "$path/.ai-project"
  ln -s .ai-project "$path/legacy-target"
  ln -s legacy-target "$path/ai"
  if run_setup "$path"; then
    fail 'encadeamento de ai deveria abortar'
  fi
  assert_symlink_target "$path/ai" 'legacy-target'

  path="$TEST_ROOT/document symlink"
  make_consumer "$path"
  mkdir -p "$path/ai"
  printf '%s\n' local > "$path/local-brief.md"
  ln -s ../local-brief.md "$path/ai/PROJECT_BRIEF.md"
  if run_setup "$path"; then
    fail 'documento local symlink deveria abortar'
  fi
  assert_symlink_target "$path/ai/PROJECT_BRIEF.md" '../local-brief.md'
}

test_preflight_rejects_shared_and_gitmodules_conflicts() {
  local path="$TEST_ROOT/shared conflict"
  make_consumer "$path"
  mkdir -p "$path/ai/shared"
  if run_setup "$path"; then
    fail 'shared inesperado deveria abortar'
  fi
  assert_not_exists "$path/.gitmodules"

  path="$TEST_ROOT/gitmodules symlink"
  make_consumer "$path"
  printf '%s\n' '[submodule "other"]' > "$path/real-gitmodules"
  ln -s real-gitmodules "$path/.gitmodules"
  if run_setup "$path"; then
    fail '.gitmodules symlink deveria abortar'
  fi
  assert_symlink_target "$path/.gitmodules" 'real-gitmodules'

  path="$TEST_ROOT/unknown metadata"
  make_consumer "$path"
  printf '%s\n' '[submodule "ai/shared"]' 'path = ai/shared' 'url = /tmp/remote' 'mystery = value' > "$path/.gitmodules"
  if run_setup "$path"; then
    fail 'metadado desconhecido de submodule deveria abortar'
  fi
  assert_file "$path/.gitmodules"
}

test_lock_is_exclusive_and_not_removed_on_conflict() {
  local path="$TEST_ROOT/locked"
  make_consumer "$path"
  mkdir -p "$path/.ai-base-setup.lock"
  printf '%s\n' keep > "$path/.ai-base-setup.lock/phase"
  if run_setup "$path"; then
    fail 'setup deveria recusar lock existente'
  fi
  assert_file "$path/.ai-base-setup.lock/phase"
}

test_preserves_other_git_state() {
  local path="$TEST_ROOT/other git state"
  local other_remote="$TEST_ROOT/other remote.git"
  local other_seed="$TEST_ROOT/other seed"
  make_consumer "$path"
  mkdir -p "$other_seed"
  git init --bare "$other_remote" >/dev/null
  git init "$other_seed" >/dev/null
  git -C "$other_seed" config user.email test@example.com
  git -C "$other_seed" config user.name Tests
  printf '%s\n' other > "$other_seed/README"
  git -C "$other_seed" add README
  git -C "$other_seed" commit -m other >/dev/null
  git -C "$other_seed" branch -M main
  git -C "$other_seed" remote add origin "$other_remote"
  git -C "$other_seed" push -u origin main >/dev/null
  (cd "$path" && GIT_ALLOW_PROTOCOL=file git submodule add -b main "$other_remote" vendor/other) >/dev/null 2>&1 || fail 'submodule externo de teste não foi criado'
  printf '%s\n' staged > "$path/staged.txt"
  git -C "$path" add staged.txt
  printf '%s\n' unstaged > "$path/staged.txt"
  printf '%s\n' untracked > "$path/untracked.txt"
  if ! run_setup "$path"; then
    cat "$TEST_ROOT/last.out" >&2
    fail 'setup com estado Git fora do escopo falhou'
  fi
  if [[ "$(git -C "$path" diff --cached --name-only | grep '^staged.txt$' || true)" != 'staged.txt' ]]; then
    fail 'estado staged fora do escopo não foi preservado'
  fi
  assert_file "$path/untracked.txt"
  assert_directory "$path/vendor/other"
  if [[ "$(git -C "$path" ls-files --stage -- vendor/other | awk '{print $1}')" != '160000' ]]; then
    fail 'outro submodule foi alterado'
  fi
}

test_rejects_external_submodule_git_metadata_before_update() {
  local path="$TEST_ROOT/external submodule metadata"
  local external_repo="$TEST_ROOT/external submodule repo"
  local branch_before=""
  local status_before=""
  local index_before=""
  local file_before=""

  make_consumer "$path"
  run_setup "$path" || fail 'setup inicial para metadados externos falhou'

  git init "$external_repo" >/dev/null
  git -C "$external_repo" config user.email test@example.com
  git -C "$external_repo" config user.name Tests
  printf '%s\n' 'external checkout' > "$external_repo/external.txt"
  git -C "$external_repo" add external.txt
  git -C "$external_repo" commit -m external >/dev/null
  git -C "$external_repo" switch -c review-external >/dev/null

  printf 'gitdir: %s\n' "$external_repo/.git" > "$path/ai/shared/.git"
  branch_before="$(git -C "$external_repo" branch --show-current)"
  status_before="$(git -C "$external_repo" status --porcelain)"
  index_before="$(git -C "$external_repo" ls-files --stage)"
  file_before="$(cksum < "$external_repo/external.txt")"

  if run_setup "$path" --update; then
    fail 'submodule com gitfile externo deveria ser rejeitado antes da atualização'
  fi
  assert_contains "$TEST_ROOT/last.out" 'associação'
  [[ "$(git -C "$external_repo" branch --show-current)" == "$branch_before" ]] || fail 'branch do repositório externo foi alterada'
  [[ "$(git -C "$external_repo" status --porcelain)" == "$status_before" ]] || fail 'status do repositório externo foi alterado'
  [[ "$(git -C "$external_repo" ls-files --stage)" == "$index_before" ]] || fail 'índice do repositório externo foi alterado'
  [[ "$(cksum < "$external_repo/external.txt")" == "$file_before" ]] || fail 'arquivo do repositório externo foi alterado'

  path="$TEST_ROOT/symlink submodule metadata"
  make_consumer "$path"
  run_setup "$path" || fail 'setup inicial para symlink externo falhou'
  rm "$path/ai/shared/.git"
  ln -s "$external_repo/.git" "$path/ai/shared/.git"
  branch_before="$(git -C "$external_repo" branch --show-current)"
  if run_setup "$path" --update; then
    fail 'symlink de .git externo deveria ser rejeitado antes da atualização'
  fi
  assert_contains "$TEST_ROOT/last.out" 'symlink'
  [[ "$(git -C "$external_repo" branch --show-current)" == "$branch_before" ]] || fail 'branch externa foi alterada ao rejeitar symlink de .git'
}

test_rejects_unrelated_gitmodules_staging_divergence_before_mutation() {
  local path="$TEST_ROOT/gitmodules staging divergence"
  local index_before=""
  local gitmodules_before=""

  make_consumer "$path"
  printf '%s\n' '[submodule "other"]' 'path = vendor/other' 'url = /original/remote' > "$path/.gitmodules"
  git -C "$path" add .gitmodules
  printf '%s\n' '[submodule "other"]' 'path = vendor/other' 'url = /unstaged/remote' > "$path/.gitmodules"
  index_before="$(git -C "$path" ls-files --stage -- .gitmodules)"
  gitmodules_before="$(cksum < "$path/.gitmodules")"

  if run_setup "$path"; then
    fail 'divergência staged/unstaged de seção alheia deveria ser rejeitada antes da migração'
  fi
  assert_contains "$TEST_ROOT/last.out" '.gitmodules'
  [[ "$(git -C "$path" ls-files --stage -- .gitmodules)" == "$index_before" ]] || fail 'o índice de .gitmodules foi alterado'
  [[ "$(cksum < "$path/.gitmodules")" == "$gitmodules_before" ]] || fail 'o .gitmodules unstaged foi alterado'
  assert_not_exists "$path/.gitmodules~"
  assert_not_exists "$path/ai/shared"
}

test_rejects_indented_external_gitmodules_divergence_before_mutation() {
  local path="$TEST_ROOT/gitmodules indented external divergence"
  local index_before=""
  local gitmodules_before=""

  make_consumer "$path"
  mkdir -p "$path/.ai-project"
  printf '%s\n' 'preserve me' > "$path/.ai-project/extra.txt"
  ln -s .ai-project "$path/ai"
  git -C "$path" add ai
  printf '%s\n' \
    '[submodule "ai/shared"]' \
    ' [submodule "other"]' \
    ' path = vendor/other' \
    ' url = /staged/remote' > "$path/.gitmodules"
  git -C "$path" add .gitmodules
  printf '%s\n' \
    '[submodule "ai/shared"]' \
    ' [submodule "other"]' \
    ' path = vendor/other' \
    ' url = /unstaged/remote' > "$path/.gitmodules"
  index_before="$(git -C "$path" ls-files --stage)"
  gitmodules_before="$(cksum < "$path/.gitmodules")"

  if run_setup "$path"; then
    fail 'divergência staged/unstaged em seção externa indentada deveria ser rejeitada antes da migração'
  fi
  assert_contains "$TEST_ROOT/last.out" '.gitmodules'
  [[ "$(git -C "$path" ls-files --stage)" == "$index_before" ]] || fail 'o índice mudou ao rejeitar seção externa indentada divergente'
  [[ "$(cksum < "$path/.gitmodules")" == "$gitmodules_before" ]] || fail 'o .gitmodules unstaged mudou ao rejeitar seção externa indentada divergente'
  assert_symlink_target "$path/ai" '.ai-project'
  assert_file "$path/.ai-project/extra.txt"
  assert_not_exists "$path/ai/shared"
}

test_rejects_missing_worktree_gitmodules_with_staged_entry_before_migration() {
  local path="$TEST_ROOT/gitmodules staged but missing worktree"
  local index_before=""

  make_consumer "$path"
  mkdir -p "$path/.ai-project"
  printf '%s\n' 'preserve me' > "$path/.ai-project/extra.txt"
  ln -s .ai-project "$path/ai"
  git -C "$path" add ai
  printf '%s\n' '[submodule "other"]' 'path = vendor/other' 'url = /staged/remote' > "$path/.gitmodules"
  git -C "$path" add .gitmodules
  rm "$path/.gitmodules"
  index_before="$(git -C "$path" ls-files --stage)"

  if run_setup "$path"; then
    fail '.gitmodules staged e ausente do worktree deveria ser rejeitado antes da migração'
  fi
  assert_contains "$TEST_ROOT/last.out" '.gitmodules'
  [[ "$(git -C "$path" ls-files --stage)" == "$index_before" ]] || fail 'o índice mudou com .gitmodules ausente do worktree'
  assert_symlink_target "$path/ai" '.ai-project'
  assert_file "$path/.ai-project/extra.txt"
  assert_not_exists "$path/.gitmodules"
  assert_not_exists "$path/ai/shared"
}

test_rejects_untracked_external_gitmodules_before_migration() {
  local path="$TEST_ROOT/gitmodules untracked external"
  local index_before=""
  local gitmodules_before=""

  make_consumer "$path"
  mkdir -p "$path/.ai-project"
  printf '%s\n' 'preserve me' > "$path/.ai-project/extra.txt"
  ln -s .ai-project "$path/ai"
  printf '%s\n' \
    '[submodule "other"]' \
    'path = vendor/other' \
    'url = /external/remote' > "$path/.gitmodules"
  index_before="$(git -C "$path" ls-files --stage)"
  gitmodules_before="$(cksum < "$path/.gitmodules")"

  if run_setup "$path"; then
    fail '.gitmodules untracked com seção externa deveria ser rejeitado antes da migração'
  fi
  assert_contains "$TEST_ROOT/last.out" '.gitmodules'
  [[ "$(git -C "$path" ls-files --stage)" == "$index_before" ]] || fail 'o índice mudou ao rejeitar .gitmodules untracked externo'
  [[ "$(cksum < "$path/.gitmodules")" == "$gitmodules_before" ]] || fail 'a seção externa de .gitmodules foi alterada'
  assert_contains "$path/.gitmodules" '[submodule "other"]'
  assert_symlink_target "$path/ai" '.ai-project'
  assert_file "$path/.ai-project/extra.txt"
  assert_not_exists "$path/ai/shared"
  assert_not_exists "$path/.git/modules/ai/shared"
}

test_update_diagnoses_legacy_layout() {
  local path="$TEST_ROOT/update legacy"
  make_consumer "$path"
  mkdir -p "$path/.ai-project"
  ln -s .ai-project "$path/ai"
  if run_update "$path"; then
    fail 'ai-update deveria recusar layout legado'
  fi
  assert_contains "$TEST_ROOT/last.out" 'layout legado'
  assert_symlink_target "$path/ai" '.ai-project'
}

test_update_existing_submodule() {
  local path="$TEST_ROOT/update existing"
  make_consumer "$path"
  run_setup "$path" || fail 'setup inicial da atualização falhou'
  if ! run_update "$path"; then
    cat "$TEST_ROOT/last.out" >&2
    fail 'ai-update deveria atualizar um submodule já configurado'
  fi
  assert_canonical_links "$path"
}

test_bootstrap_configures_before_pending_agents() {
  local path="$TEST_ROOT/bootstrap order"
  make_consumer "$path"
  printf '%s\n' blocker > "$TEST_ROOT/codex blocker"
  if (cd "$path" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE_ROOT" CODEX_CONFIG_DIR="$TEST_ROOT/codex blocker" bash "$SCRIPT_ROOT/scripts/bootstrap-consumer.sh") >"$TEST_ROOT/last.out" 2>&1; then
    fail 'bootstrap deveria sinalizar agentes pendentes quando a configuração global é inválida'
  fi
  assert_directory "$path/ai"
  assert_directory "$path/ai/shared"
  assert_contains "$TEST_ROOT/last.out" 'projeto está configurado'
  assert_contains "$TEST_ROOT/last.out" 'não foi possível criar o diretório de agentes'
}

test_bootstrap_propagates_agent_link_failures() {
  local path="$TEST_ROOT/bootstrap agent failure"
  local fake_bin="$TEST_ROOT/fake-bin"
  make_consumer "$path"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/ln" <<'EOF'
#!/usr/bin/env bash
if [[ "${3:-}" == *"/codex failure/agents/"* ]]; then
  echo 'falha injetada ao criar link de agente' >&2
  exit 42
fi
exec /bin/ln "$@"
EOF
  chmod 755 "$fake_bin/ln"
  if (cd "$path" && PATH="$fake_bin:$PATH" GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE_ROOT" CODEX_CONFIG_DIR="$TEST_ROOT/codex failure" bash "$SCRIPT_ROOT/scripts/bootstrap-consumer.sh") >"$TEST_ROOT/last.out" 2>&1; then
    fail 'bootstrap deveria retornar erro quando a criação de link de agente falha'
  fi
  assert_contains "$TEST_ROOT/last.out" 'agentes globais pendentes'
  assert_contains "$TEST_ROOT/last.out" 'falha injetada ao criar link de agente'
}

test_bootstrap_propagates_agent_backup_and_move_failures() {
  local backup_path="$TEST_ROOT/bootstrap backup failure"
  local move_path="$TEST_ROOT/bootstrap move failure"
  local fake_bin="$TEST_ROOT/fake-mv-bin"
  make_consumer "$backup_path"
  mkdir -p "$TEST_ROOT/codex backup failure/agents"
  printf '%s\n' 'old manager' > "$TEST_ROOT/codex backup failure/agents/Manager.toml"
  printf '%s\n' 'blocker' > "$TEST_ROOT/codex backup failure/agents/.ai-base-migration-backup"
  if (cd "$backup_path" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE_ROOT" CODEX_CONFIG_DIR="$TEST_ROOT/codex backup failure" bash "$SCRIPT_ROOT/scripts/bootstrap-consumer.sh") >"$TEST_ROOT/last.out" 2>&1; then
    fail 'bootstrap deveria retornar erro quando a criação do backup falha'
  fi
  assert_contains "$TEST_ROOT/last.out" 'não foi possível criar o backup dos subagents'
  assert_contains "$TEST_ROOT/last.out" 'agentes globais pendentes'

  make_consumer "$move_path"
  mkdir -p "$fake_bin" "$TEST_ROOT/codex move failure/agents"
  printf '%s\n' 'old manager' > "$TEST_ROOT/codex move failure/agents/Manager.toml"
  cat > "$fake_bin/mv" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == *"/codex move failure/agents/"* ]]; then
  echo 'falha injetada ao mover backup de agente' >&2
  exit 43
fi
exec /bin/mv "$@"
EOF
  chmod 755 "$fake_bin/mv"
  if (cd "$move_path" && PATH="$fake_bin:$PATH" GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE_ROOT" CODEX_CONFIG_DIR="$TEST_ROOT/codex move failure" bash "$SCRIPT_ROOT/scripts/bootstrap-consumer.sh") >"$TEST_ROOT/last.out" 2>&1; then
    fail 'bootstrap deveria retornar erro quando a movimentação do backup falha'
  fi
  assert_contains "$TEST_ROOT/last.out" 'falha injetada ao mover backup de agente'
  assert_contains "$TEST_ROOT/last.out" 'não foi possível mover'
  assert_contains "$TEST_ROOT/last.out" 'agentes globais pendentes'
}

test_invalid_gitmodules_aborts_before_mutation() {
  local path="$TEST_ROOT/invalid gitmodules"
  local before_index=""
  local before_gitmodules_checksum=""
  make_consumer "$path"
  mkdir -p "$path/.ai-project"
  printf '%s\n' 'preserve me' > "$path/.ai-project/extra.txt"
  ln -s .ai-project "$path/ai"
  printf '%s\n' '[submodule "ai/shared"' 'path = ai/shared' 'url = /tmp/remote' > "$path/.gitmodules"
  before_index="$(git -C "$path" ls-files --stage)"
  before_gitmodules_checksum="$(cksum < "$path/.gitmodules")"
  if run_setup "$path"; then
    fail 'sintaxe inválida em .gitmodules deveria abortar'
  fi
  assert_contains "$TEST_ROOT/last.out" "'.gitmodules' inválido"
  [[ "$(git -C "$path" ls-files --stage)" == "$before_index" ]] || fail 'preflight inválido alterou o índice'
  [[ "$(cksum < "$path/.gitmodules")" == "$before_gitmodules_checksum" ]] || fail 'preflight inválido alterou .gitmodules'
  assert_symlink_target "$path/ai" '.ai-project'
  assert_file "$path/.gitmodules"
  assert_not_exists "$path/.git/modules"
}

test_invalid_existing_submodule_aborts_before_mutation() {
  local path="$TEST_ROOT/invalid existing submodule"
  local before_index=""
  local before_gitmodules_checksum=""
  make_consumer "$path"
  run_setup "$path" || fail 'setup inicial do submodule inválido falhou'
  before_index="$(git -C "$path" ls-files --stage)"
  before_gitmodules_checksum="$(cksum < "$path/.gitmodules")"
  printf '%s\n' 'gitdir: não é um gitdir válido' > "$path/ai/shared/.git"
  if run_setup "$path"; then
    fail 'repositório existente com .git inválido deveria abortar'
  fi
  assert_contains "$TEST_ROOT/last.out" 'repositório existente'
  [[ "$(git -C "$path" ls-files --stage)" == "$before_index" ]] || fail 'preflight do submodule inválido alterou o índice'
  [[ "$(cksum < "$path/.gitmodules")" == "$before_gitmodules_checksum" ]] || fail 'preflight do submodule inválido alterou .gitmodules'
}

test_fetch_recurse_submodules_metadata_is_normalized() {
  local path="$TEST_ROOT/fetch recurse metadata"
  make_consumer "$path"
  run_setup "$path" || fail 'setup inicial da opção fetchRecurseSubmodules falhou'
  git -C "$path" config -f .gitmodules submodule.ai/shared.fetchRecurseSubmodules true
  git -C "$path" config --local submodule.ai/shared.fetchRecurseSubmodules true
  if ! run_setup "$path"; then
    cat "$TEST_ROOT/last.out" >&2
    fail 'setup repetido deveria aceitar fetchRecurseSubmodules normalizado'
  fi
  if ! run_update "$path"; then
    cat "$TEST_ROOT/last.out" >&2
    fail 'update deveria aceitar fetchRecurseSubmodules normalizado'
  fi
  [[ "$(git -C "$path" config -f .gitmodules --get submodule.ai/shared.fetchRecurseSubmodules)" == 'true' ]] || fail 'fetchRecurseSubmodules não foi preservado em .gitmodules'
  [[ "$(git -C "$path" config --local --get submodule.ai/shared.fetchRecurseSubmodules)" == 'true' ]] || fail 'fetchRecurseSubmodules não foi preservado na configuração local'
}

test_conflicting_backup_destination_aborts_before_legacy_migration() {
  local symlink_path="$TEST_ROOT/backup symlink conflict"
  local regular_path="$TEST_ROOT/backup regular conflict"
  local external_backup="$TEST_ROOT/external backup"
  local before_index=""

  make_consumer "$symlink_path"
  mkdir -p "$symlink_path/.ai-project" "$external_backup"
  printf '%s\n' 'local agents' > "$symlink_path/AGENTS.md"
  ln -s .ai-project "$symlink_path/ai"
  git -C "$symlink_path" add ai
  before_index="$(git -C "$symlink_path" ls-files --stage)"
  ln -s "$external_backup" "$symlink_path/.ai-base-migration-backup"
  if run_setup "$symlink_path" --migrate-existing; then
    fail 'destino de backup symlink externo deveria abortar no preflight'
  fi
  assert_symlink_target "$symlink_path/ai" '.ai-project'
  [[ "$(git -C "$symlink_path" ls-files --stage)" == "$before_index" ]] || fail 'recusa por backup symlink alterou o índice'
  assert_not_exists "$symlink_path/.gitmodules"

  make_consumer "$regular_path"
  mkdir -p "$regular_path/.ai-project"
  printf '%s\n' 'local agents' > "$regular_path/AGENTS.md"
  ln -s .ai-project "$regular_path/ai"
  git -C "$regular_path" add ai
  before_index="$(git -C "$regular_path" ls-files --stage)"
  printf '%s\n' 'backup blocker' > "$regular_path/.ai-base-migration-backup"
  if run_setup "$regular_path" --migrate-existing; then
    fail 'destino de backup arquivo regular deveria abortar no preflight'
  fi
  assert_symlink_target "$regular_path/ai" '.ai-project'
  [[ "$(git -C "$regular_path" ls-files --stage)" == "$before_index" ]] || fail 'recusa por backup arquivo alterou o índice'
  assert_not_exists "$regular_path/.gitmodules"
}

test_legacy_copy_preserves_modes_with_restrictive_umask() {
  local path="$TEST_ROOT/legacy modes"
  make_consumer "$path"
  mkdir -p "$path/.ai-project/private/nested"
  printf '%s\n' 'mode 777' > "$path/.ai-project/private/open.txt"
  printf '%s\n' 'mode 640' > "$path/.ai-project/private/nested/secret.txt"
  chmod 770 "$path/.ai-project/private"
  chmod 777 "$path/.ai-project/private/open.txt"
  chmod 750 "$path/.ai-project/private/nested"
  chmod 640 "$path/.ai-project/private/nested/secret.txt"
  ln -s .ai-project "$path/ai"
  if ! (umask 022; cd "$path" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE_ROOT" bash "$SCRIPT_ROOT/scripts/setup-consumer.sh") >"$TEST_ROOT/last.out" 2>&1; then
    cat "$TEST_ROOT/last.out" >&2
    fail 'migração com modos explícitos deveria funcionar'
    return
  fi
  assert_mode "$path/ai/private" '770'
  assert_mode "$path/ai/private/open.txt" '777'
  assert_mode "$path/ai/private/nested" '750'
  assert_mode "$path/ai/private/nested/secret.txt" '640'
}

test_legacy_internal_relative_link_is_validated_in_original_context() {
  local path="$TEST_ROOT/legacy internal link"
  make_consumer "$path"
  mkdir -p "$path/.ai-project"
  printf '%s\n' 'local orchestrator' > "$path/.ai-project/local-orchestrator.md"
  ln -s ./local-orchestrator.md "$path/.ai-project/CODEX_ORCHESTRATOR.md"
  ln -s .ai-project "$path/ai"
  if ! run_setup "$path"; then
    cat "$TEST_ROOT/last.out" >&2
    fail 'link relativo interno válido deveria ser aceito durante a migração'
    return
  fi
  assert_symlink_target "$path/ai/CODEX_ORCHESTRATOR.md" 'shared/ai/CODEX_ORCHESTRATOR.md'
  assert_file "$path/ai/local-orchestrator.md"
}

test_legacy_broken_relative_link_is_rejected() {
  local path="$TEST_ROOT/legacy broken internal link"
  make_consumer "$path"
  mkdir -p "$path/.ai-project"
  ln -s ./missing-orchestrator.md "$path/.ai-project/CODEX_ORCHESTRATOR.md"
  ln -s .ai-project "$path/ai"
  if run_setup "$path"; then
    fail 'link relativo interno quebrado deveria abortar'
  fi
  assert_contains "$TEST_ROOT/last.out" 'link quebrado'
  assert_symlink_target "$path/ai" '.ai-project'
  assert_not_exists "$path/.gitmodules"
}

test_manager_configuration() {
  assert_contains "$SCRIPT_ROOT/ai/agents/Manager.toml" 'model = "gpt-5.6-sol"'
  assert_contains "$SCRIPT_ROOT/ai/agents/Manager.toml" 'model_reasoning_effort = "high"'
}

setup_remote
test_legacy_symlink_is_migrated
test_untracked_legacy_symlink
test_tracked_legacy_symlink_only_index_entry
test_idempotence_does_not_use_remote_or_backup
test_existing_copies_and_migrate_backup
test_missing_documents_are_created
test_known_legacy_root_link_is_replaced
test_unexpected_and_broken_links_abort_before_git_mutation
test_preflight_rejects_ambiguous_and_local_document_links
test_preflight_rejects_shared_and_gitmodules_conflicts
test_lock_is_exclusive_and_not_removed_on_conflict
test_preserves_other_git_state
test_rejects_external_submodule_git_metadata_before_update
test_rejects_unrelated_gitmodules_staging_divergence_before_mutation
test_rejects_indented_external_gitmodules_divergence_before_mutation
test_rejects_missing_worktree_gitmodules_with_staged_entry_before_migration
test_rejects_untracked_external_gitmodules_before_migration
test_update_diagnoses_legacy_layout
test_update_existing_submodule
test_bootstrap_configures_before_pending_agents
test_bootstrap_propagates_agent_link_failures
test_bootstrap_propagates_agent_backup_and_move_failures
test_invalid_gitmodules_aborts_before_mutation
test_invalid_existing_submodule_aborts_before_mutation
test_fetch_recurse_submodules_metadata_is_normalized
test_conflicting_backup_destination_aborts_before_legacy_migration
test_legacy_copy_preserves_modes_with_restrictive_umask
test_legacy_internal_relative_link_is_validated_in_original_context
test_legacy_broken_relative_link_is_rejected
test_manager_configuration

if [[ "$failures" -ne 0 ]]; then
  echo "Testes falharam: $failures" >&2
  exit 1
fi

echo 'Testes passaram.'
