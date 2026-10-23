#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode 26.6.app/Contents/Developer}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/ai-base-tests.XXXXXX")"
REMOTE="$TMP/remote.git"; SEED="$TMP/seed"; CONSUMER="$TMP/consumer with spaces"
# A managed file copied after the example skill; the concurrency tests edit it mid-update.
HELPER=".agents/skills/helper/SKILL.md"
trap 'rm -rf "$TMP"' EXIT INT TERM
# Never pull the real AI checkout from the tests; test_self_update_base opts back in.
export AI_SKIP_SELF_UPDATE=1
fail() { echo "FALHA: $*" >&2; exit 1; }
abslink() { [[ -L "$1" && "$(readlink "$1")" == "$2" ]] || fail "link $1"; }
copy() { [[ -f "$1" && ! -L "$1" ]] && cmp -s "$1" "$2" || fail "cópia $1"; }
consumer() { mkdir -p "$1"; git init "$1" >/dev/null; git -C "$1" config user.email test@example.com; git -C "$1" config user.name Tests; }
run_bootstrap() { (cd "$1" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" HOME="$TMP/home" CODEX_CONFIG_DIR="$TMP/codex" bash "$ROOT/scripts/bootstrap-consumer.sh") >"$TMP/out" 2>&1; }
run_update() { (cd "$1" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" HOME="$TMP/home" CODEX_CONFIG_DIR="$TMP/codex" bash "$ROOT/scripts/update-consumer.sh") >"$TMP/out" 2>&1; }
run_update_adopt() { (cd "$1" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" HOME="$TMP/home" CODEX_CONFIG_DIR="$TMP/codex" bash "$ROOT/scripts/update-consumer.sh" --adopt-lint-config) >"$TMP/out" 2>&1; }
run_update_fail() { (cd "$1" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_FAIL_AT="$2" bash "$ROOT/scripts/update-consumer.sh") >"$TMP/out" 2>&1; }
run_bootstrap_fail() { (cd "$1" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_FAIL_AT="$2" bash "$ROOT/scripts/bootstrap-consumer.sh") >"$TMP/out" 2>&1; }
snapshot() { (cd "$1" && { find . -path './.git' -prune -o -type f -print | LC_ALL=C sort | while IFS= read -r f; do shasum -a 256 "$f"; done; find . -path './.git' -prune -o -type l -print | LC_ALL=C sort | while IFS= read -r f; do printf 'LINK %s %s\n' "$f" "$(readlink "$f")"; done; git status --porcelain=v1; git ls-files --stage; git config --local --list | LC_ALL=C sort; test -f .gitmodules && cat .gitmodules || true; test -d .ai/shared && git -C .ai/shared rev-parse HEAD && git -C .ai/shared branch --show-current || true; }) > "$2"; }
seed() {
  git init --bare "$REMOTE" >/dev/null
  mkdir -p "$SEED/.ai" "$SEED/.agents/skills/example/assets" "$SEED/.agents/skills/helper" \
    "$SEED/scripts"
  printf '# agents\n' > "$SEED/AGENTS.md"; printf '# swift\n' > "$SEED/.ai/SWIFT_REFERENCE.md"
  printf 'brief v1\n' > "$SEED/.ai/PROJECT_BRIEF.template.md"; printf 'guide v1\n' > "$SEED/.ai/PROJECT_GUIDE.template.md"
  printf 'helper v1\n' > "$SEED/$HELPER"; printf 'skill v1\n' > "$SEED/.agents/skills/example/SKILL.md"; printf old > "$SEED/.agents/skills/example/a"; printf '\001\002\377' > "$SEED/.agents/skills/example/assets/logo.bin"
  cp "$ROOT/.swiftlint.yml" "$SEED/.swiftlint.yml"
  cp "$ROOT/.swiftformat" "$SEED/.swiftformat"
  for script in lint-swift.sh fix-swift-spacing.pl install-swift-tools.sh add-type-marks.py test-required-type-marks.sh test-swift-spacing.sh; do
    cp "$ROOT/scripts/$script" "$SEED/scripts/$script"; chmod +x "$SEED/scripts/$script"
  done
  git -C "$SEED" init >/dev/null; git -C "$SEED" config user.email test@example.com; git -C "$SEED" config user.name Tests
  git -C "$SEED" add .; git -C "$SEED" commit -m v1 >/dev/null; git -C "$SEED" branch -M main; git -C "$SEED" remote add origin "$REMOTE"; git -C "$SEED" push -u origin main >/dev/null
}
test_lint_tooling_distribution() {
  local p="$TMP/lint-tooling consumer"
  consumer "$p"
  mkdir -p "$p/.github/workflows"
  printf 'consumer build workflow\n' > "$p/.github/workflows/build.yml"
  run_bootstrap "$p" || { cat "$TMP/out"; fail lint-tooling-bootstrap; }
  for rel in .swiftlint.yml .swiftformat scripts/lint-swift.sh scripts/fix-swift-spacing.pl \
    scripts/install-swift-tools.sh scripts/add-type-marks.py; do
    copy "$p/$rel" "$SEED/$rel"
    grep -Fq "  $rel" "$p/.ai/managed-files.sha256" || fail "manifest-$rel"
  done
  [[ ! -e "$p/.github/workflows/swift-lint.yml" ]] || fail workflow-not-distributed
  if grep -Fq '.github/' "$p/.ai/managed-files.sha256"; then fail workflow-not-in-manifest; fi
  for rel in test-required-type-marks.sh test-swift-spacing.sh; do [[ ! -e "$p/scripts/$rel" ]] || fail "base-only-test-installed-$rel"; done
  for rel in lint-swift.sh fix-swift-spacing.pl install-swift-tools.sh add-type-marks.py; do
    [[ -x "$p/scripts/$rel" ]] || fail "lint-scripts-executable-$rel"
  done
  [[ "$(<"$p/.github/workflows/build.yml")" == 'consumer build workflow' ]] || fail unrelated-workflow-preserved
  mkdir -p "$p/Sources/Core" "$p/Tests/CoreTests" "$p/DemoApp/Sources/DemoApp" \
    "$p/DemoApp/Tests" "$p/Packages/Kit/Sources/Kit" "$p/Packages/Kit/Tests" \
    "$p/.ai/shared/Hidden" "$p/.build/Hidden" "$p/.swiftpm/Hidden" \
    "$p/DerivedData/Hidden" "$p/Unrelated/Hidden"
  for rel in Sources/Core/Core.swift Tests/CoreTests/CoreTests.swift \
    DemoApp/Sources/DemoApp/DemoApp.swift DemoApp/Tests/DemoAppTests.swift \
    Packages/Kit/Sources/Kit/Kit.swift Packages/Kit/Tests/KitTests.swift; do
    printf 'struct Probe {}\n' > "$p/$rel"
  done
  printf '// swift-tools-version: 6.0\nimport PackageDescription\n\nlet package = Package(name: "Consumer")\n' > "$p/Package.swift"
  printf '// swift-tools-version: 6.0\nimport PackageDescription\n\nlet package = Package(name: "Kit")\n' > "$p/Packages/Kit/Package.swift"
  for rel in .ai/shared/Hidden/Bad.swift .build/Hidden/Bad.swift .swiftpm/Hidden/Bad.swift \
    DerivedData/Hidden/Bad.swift Unrelated/Hidden/Bad.swift; do
    printf 'final class MissingMark {}\n' > "$p/$rel"
  done
  local vendor_source="$TMP/vendor-source" vendor_remote="$TMP/vendor.git"
  mkdir "$vendor_source"; git init "$vendor_source" >/dev/null
  git -C "$vendor_source" config user.email test@example.com; git -C "$vendor_source" config user.name Tests
  mkdir -p "$vendor_source/Sources/ThirdParty"
  printf 'final class ExternalWithoutMark {}\n' > "$vendor_source/Sources/ThirdParty/Bad.swift"
  git -C "$vendor_source" add .; git -C "$vendor_source" commit -m fixture >/dev/null
  git clone --bare "$vendor_source" "$vendor_remote" >/dev/null
  git -C "$p" -c protocol.file.allow=always submodule add "$vendor_remote" \
    DemoApp/Sources/DemoApp/External >/dev/null
  git -C "$p" -c protocol.file.allow=always submodule add "$vendor_remote" \
    Packages/Vendor >/dev/null
  printf '// swift-tools-version: 6.0\nimport PackageDescription\n\nlet package = Package(name: "External")\n' \
    > "$p/Packages/Vendor/Package.swift"
  git -C "$p/.ai/shared" add Hidden/Bad.swift
  git -C "$p/.ai/shared" -c user.email=test@example.com -c user.name=Tests \
    commit -m 'fixture excluded from lint' >/dev/null
  git -C "$p" add .ai/shared
  (cd "$p" && DEVELOPER_DIR="$TEST_DEVELOPER_DIR" bash scripts/lint-swift.sh) > "$TMP/lint-gate.out" 2>&1 || {
    cat "$TMP/lint-gate.out" >&2
    fail lint-gate-supported-layouts
  }
  for rel in Sources/Core/Core.swift Tests/CoreTests/CoreTests.swift \
    DemoApp/Sources/DemoApp/DemoApp.swift DemoApp/Tests/DemoAppTests.swift \
    Packages/Kit/Sources/Kit/Kit.swift Packages/Kit/Tests/KitTests.swift Package.swift \
    Packages/Kit/Package.swift; do
    grep -Fq "$rel" "$TMP/lint-gate.out" || fail "lint-gate-missing-$rel"
  done
  for rel in .ai/shared/Hidden/Bad.swift .build/Hidden/Bad.swift .swiftpm/Hidden/Bad.swift \
    DerivedData/Hidden/Bad.swift Unrelated/Hidden/Bad.swift \
    DemoApp/Sources/DemoApp/External/Sources/ThirdParty/Bad.swift \
    Packages/Vendor/Sources/ThirdParty/Bad.swift Packages/Vendor/Package.swift; do
    if grep -Fq "$rel" "$TMP/lint-gate.out"; then fail "lint-gate-unrelated-$rel"; fi
  done
  local no_swift="$TMP/no-swift"; consumer "$no_swift"; run_bootstrap "$no_swift" || fail no-swift-bootstrap
  if (cd "$no_swift" && DEVELOPER_DIR="$TEST_DEVELOPER_DIR" bash scripts/lint-swift.sh) > "$TMP/no-swift.out" 2>&1; then fail lint-gate-requires-swift; fi
  grep -Fq 'No Swift sources' "$TMP/no-swift.out" || fail lint-gate-empty-diagnostic

  local rollback="$TMP/rollback-new-dirs" rollback_empty="$TMP/rollback-empty-dirs"
  consumer "$rollback"
  if (cd "$rollback" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" \
    AI_TEST_FAIL_AT=after-lint-gate bash "$ROOT/scripts/bootstrap-consumer.sh") > "$TMP/lint-rollback.out" 2>&1; then
    fail lint-gate-bootstrap-rollback
  fi
  [[ ! -e "$rollback/scripts" && ! -e "$rollback/.github" ]] || fail lint-rollback-created-directories
  consumer "$rollback_empty"; mkdir -p "$rollback_empty/scripts" "$rollback_empty/.github/workflows"
  if (cd "$rollback_empty" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" \
    AI_TEST_FAIL_AT=after-lint-gate bash "$ROOT/scripts/bootstrap-consumer.sh") > "$TMP/lint-rollback-empty.out" 2>&1; then
    fail lint-gate-empty-dir-rollback
  fi
  [[ -d "$rollback_empty/scripts" && -z "$(ls -A "$rollback_empty/scripts")" ]] || fail preserve-empty-scripts
  [[ -d "$rollback_empty/.github/workflows" && -z "$(ls -A "$rollback_empty/.github/workflows")" ]] || fail preserve-empty-workflow-dirs
  local before_update="$TMP/lint-gate-update-before"
  snapshot "$p" "$before_update"
  if run_update_fail "$p" after-lint-gate; then fail lint-gate-update-rollback; fi
  snapshot "$p" "$TMP/lint-gate-update-after"
  cmp -s "$before_update" "$TMP/lint-gate-update-after" || fail lint-gate-update-rollback-state

  local workflow_conflict="$TMP/workflow-conflict" config_link="$TMP/config-link" outside="$TMP/config-outside"
  consumer "$workflow_conflict"; mkdir -p "$workflow_conflict/.github/workflows"
  printf 'consumer workflow\n' > "$workflow_conflict/.github/workflows/swift-lint.yml"
  run_bootstrap "$workflow_conflict" || { cat "$TMP/out"; fail consumer-workflow-bootstrap; }
  [[ "$(<"$workflow_conflict/.github/workflows/swift-lint.yml")" == 'consumer workflow' ]] || fail consumer-workflow-preserved
  if grep -Fq '.github/' "$workflow_conflict/.ai/managed-files.sha256"; then fail consumer-workflow-unmanaged; fi
  consumer "$config_link"; mkdir "$outside"; printf outside-config > "$outside/formatter"
  ln -s "$outside/formatter" "$config_link/.swiftformat"
  if run_bootstrap "$config_link"; then fail formatter-symlink-conflict; fi
  [[ -L "$config_link/.swiftformat" && "$(<"$outside/formatter")" == outside-config && ! -e "$config_link/.ai/shared" ]] || fail formatter-symlink-preserved

  run_bootstrap "$p" || { cat "$TMP/out"; fail lint-tooling-idempotence; }
}
# CI puts the pinned tools on PATH; a newer Homebrew SwiftFormat on the runner must not win.
test_lint_gate_prefers_caller_path() {
  local p="$TMP/caller-path consumer" stub="$TMP/caller-path-bin" marker="$TMP/caller-path-used" version
  version="$(sed -n 's/^readonly SWIFTFORMAT_VERSION="\(.*\)"$/\1/p' "$ROOT/scripts/lint-swift.sh")"
  consumer "$p"; run_bootstrap "$p" || { cat "$TMP/out"; fail caller-path-bootstrap; }
  mkdir -p "$p/Sources/Core" "$stub"; printf 'struct Probe {}\n' > "$p/Sources/Core/Core.swift"
  printf '#!/usr/bin/env bash\ntouch %q\n[[ "${1:-}" == --version ]] && echo %q\nexit 0\n' "$marker" "$version" > "$stub/swiftformat"
  chmod +x "$stub/swiftformat"
  (cd "$p" && PATH="$stub:$PATH" bash scripts/lint-swift.sh --format-only) > "$TMP/caller-path.out" 2>&1 || {
    cat "$TMP/caller-path.out" >&2
    fail lint-gate-caller-path-run
  }
  [[ -e "$marker" ]] || fail lint-gate-prefers-caller-path
}
# Simulates a consumer set up by a base that still distributed the file $2 with content $3.
install_legacy_file() {
  local p="$1" rel="$2" manifest="$1/.ai/managed-files.sha256" hash
  mkdir -p "$p/$(dirname "$rel")"; printf '%s\n' "$3" > "$p/$rel"
  hash="$(shasum -a 256 "$p/$rel" | awk '{print $1}')"
  { cat "$manifest"; printf '%s  %s\n' "$hash" "$rel"; } | LC_ALL=C sort -b -k2 > "$TMP/legacy-manifest"
  cp "$TMP/legacy-manifest" "$manifest"
}
install_legacy_workflow() { install_legacy_file "$1" .github/workflows/swift-lint.yml 'name: Swift lint'; }
install_legacy_agents() { install_legacy_file "$1" .codex/agents/luna.toml 'name = "luna"'; install_legacy_file "$1" .codex/agents/sol.toml 'name = "sol"'; }
test_retired_workflow() {
  local intact="$TMP/retired intact" deleted="$TMP/retired deleted" edited="$TMP/retired edited" rollback="$TMP/retired rollback" before="$TMP/retired-rollback-before" p
  for p in "$intact" "$deleted" "$edited" "$rollback"; do
    consumer "$p"; run_bootstrap "$p" || { cat "$TMP/out"; fail retired-bootstrap; }
    install_legacy_workflow "$p"
  done
  run_update "$intact" || { cat "$TMP/out"; fail retired-intact-update; }
  [[ ! -e "$intact/.github" ]] || fail retired-intact-removed
  if grep -Fq '.github/' "$intact/.ai/managed-files.sha256"; then fail retired-intact-manifest; fi
  rm "$deleted/.github/workflows/swift-lint.yml"
  run_update "$deleted" || { cat "$TMP/out"; fail retired-deleted-update; }
  if grep -Fq '.github/' "$deleted/.ai/managed-files.sha256"; then fail retired-deleted-manifest; fi
  run_update "$deleted" || { cat "$TMP/out"; fail retired-deleted-idempotent; }
  printf 'consumer tweak\n' >> "$edited/.github/workflows/swift-lint.yml"
  run_update "$edited" || { cat "$TMP/out"; fail retired-edited-update; }
  grep -Fq 'consumer tweak' "$edited/.github/workflows/swift-lint.yml" || fail retired-edited-preserved
  grep -Fq '.github/workflows/swift-lint.yml' "$TMP/out" || { cat "$TMP/out"; fail retired-edited-warning; }
  if grep -Fq '.github/' "$edited/.ai/managed-files.sha256"; then fail retired-edited-manifest; fi
  snapshot "$rollback" "$before"
  if run_update_fail "$rollback" after-claude-skills; then fail retired-rollback; fi
  snapshot "$rollback" "$TMP/retired-rollback-after"
  cmp -s "$before" "$TMP/retired-rollback-after" || { diff -u "$before" "$TMP/retired-rollback-after" >&2 || true; fail retired-rollback-state; }
}
test_retired_agents() {
  local intact="$TMP/agents intact" deleted="$TMP/agents deleted" edited="$TMP/agents edited" custom="$TMP/agents custom" rollback="$TMP/agents rollback" before="$TMP/agents-rollback-before" p
  for p in "$intact" "$deleted" "$edited" "$custom" "$rollback"; do
    consumer "$p"; run_bootstrap "$p" || { cat "$TMP/out"; fail retired-agents-bootstrap; }
    install_legacy_agents "$p"
  done
  run_update "$intact" || { cat "$TMP/out"; fail retired-agents-intact-update; }
  [[ ! -e "$intact/.codex" ]] || fail retired-agents-intact-removed
  if grep -Fq '.codex/' "$intact/.ai/managed-files.sha256"; then fail retired-agents-intact-manifest; fi
  grep -Fq 'Arquivo removido (não é mais distribuído pela base): .codex/agents/sol.toml' "$TMP/out" || { cat "$TMP/out"; fail retired-agents-message; }
  rm "$deleted/.codex/agents/luna.toml"
  run_update "$deleted" || { cat "$TMP/out"; fail retired-agents-deleted-update; }
  [[ ! -e "$deleted/.codex" ]] || fail retired-agents-deleted-removed
  if grep -Fq '.codex/' "$deleted/.ai/managed-files.sha256"; then fail retired-agents-deleted-manifest; fi
  printf 'model = "local"\n' >> "$edited/.codex/agents/sol.toml"
  run_update "$edited" || { cat "$TMP/out"; fail retired-agents-edited-update; }
  grep -Fq 'model = "local"' "$edited/.codex/agents/sol.toml" || fail retired-agents-edited-preserved
  [[ ! -e "$edited/.codex/agents/luna.toml" ]] || fail retired-agents-edited-intact-removed
  grep -Fq '.codex/agents/sol.toml não é mais distribuído' "$TMP/out" || { cat "$TMP/out"; fail retired-agents-edited-warning; }
  if grep -Fq '.codex/' "$edited/.ai/managed-files.sha256"; then fail retired-agents-edited-manifest; fi
  run_update "$edited" || { cat "$TMP/out"; fail retired-agents-edited-idempotent; }
  printf 'custom agent\n' > "$custom/.codex/agents/custom.toml"
  run_update "$custom" || { cat "$TMP/out"; fail retired-agents-custom-update; }
  [[ "$(<"$custom/.codex/agents/custom.toml")" == 'custom agent' && ! -e "$custom/.codex/agents/sol.toml" && ! -e "$custom/.codex/agents/luna.toml" ]] || fail retired-agents-custom-preserved
  snapshot "$rollback" "$before"
  if run_update_fail "$rollback" after-claude-skills; then fail retired-agents-rollback; fi
  snapshot "$rollback" "$TMP/agents-rollback-after"
  cmp -s "$before" "$TMP/agents-rollback-after" || { diff -u "$before" "$TMP/agents-rollback-after" >&2 || true; fail retired-agents-rollback-state; }
}
# Project documents are never rewritten; the update only points out wording that named the fixed agents.
test_stale_agent_references() {
  local p="$TMP/stale guide"
  consumer "$p"; run_bootstrap "$p" || { cat "$TMP/out"; fail stale-guide-bootstrap; }
  if grep -Fq 'cita os agentes fixos' "$TMP/out"; then fail stale-guide-false-positive; fi
  printf 'intro\n- Planejamento: `sol` (papel conceitual Manager)\nOs IDs vêm dos TOML compartilhados.\n' > "$p/.ai/PROJECT_GUIDE.md"
  cp "$p/.ai/PROJECT_GUIDE.md" "$TMP/stale-guide-before"
  run_update "$p" || { cat "$TMP/out"; fail stale-guide-update; }
  grep -Fq '.ai/PROJECT_GUIDE.md cita os agentes fixos sol/luna ou seus TOML (linhas 2,3)' "$TMP/out" || { cat "$TMP/out"; fail stale-guide-warning; }
  cmp -s "$p/.ai/PROJECT_GUIDE.md" "$TMP/stale-guide-before" || fail stale-guide-preserved
}
# Earlier versions linked .ai/CODEX_ORCHESTRATOR.md into consumers; only that exact link is removed.
test_retired_orchestrator_link() {
  local linked="$TMP/orchestrator linked" local_file="$TMP/orchestrator local" other="$TMP/orchestrator other" stale="$TMP/orchestrator stale" rollback="$TMP/orchestrator rollback" before="$TMP/orchestrator-rollback-before" p
  for p in "$linked" "$local_file" "$other" "$stale" "$rollback"; do
    consumer "$p"; run_bootstrap "$p" || { cat "$TMP/out"; fail retired-orchestrator-bootstrap; }
  done
  for p in "$linked" "$rollback"; do ln -s shared/.ai/CODEX_ORCHESTRATOR.md "$p/.ai/CODEX_ORCHESTRATOR.md"; done
  run_update "$linked" || { cat "$TMP/out"; fail retired-orchestrator-update; }
  [[ ! -e "$linked/.ai/CODEX_ORCHESTRATOR.md" && ! -L "$linked/.ai/CODEX_ORCHESTRATOR.md" ]] || fail retired-orchestrator-removed
  grep -Fq 'Link removido (o orquestrador agora faz parte de AGENTS.md): .ai/CODEX_ORCHESTRATOR.md' "$TMP/out" || { cat "$TMP/out"; fail retired-orchestrator-message; }
  run_update "$linked" || { cat "$TMP/out"; fail retired-orchestrator-idempotent; }
  printf 'local notes\n' > "$local_file/.ai/CODEX_ORCHESTRATOR.md"
  run_update "$local_file" || { cat "$TMP/out"; fail retired-orchestrator-local-update; }
  [[ -f "$local_file/.ai/CODEX_ORCHESTRATOR.md" && ! -L "$local_file/.ai/CODEX_ORCHESTRATOR.md" && "$(<"$local_file/.ai/CODEX_ORCHESTRATOR.md")" == 'local notes' ]] || fail retired-orchestrator-local-preserved
  ln -s ../notes.md "$other/.ai/CODEX_ORCHESTRATOR.md"
  run_update "$other" || { cat "$TMP/out"; fail retired-orchestrator-other-update; }
  abslink "$other/.ai/CODEX_ORCHESTRATOR.md" ../notes.md
  printf 'intro\nDetalhes em `.ai/CODEX_ORCHESTRATOR.md`.\n' > "$stale/.ai/PROJECT_GUIDE.md"; cp "$stale/.ai/PROJECT_GUIDE.md" "$TMP/orchestrator-guide-before"
  run_update "$stale" || { cat "$TMP/out"; fail retired-orchestrator-stale-update; }
  grep -Fq '.ai/PROJECT_GUIDE.md cita .ai/CODEX_ORCHESTRATOR.md (linhas 2)' "$TMP/out" || { cat "$TMP/out"; fail retired-orchestrator-stale-warning; }
  cmp -s "$stale/.ai/PROJECT_GUIDE.md" "$TMP/orchestrator-guide-before" || fail retired-orchestrator-stale-preserved
  snapshot "$rollback" "$before"
  if run_update_fail "$rollback" after-claude-skills; then fail retired-orchestrator-rollback; fi
  snapshot "$rollback" "$TMP/orchestrator-rollback-after"
  cmp -s "$before" "$TMP/orchestrator-rollback-after" || { diff -u "$before" "$TMP/orchestrator-rollback-after" >&2 || true; fail retired-orchestrator-rollback-state; }
}
test_lint_config_adoption() {
  local p="$TMP/adopt consumer" manifest
  consumer "$p"; run_bootstrap "$p" || { cat "$TMP/out"; fail adopt-bootstrap; }
  manifest="$p/.ai/managed-files.sha256"
  # Simulate a consumer whose lint configuration predates the managed files.
  grep -v '  \.swiftlint\.yml$' "$manifest" > "$TMP/manifest"; cp "$TMP/manifest" "$manifest"
  printf 'consumer lint rules\n' > "$p/.swiftlint.yml"
  if run_update "$p"; then fail adopt-requires-flag; fi
  grep -Fq -- '--adopt-lint-config' "$TMP/out" || { cat "$TMP/out"; fail adopt-hint; }
  [[ "$(<"$p/.swiftlint.yml")" == 'consumer lint rules' && ! -e "$p/.swiftlint.yml.local-backup" ]] || fail adopt-conflict-preserves
  run_update_adopt "$p" || { cat "$TMP/out"; fail adopt-update; }
  copy "$p/.swiftlint.yml" "$SEED/.swiftlint.yml"
  [[ "$(<"$p/.swiftlint.yml.local-backup")" == 'consumer lint rules' ]] || fail adopt-backup
  grep -Fq '  .swiftlint.yml' "$manifest" || fail adopt-manifest
  run_update "$p" || { cat "$TMP/out"; fail adopt-idempotent-update; }
  grep -v '  \.swiftlint\.yml$' "$manifest" > "$TMP/manifest"; cp "$TMP/manifest" "$manifest"
  printf 'consumer lint rules again\n' > "$p/.swiftlint.yml"
  if run_update_adopt "$p"; then fail adopt-existing-backup; fi
  [[ "$(<"$p/.swiftlint.yml")" == 'consumer lint rules again' ]] || fail adopt-existing-backup-preserves
}
test_adoption_rollback() {
  local p="$TMP/adopt rollback" manifest before="$TMP/adopt-rollback-before"
  consumer "$p"; run_bootstrap "$p" || { cat "$TMP/out"; fail adopt-rollback-bootstrap; }
  manifest="$p/.ai/managed-files.sha256"
  grep -v '  \.swiftlint\.yml$' "$manifest" > "$TMP/manifest"; cp "$TMP/manifest" "$manifest"
  printf 'consumer lint rules\n' > "$p/.swiftlint.yml"
  snapshot "$p" "$before"
  if (cd "$p" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_FAIL_AT=during-copy \
    bash "$ROOT/scripts/update-consumer.sh" --adopt-lint-config) > "$TMP/out" 2>&1; then fail adopt-rollback; fi
  snapshot "$p" "$TMP/adopt-rollback-after"
  cmp -s "$before" "$TMP/adopt-rollback-after" || { diff -u "$before" "$TMP/adopt-rollback-after" >&2 || true; fail adopt-rollback-state; }
}
test_setup_runs_from_main() {
  local p="$TMP/reexec consumer"
  consumer "$p"; run_bootstrap "$p" || { cat "$TMP/out"; fail reexec-bootstrap; }
  mkdir -p "$SEED/scripts"
  { head -n 2 "$ROOT/scripts/setup-consumer.sh"; echo 'echo "setup from main" >&2'; tail -n +3 "$ROOT/scripts/setup-consumer.sh"; } > "$SEED/scripts/setup-consumer.sh"
  git -C "$SEED" add -A; git -C "$SEED" commit -m reexec >/dev/null; git -C "$SEED" push >/dev/null
  run_update "$p" || { cat "$TMP/out"; fail reexec-update; }
  grep -Fq 'setup from main' "$TMP/out" || { cat "$TMP/out"; fail reexec-main-script; }
  grep -Fq 'desatualizada' "$TMP/out" || fail reexec-warning
  if ls "${TMPDIR:-/tmp}"/ai-setup.* >/dev/null 2>&1; then fail reexec-temp-cleanup; fi
  git -C "$SEED" rm -q scripts/setup-consumer.sh; git -C "$SEED" commit -m unreexec >/dev/null; git -C "$SEED" push >/dev/null
}
test_self_update_base() {
  local origin="$TMP/ai-origin.git" local_ai="$TMP/local-ai" publisher="$TMP/ai-publisher" p="$TMP/self-update consumer" head
  git init -q "$TMP/ai-source"; cp -R "$ROOT/scripts" "$TMP/ai-source/scripts"
  git -C "$TMP/ai-source" -c user.email=test@example.com -c user.name=Tests add -A
  git -C "$TMP/ai-source" -c user.email=test@example.com -c user.name=Tests commit -qm base
  git -C "$TMP/ai-source" branch -M main
  git clone -q --bare "$TMP/ai-source" "$origin"
  git clone -q "$origin" "$local_ai"; git clone -q "$origin" "$publisher"
  { head -n 2 "$publisher/scripts/update-consumer.sh"; echo 'echo "update from pulled base" >&2'; tail -n +3 "$publisher/scripts/update-consumer.sh"; } > "$TMP/update.sh"
  cp "$TMP/update.sh" "$publisher/scripts/update-consumer.sh"
  git -C "$publisher" -c user.email=test@example.com -c user.name=Tests commit -qam 'newer base'
  git -C "$publisher" push -q origin main
  consumer "$p"; run_bootstrap "$p" || { cat "$TMP/out"; fail self-update-bootstrap; }
  printf 'local edit\n' >> "$local_ai/scripts/consumer-next-steps.txt"
  (cd "$p" && env -u AI_SKIP_SELF_UPDATE GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" \
    bash "$local_ai/scripts/update-consumer.sh") > "$TMP/out" 2>&1 || { cat "$TMP/out"; fail self-update-dirty-run; }
  grep -Fq 'alterações locais' "$TMP/out" || { cat "$TMP/out"; fail self-update-dirty-warning; }
  if grep -Fq 'update from pulled base' "$TMP/out"; then fail self-update-dirty-pulled; fi
  git -C "$local_ai" checkout -q -- scripts/consumer-next-steps.txt
  (cd "$p" && env -u AI_SKIP_SELF_UPDATE GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" \
    bash "$local_ai/scripts/update-consumer.sh") > "$TMP/out" 2>&1 || { cat "$TMP/out"; fail self-update-run; }
  grep -Fq 'Base AI atualizada' "$TMP/out" || { cat "$TMP/out"; fail self-update-message; }
  grep -Fq 'update from pulled base' "$TMP/out" || { cat "$TMP/out"; fail self-update-reexec; }
  [[ "$(grep -Fc 'update from pulled base' "$TMP/out")" == 1 ]] || fail self-update-single-reexec
  head="$(git -C "$local_ai" rev-parse HEAD)"
  [[ "$head" == "$(git -C "$origin" rev-parse main)" ]] || fail self-update-fast-forward
}
test_claude_skills() {
  local p="$TMP/claude consumer" q="$TMP/claude existing" r="$TMP/claude rollback" before="$TMP/claude-before"
  consumer "$p"; run_bootstrap "$p" || { cat "$TMP/out"; fail claude-bootstrap; }
  abslink "$p/.claude/skills/example" '../../.agents/skills/example'
  [[ -f "$p/.claude/skills/example/SKILL.md" ]] || fail claude-skill-resolves
  grep -Fqx '@AGENTS.md' "$p/CLAUDE.md" || fail claude-md-import
  git -C "$p" add -A; run_update "$p" || { cat "$TMP/out"; fail claude-idempotent-update; }
  git -C "$p" diff --quiet -- .claude CLAUDE.md && [[ -z "$(git -C "$p" ls-files --others --exclude-standard -- .claude CLAUDE.md)" ]] || fail claude-idempotent-state
  consumer "$q"; printf 'consumer claude rules\n' > "$q/CLAUDE.md"; mkdir -p "$q/.claude/skills/example"
  printf 'local skill\n' > "$q/.claude/skills/example/SKILL.md"
  run_bootstrap "$q" || { cat "$TMP/out"; fail claude-existing-bootstrap; }
  [[ "$(<"$q/CLAUDE.md")" == 'consumer claude rules' && "$(<"$q/.claude/skills/example/SKILL.md")" == 'local skill' ]] || fail claude-existing-preserved
  grep -Fq '.claude/skills/example já existe' "$TMP/out" || fail claude-existing-warning
  consumer "$r"; snapshot "$r" "$before"
  if run_bootstrap_fail "$r" after-claude-skills; then fail claude-rollback; fi
  snapshot "$r" "$TMP/claude-after"
  cmp -s "$before" "$TMP/claude-after" || { diff -u "$before" "$TMP/claude-after" >&2 || true; fail claude-rollback-state; }
  [[ ! -e "$r/.claude" && ! -e "$r/CLAUDE.md" ]] || fail claude-rollback-files
}
test_layout_and_idempotence() {
  consumer "$CONSUMER"; printf 'consumer readme\n' > "$CONSUMER/README.md"; run_bootstrap "$CONSUMER" || { cat "$TMP/out"; fail bootstrap; }
  [[ -d "$CONSUMER/.ai/shared" ]] || fail submodule; abslink "$CONSUMER/AGENTS.md" '.ai/shared/AGENTS.md'; [[ ! -e "$CONSUMER/.ai/CODEX_ORCHESTRATOR.md" && ! -L "$CONSUMER/.ai/CODEX_ORCHESTRATOR.md" ]] || fail orchestrator-linked; abslink "$CONSUMER/.ai/SWIFT_REFERENCE.md" 'shared/.ai/SWIFT_REFERENCE.md'
  copy "$CONSUMER/$HELPER" "$SEED/$HELPER"; [[ ! -e "$CONSUMER/.codex" ]] || fail agents-installed; copy "$CONSUMER/.agents/skills/example/SKILL.md" "$SEED/.agents/skills/example/SKILL.md"; copy "$CONSUMER/.agents/skills/example/assets/logo.bin" "$SEED/.agents/skills/example/assets/logo.bin"
  [[ "$(<"$CONSUMER/README.md")" == 'consumer readme' ]] || fail README; [[ ! -e "$TMP/home/.codex" && ! -e "$TMP/codex" ]] || fail global-write; run_bootstrap "$CONSUMER" || { cat "$TMP/out"; fail idempotence; }
}
test_backup_and_preflight() {
  local p="$TMP/backup"; consumer "$p"; printf local > "$p/AGENTS.md"; run_bootstrap "$p" || fail backup; [[ "$(<"$p/AGENTS_backup.md")" == local ]] || fail backup-content
  local q="$TMP/backup-conflict"; consumer "$q"; printf local > "$q/AGENTS.md"; printf old > "$q/AGENTS_backup.md"; if run_bootstrap "$q"; then fail backup-conflict; fi; [[ ! -e "$q/.ai/shared" ]] || fail preflight-mutation
}
test_documents_and_conflicts() {
  local p="$TMP/documents"; consumer "$p"; mkdir "$p/.ai"; printf own > "$p/.ai/PROJECT_BRIEF.md"; printf own-guide > "$p/.ai/PROJECT_GUIDE.md"; run_bootstrap "$p" || fail docs; [[ "$(<"$p/.ai/PROJECT_BRIEF.md")" == own && "$(<"$p/.ai/PROJECT_GUIDE.md")" == own-guide ]] || fail docs-preserved
  local q="$TMP/conflict"; consumer "$q"; mkdir -p "$q/.agents/skills/helper"; printf mine > "$q/$HELPER"; if run_bootstrap "$q"; then fail managed-conflict; fi; [[ "$(<"$q/$HELPER")" == mine ]] || fail conflict-overwrite
}
test_update_safety() {
  local p="$TMP/update"; consumer "$p"; run_bootstrap "$p" || fail update-bootstrap; printf extra > "$p/.agents/skills/custom.txt"; mkdir -p "$p/.codex/agents"; printf agent-extra > "$p/.codex/agents/custom.toml"
  printf 'helper v2\n' > "$SEED/$HELPER"; rm "$SEED/.agents/skills/example/a"; printf new > "$SEED/.agents/skills/example/ab"; printf 'skill v2\n' > "$SEED/.agents/skills/example/SKILL.md"; git -C "$SEED" add -A; git -C "$SEED" commit -m v2 >/dev/null; git -C "$SEED" push >/dev/null
  run_update "$p" || { cat "$TMP/out"; fail update; }; [[ "$(<"$p/$HELPER")" == 'helper v2' ]] || fail update-copy; [[ -e "$p/.agents/skills/example/SKILL.md" && ! -e "$p/.agents/skills/example/a" && -e "$p/.agents/skills/example/ab" ]] || fail exact-obsolete-removal; [[ "$(<"$p/.agents/skills/custom.txt")" == extra && "$(<"$p/.codex/agents/custom.toml")" == agent-extra ]] || fail extras
  printf local-lint-edit > "$p/.swiftlint.yml"
  printf 'config marker\n' > "$SEED/.agents/skills/example/config-update-marker"; git -C "$SEED" add -A; git -C "$SEED" commit -m config-update >/dev/null; git -C "$SEED" push >/dev/null
  if run_update "$p"; then fail edited-lint-config; fi
  [[ "$(<"$p/.swiftlint.yml")" == local-lint-edit ]] || fail edited-lint-config-overwrite
  cp "$SEED/.swiftlint.yml" "$p/.swiftlint.yml"
  printf edited > "$p/$HELPER"; printf 'helper v3\n' > "$SEED/$HELPER"; git -C "$SEED" add -A; git -C "$SEED" commit -m v3 >/dev/null; git -C "$SEED" push >/dev/null; if run_update "$p"; then fail edited-managed; fi; [[ "$(<"$p/$HELPER")" == edited ]] || fail edited-overwrite
}
test_old_paths_and_missing_dependency() {
  local p="$TMP/old-symlink" q="$TMP/missing-reference" outside="$TMP/outside-old" before="$TMP/missing-before"; consumer "$p"; run_bootstrap "$p" || fail old-bootstrap; mkdir "$outside"; printf outside > "$outside/ab"; rm -rf "$p/.agents/skills/example"; ln -s "$outside" "$p/.agents/skills/example"; rm "$SEED/.agents/skills/example/ab"; git -C "$SEED" add -A; git -C "$SEED" commit -m remove-ab >/dev/null; git -C "$SEED" push >/dev/null; if run_update "$p"; then fail old-symlink; fi; [[ "$(<"$outside/ab")" == outside ]] || fail outside-overwrite
  consumer "$q"; run_bootstrap "$q" || fail missing-reference-bootstrap; snapshot "$q" "$before"; git -C "$SEED" rm -q .ai/SWIFT_REFERENCE.md; git -C "$SEED" commit -m remove-reference >/dev/null; git -C "$SEED" push >/dev/null; if run_update "$q"; then fail missing-reference; fi; grep -Fq 'dependência sem .ai/SWIFT_REFERENCE.md' "$TMP/out" || fail missing-reference-message; snapshot "$q" "$TMP/missing-after"; cmp -s "$before" "$TMP/missing-after" || fail missing-reference-mutation
  git -C "$SEED" checkout -q HEAD~1 -- .ai/SWIFT_REFERENCE.md; git -C "$SEED" commit -qm restore-reference; git -C "$SEED" push >/dev/null
}
test_remote_advance_after_candidate() {
  local p="$TMP/candidate-race" gate="$TMP/candidate-gate" candidate pid attempts=0; consumer "$p"; mkdir "$gate"; candidate="$(git -C "$SEED" rev-parse HEAD)"
  (cd "$p" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_CANDIDATE="$gate" bash "$ROOT/scripts/bootstrap-consumer.sh") >"$TMP/race.out" 2>&1 & pid=$!
  while [[ ! -f "$gate/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done
  [[ -f "$gate/ready" ]] || fail candidate-pause
  git -C "$SEED" checkout --orphan rewritten >/dev/null; git -C "$SEED" reset >/dev/null; printf rewritten > "$SEED/.agents/skills/example/race-marker"; git -C "$SEED" add -A; git -C "$SEED" commit -m rewritten >/dev/null; git -C "$SEED" push --force origin rewritten:main >/dev/null; git -C "$SEED" branch --set-upstream-to=origin/main rewritten >/dev/null; git -C "$SEED" config push.default upstream
  : > "$gate/continue"; wait "$pid" || { cat "$TMP/race.out"; fail candidate-race; }
  [[ "$(git -C "$p/.ai/shared" rev-parse HEAD)" == "$candidate" ]] || fail candidate-head; [[ ! -e "$p/.agents/skills/example/race-marker" ]] || fail candidate-content
}
test_edit_during_candidate_pause() {
  local p="$TMP/concurrent-edit" gate="$TMP/concurrent-gate" pid attempts=0; consumer "$p"; run_bootstrap "$p" || fail concurrent-bootstrap; mkdir "$gate"; printf remote > "$SEED/$HELPER"; git -C "$SEED" add -A; git -C "$SEED" commit -m concurrent >/dev/null; git -C "$SEED" push >/dev/null
  (cd "$p" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_CANDIDATE="$gate" bash "$ROOT/scripts/update-consumer.sh") >"$TMP/concurrent.out" 2>&1 & pid=$!; while [[ ! -f "$gate/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate/ready" ]] || fail concurrent-pause; printf user-edit > "$p/$HELPER"; : > "$gate/continue"; if wait "$pid"; then fail concurrent-update; fi; [[ "$(<"$p/$HELPER")" == user-edit ]] || fail concurrent-overwrite
}
test_edit_after_backup_pause() {
  local p="$TMP/edit-after-backup" gate="$TMP/edit-after-backup-gate" before="$TMP/edit-after-backup-before" pid attempts=0; consumer "$p"; run_bootstrap "$p" || fail backup-pause-bootstrap; printf remote-backup > "$SEED/$HELPER"; git -C "$SEED" add -A; git -C "$SEED" commit -m backup-pause >/dev/null; git -C "$SEED" push >/dev/null; snapshot "$p" "$before"; mkdir "$gate"
  (cd "$p" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_BACKUP="$gate" bash "$ROOT/scripts/update-consumer.sh") >"$TMP/backup-pause.out" 2>&1 & pid=$!; while [[ ! -f "$gate/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate/ready" ]] || fail backup-pause-ready; printf user-edit > "$p/$HELPER"; : > "$gate/continue"; if wait "$pid"; then fail backup-pause-update; fi; [[ "$(<"$p/$HELPER")" == user-edit ]] || fail backup-pause-overwrite; [[ -f "$p/.ai/managed-files.sha256" && -f "$p/.agents/skills/example/SKILL.md" && -d "$p/.ai/shared" ]] || fail backup-pause-state
}
test_new_collision_after_backup_pause() {
  local p="$TMP/new-after-backup" gate="$TMP/new-after-backup-gate" pid attempts=0; consumer "$p"; run_bootstrap "$p" || fail new-backup-bootstrap; printf upstream-new > "$SEED/.agents/skills/example/new-after-backup"; git -C "$SEED" add -A; git -C "$SEED" commit -m new-backup >/dev/null; git -C "$SEED" push >/dev/null; mkdir "$gate"
  (cd "$p" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_BACKUP="$gate" bash "$ROOT/scripts/update-consumer.sh") >"$TMP/new-backup.out" 2>&1 & pid=$!; while [[ ! -f "$gate/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate/ready" ]] || fail new-backup-ready; printf user-new > "$p/.agents/skills/example/new-after-backup"; : > "$gate/continue"; if wait "$pid"; then fail new-backup-update; fi; [[ "$(<"$p/.agents/skills/example/new-after-backup")" == user-new ]] || fail new-backup-overwrite
}
test_edit_after_first_copy_pause() {
  local p="$TMP/edit-after-copy" gate="$TMP/edit-after-copy-gate" before="$TMP/edit-after-copy-before" pid attempts=0 old_skill; consumer "$p"; run_bootstrap "$p" || fail first-copy-bootstrap; old_skill="$(<"$p/.agents/skills/example/SKILL.md")"; printf upstream-skill > "$SEED/.agents/skills/example/SKILL.md"; printf upstream-helper > "$SEED/$HELPER"; git -C "$SEED" add -A; git -C "$SEED" commit -m first-copy >/dev/null; git -C "$SEED" push >/dev/null; snapshot "$p" "$before"; mkdir "$gate"
  (cd "$p" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_FIRST_COPY="$gate" bash "$ROOT/scripts/update-consumer.sh") >"$TMP/first-copy.out" 2>&1 & pid=$!; while [[ ! -f "$gate/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate/ready" ]] || fail first-copy-ready; printf user-edit > "$p/$HELPER"; : > "$gate/continue"; if wait "$pid"; then fail first-copy-update; fi; [[ "$(<"$p/$HELPER")" == user-edit ]] || fail first-copy-overwrite; [[ "$(<"$p/.agents/skills/example/SKILL.md")" == "$old_skill" ]] || fail first-copy-skill; [[ -f "$p/.ai/managed-files.sha256" && -d "$p/.ai/shared" ]] || fail first-copy-state
}
test_bootstrap_edit_after_backup_pause() {
  local p="$TMP/bootstrap-after-backup" gate="$TMP/bootstrap-after-backup-gate" pid attempts=0; consumer "$p"; mkdir "$gate"; (cd "$p" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_BACKUP="$gate" bash "$ROOT/scripts/bootstrap-consumer.sh") >"$TMP/bootstrap-backup.out" 2>&1 & pid=$!; while [[ ! -f "$gate/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate/ready" ]] || fail bootstrap-backup-ready; mkdir -p "$p/.agents/skills/helper"; printf user-edit > "$p/$HELPER"; : > "$gate/continue"; if wait "$pid"; then fail bootstrap-backup-update; fi; [[ "$(<"$p/$HELPER")" == user-edit ]] || fail bootstrap-backup-overwrite
}
test_concurrent_types_after_backup_pause() {
  local p="$TMP/type-directory-after-backup" q="$TMP/type-symlink-after-backup" gate="$TMP/type-directory-gate" gate2="$TMP/type-symlink-gate" outside="$TMP/type-outside" pid attempts=0 old_head old_manifest old_skill
  consumer "$p"; run_bootstrap "$p" || fail type-directory-bootstrap; old_head="$(git -C "$p/.ai/shared" rev-parse HEAD)"; old_manifest="$(<"$p/.ai/managed-files.sha256")"; old_skill="$(<"$p/.agents/skills/example/SKILL.md")"; printf type-remote > "$SEED/.agents/skills/example/type-marker"; git -C "$SEED" add -A; git -C "$SEED" commit -m type-directory >/dev/null; git -C "$SEED" push >/dev/null; mkdir "$gate"
  (cd "$p" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_BACKUP="$gate" bash "$ROOT/scripts/update-consumer.sh") >"$TMP/type-directory.out" 2>&1 & pid=$!; while [[ ! -f "$gate/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate/ready" ]] || fail type-directory-ready; rm "$p/$HELPER"; mkdir "$p/$HELPER"; : > "$gate/continue"; if wait "$pid"; then fail type-directory-update; fi; [[ -d "$p/$HELPER" && "$(git -C "$p/.ai/shared" rev-parse HEAD)" == "$old_head" && "$(<"$p/.ai/managed-files.sha256")" == "$old_manifest" && "$(<"$p/.agents/skills/example/SKILL.md")" == "$old_skill" ]] || fail type-directory-preserved
  consumer "$q"; run_bootstrap "$q" || fail type-symlink-bootstrap; mkdir "$outside"; printf outside > "$outside/helper"; printf type-remote-2 > "$SEED/.agents/skills/example/type-marker-2"; git -C "$SEED" add -A; git -C "$SEED" commit -m type-symlink >/dev/null; git -C "$SEED" push >/dev/null; mkdir "$gate2"; attempts=0
  (cd "$q" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_BACKUP="$gate2" bash "$ROOT/scripts/update-consumer.sh") >"$TMP/type-symlink.out" 2>&1 & pid=$!; while [[ ! -f "$gate2/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate2/ready" ]] || fail type-symlink-ready; rm "$q/$HELPER"; ln -s "$outside/helper" "$q/$HELPER"; : > "$gate2/continue"; if wait "$pid"; then fail type-symlink-update; fi; [[ -L "$q/$HELPER" && "$(readlink "$q/$HELPER")" == "$outside/helper" && "$(<"$outside/helper")" == outside ]] || fail type-symlink-preserved
}
test_edit_already_copied_after_first_copy() {
  local p="$TMP/copied-change" gate="$TMP/copied-change-gate" pid attempts=0 old_head old_manifest
  consumer "$p"; run_bootstrap "$p" || fail copied-change-bootstrap; old_head="$(git -C "$p/.ai/shared" rev-parse HEAD)"; old_manifest="$(<"$p/.ai/managed-files.sha256")"; printf copied-remote > "$SEED/.agents/skills/example/SKILL.md"; git -C "$SEED" add -A; git -C "$SEED" commit -m copied-change >/dev/null; git -C "$SEED" push >/dev/null; mkdir "$gate"
  (cd "$p" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_FIRST_COPY="$gate" AI_TEST_FAIL_AT=after-first-copy bash "$ROOT/scripts/update-consumer.sh") >"$TMP/copied-change.out" 2>&1 & pid=$!; while [[ ! -f "$gate/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate/ready" ]] || fail copied-change-ready; printf user-copied > "$p/.agents/skills/example/SKILL.md"; : > "$gate/continue"; if wait "$pid"; then fail copied-change-update; fi; [[ "$(<"$p/.agents/skills/example/SKILL.md")" == user-copied && "$(git -C "$p/.ai/shared" rev-parse HEAD)" == "$old_head" && "$(<"$p/.ai/managed-files.sha256")" == "$old_manifest" ]] || fail copied-change-preserved
}
test_project_documents_concurrent_rollback() {
  local p="$TMP/project-documents-update" q="$TMP/project-documents-created" gate="$TMP/project-documents-gate" gate2="$TMP/project-documents-created-gate" pid attempts=0 old_head
  consumer "$p"; run_bootstrap "$p" || fail project-documents-bootstrap; old_head="$(git -C "$p/.ai/shared" rev-parse HEAD)"; mkdir "$gate"
  (cd "$p" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_BACKUP="$gate" AI_TEST_FAIL_AT=after-submodule bash "$ROOT/scripts/update-consumer.sh") >"$TMP/project-documents-update.out" 2>&1 & pid=$!; while [[ ! -f "$gate/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate/ready" ]] || fail project-documents-ready; printf guide-concurrent > "$p/.ai/PROJECT_GUIDE.md"; printf brief-concurrent > "$p/.ai/PROJECT_BRIEF.md"; : > "$gate/continue"; if wait "$pid"; then fail project-documents-update; fi; [[ "$(<"$p/.ai/PROJECT_GUIDE.md")" == guide-concurrent && "$(<"$p/.ai/PROJECT_BRIEF.md")" == brief-concurrent && "$(git -C "$p/.ai/shared" rev-parse HEAD)" == "$old_head" ]] || fail project-documents-preserved
  consumer "$q"; mkdir "$gate2"; attempts=0
  (cd "$q" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_DOCUMENTS="$gate2" AI_TEST_FAIL_AT=after-documents bash "$ROOT/scripts/bootstrap-consumer.sh") >"$TMP/project-documents-created.out" 2>&1 & pid=$!; while [[ ! -f "$gate2/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate2/ready" ]] || fail project-documents-created-ready; printf created-guide-concurrent > "$q/.ai/PROJECT_GUIDE.md"; : > "$gate2/continue"; if wait "$pid"; then fail project-documents-created; fi; [[ "$(<"$q/.ai/PROJECT_GUIDE.md")" == created-guide-concurrent && ! -e "$q/.ai/PROJECT_BRIEF.md" && ! -e "$q/.ai/shared" ]] || fail project-documents-created-preserved
}
test_submodule_preflight_and_concurrent_edits() {
  local file="$TMP/shared-file" link="$TMP/shared-link" directory="$TMP/shared-directory" target="$TMP/shared-target" dirty="$TMP/shared-dirty" race="$TMP/shared-race" created="$TMP/shared-created-race" gate="$TMP/shared-race-gate" gate2="$TMP/shared-created-race-gate" pid attempts=0
  consumer "$file"; mkdir "$file/.ai"; printf keep-file > "$file/.ai/shared"; if run_bootstrap "$file"; then fail shared-file-preflight; fi; [[ "$(<"$file/.ai/shared")" == keep-file && ! -e "$file/.gitmodules" ]] || fail shared-file-mutated
  consumer "$link"; mkdir "$link/.ai"; printf keep-link > "$target"; ln -s "$target" "$link/.ai/shared"; if run_bootstrap "$link"; then fail shared-link-preflight; fi; [[ -L "$link/.ai/shared" && "$(readlink "$link/.ai/shared")" == "$target" && "$(<"$target")" == keep-link ]] || fail shared-link-mutated
  consumer "$directory"; mkdir -p "$directory/.ai/shared"; printf keep-directory > "$directory/.ai/shared/keep"; if run_bootstrap "$directory"; then fail shared-directory-preflight; fi; [[ "$(<"$directory/.ai/shared/keep")" == keep-directory && ! -e "$directory/.gitmodules" ]] || fail shared-directory-mutated
  consumer "$dirty"; run_bootstrap "$dirty" || fail shared-dirty-bootstrap; printf dirty-before > "$dirty/.ai/shared/AGENTS.md"; if run_update "$dirty"; then fail shared-dirty-preflight; fi; [[ "$(<"$dirty/.ai/shared/AGENTS.md")" == dirty-before ]] || fail shared-dirty-mutated
  consumer "$race"; run_bootstrap "$race" || fail shared-race-bootstrap; mkdir "$gate"; (cd "$race" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_SUBMODULE="$gate" AI_TEST_FAIL_AT=after-submodule bash "$ROOT/scripts/update-consumer.sh") >"$TMP/shared-race.out" 2>&1 & pid=$!; while [[ ! -f "$gate/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate/ready" ]] || fail shared-race-ready; printf dirty-concurrent > "$race/.ai/shared/AGENTS.md"; : > "$gate/continue"; if wait "$pid"; then fail shared-race-update; fi; [[ "$(<"$race/.ai/shared/AGENTS.md")" == dirty-concurrent ]] || fail shared-race-overwrite; grep -Fq 'rollback preservou alterações concorrentes no submodule' "$TMP/shared-race.out" || fail shared-race-report
  consumer "$created"; mkdir "$gate2"; attempts=0; (cd "$created" && GIT_ALLOW_PROTOCOL=file AI_BASE_REMOTE="$REMOTE" AI_TEST_PAUSE_AFTER_SUBMODULE="$gate2" AI_TEST_FAIL_AT=after-submodule bash "$ROOT/scripts/bootstrap-consumer.sh") >"$TMP/shared-created-race.out" 2>&1 & pid=$!; while [[ ! -f "$gate2/ready" && "$attempts" -lt 100 ]]; do sleep 0.05; attempts=$((attempts + 1)); done; [[ -f "$gate2/ready" ]] || fail shared-created-race-ready; printf dirty-created > "$created/.ai/shared/AGENTS.md"; : > "$gate2/continue"; if wait "$pid"; then fail shared-created-race-update; fi; [[ "$(<"$created/.ai/shared/AGENTS.md")" == dirty-created && -d "$created/.git/modules/.ai/shared" ]] || fail shared-created-race-overwrite; grep -Fq 'rollback preservou alterações concorrentes no submodule criado' "$TMP/shared-created-race.out" || fail shared-created-race-report
}
# The base keeps the Manager -> Developer -> Manager cycle in AGENTS.md without fixed agents, names or models.
test_role_docs() {
  local doc
  [[ ! -e "$ROOT/.codex" ]] || fail fixed-agents-distributed
  [[ ! -e "$ROOT/.ai/CODEX_ORCHESTRATOR.md" ]] || fail orchestrator-file-distributed
  for doc in AGENTS.md .ai/PROJECT_GUIDE.template.md README.md; do
    grep -Fq 'Manager' "$ROOT/$doc" && grep -Fq 'Developer' "$ROOT/$doc" || fail "roles-$doc"
  done
  grep -Fqx '### Instruções do papel Manager' "$ROOT/AGENTS.md" || fail manager-instructions
  grep -Fqx '### Instruções do papel Developer' "$ROOT/AGENTS.md" || fail developer-instructions
  grep -Fqx '### Ciclo e aprovação' "$ROOT/AGENTS.md" || fail cycle-instructions
  # Only the migration notes may name the retired orchestrator file.
  if grep -nF 'CODEX_ORCHESTRATOR' "$ROOT/.ai/PROJECT_GUIDE.template.md" "$ROOT/.ai/PROJECT_BRIEF.template.md" \
    "$ROOT/.ai/SWIFT_REFERENCE.md" "$ROOT/scripts/consumer-next-steps.txt"; then
    fail orchestrator-references
  fi
  if grep -nE '`(sol|luna)`|(sol|luna)\.toml|TOML compartilhados|gpt-6-(sol|luna)' "$ROOT/.ai/PROJECT_GUIDE.template.md" \
    "$ROOT/.ai/PROJECT_BRIEF.template.md" "$ROOT/.ai/SWIFT_REFERENCE.md"; then
    fail fixed-agent-references
  fi
}
test_unsafe_paths() {
  local p="$TMP/unsafe-manifest"; consumer "$p"; mkdir -p "$p/.ai"; printf 'not a manifest\n' > "$p/.ai/managed-files.sha256"; if run_bootstrap "$p"; then fail invalid-manifest; fi; [[ ! -e "$p/.ai/shared" ]] || fail invalid-manifest-mutation
  local q="$TMP/unsafe-symlink"; consumer "$q"; mkdir -p "$q/.codex"; ln -s "$TMP" "$q/.codex/agents"; if run_bootstrap "$q"; then fail managed-symlink; fi; [[ ! -e "$q/.ai/shared" ]] || fail symlink-mutation
}
test_manifest_traversal_and_backup_idempotence() {
  local p="$TMP/traversal" victim="$TMP/victim"; consumer "$p"; printf keep > "$victim"; mkdir -p "$p/.ai"
  printf '%064d  ../victim\n' 0 > "$p/.ai/managed-files.sha256"
  if run_bootstrap "$p"; then fail traversal-manifest; fi
  [[ "$(<"$victim")" == keep && ! -e "$p/.ai/shared" ]] || fail traversal-mutation
  local q="$TMP/backup-idempotence"; consumer "$q"; printf prior > "$q/AGENTS.md"; run_bootstrap "$q" || fail first-backup; run_bootstrap "$q" || { cat "$TMP/out"; fail second-backup; }; run_update "$q" || { cat "$TMP/out"; fail update-backup; }
}
test_intermediate_symlink() {
  local p="$TMP/intermediate-link" outside="$TMP/outside-skill"; consumer "$p"; mkdir -p "$p/.agents/skills" "$outside"; printf intact > "$outside/SKILL.md"; ln -s "$outside" "$p/.agents/skills/example"
  if run_bootstrap "$p"; then fail intermediate-symlink; fi
  [[ "$(<"$outside/SKILL.md")" == intact && ! -e "$p/.ai/shared" ]] || fail intermediate-symlink-mutation
}
test_new_collision_and_rollback() {
  local p="$TMP/collision" before="$TMP/before"; consumer "$p"; run_bootstrap "$p" || fail collision-bootstrap; printf local > "$p/.agents/skills/example/new-upstream"; printf upstream > "$SEED/.agents/skills/example/new-upstream"; git -C "$SEED" add -A; git -C "$SEED" commit -m collision >/dev/null; git -C "$SEED" push >/dev/null; snapshot "$p" "$before"; if run_update "$p"; then fail new-collision; fi; snapshot "$p" "$TMP/after"; cmp -s "$before" "$TMP/after" || fail collision-mutated
}
test_rollback() { local before="$TMP/rollback-before" point q; for point in after-submodule after-agents-move during-copy; do q="$TMP/rollback-$point"; consumer "$q"; printf original > "$q/AGENTS.md"; snapshot "$q" "$before"; if run_bootstrap_fail "$q" "$point"; then fail "rollback-$point"; fi; snapshot "$q" "$TMP/after-$point"; cmp -s "$before" "$TMP/after-$point" || fail "rollback-state-$point"; if [[ "$point" == after-submodule ]]; then [[ ! -e "$q/.git/modules/.ai/shared" ]] || fail rollback-submodule-metadata; fi; done; }
test_modified_assets_and_special_destinations() {
  local p="$TMP/modified-assets" q="$TMP/directory-destination" r="$TMP/fifo-destination"; consumer "$p"; run_bootstrap "$p" || fail modified-bootstrap; printf local-skill > "$p/.agents/skills/example/SKILL.md"; printf '\007\006' > "$p/.agents/skills/example/assets/logo.bin"; if run_update "$p"; then fail modified-assets; fi; [[ "$(<"$p/.agents/skills/example/SKILL.md")" == local-skill ]] || fail skill-overwrite; cmp -s "$p/.agents/skills/example/assets/logo.bin" <(printf '\007\006') || fail asset-overwrite
  consumer "$q"; mkdir -p "$q/$HELPER"; if run_bootstrap "$q"; then fail directory-destination; fi; [[ ! -e "$q/.ai/shared" ]] || fail directory-mutation
  consumer "$r"; mkdir -p "$r/.agents/skills/helper"; mkfifo "$r/$HELPER"; if run_bootstrap "$r"; then fail fifo-destination; fi; [[ ! -e "$r/.ai/shared" ]] || fail fifo-mutation
}
test_update_rollback() { local p="$TMP/update-rollback" before="$TMP/update-rollback-before"; consumer "$p"; run_bootstrap "$p" || fail update-rollback-bootstrap; printf remote-change > "$SEED/.agents/skills/example/update-marker"; git -C "$SEED" add -A; git -C "$SEED" commit -m update-rollback >/dev/null; git -C "$SEED" push >/dev/null; snapshot "$p" "$before"; if run_update_fail "$p" after-submodule; then fail update-rollback; fi; snapshot "$p" "$TMP/update-rollback-after"; if ! cmp -s "$before" "$TMP/update-rollback-after"; then diff -u "$before" "$TMP/update-rollback-after" >&2 || true; fail update-rollback-state; fi; }
seed; test_lint_tooling_distribution; test_lint_gate_prefers_caller_path; test_retired_workflow; test_retired_agents; test_stale_agent_references; test_retired_orchestrator_link; test_lint_config_adoption; test_adoption_rollback; test_setup_runs_from_main; test_self_update_base; test_claude_skills; test_layout_and_idempotence; test_backup_and_preflight; test_documents_and_conflicts; test_unsafe_paths; test_manifest_traversal_and_backup_idempotence; test_intermediate_symlink; test_rollback; test_modified_assets_and_special_destinations; test_update_rollback; test_new_collision_and_rollback; test_update_safety; test_remote_advance_after_candidate; test_edit_during_candidate_pause; test_edit_after_backup_pause; test_new_collision_after_backup_pause; test_edit_after_first_copy_pause; test_bootstrap_edit_after_backup_pause; test_concurrent_types_after_backup_pause; test_edit_already_copied_after_first_copy; test_project_documents_concurrent_rollback; test_submodule_preflight_and_concurrent_edits; test_old_paths_and_missing_dependency; test_role_docs
echo 'OK: consumer setup tests'
