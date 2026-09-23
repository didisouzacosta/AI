#!/usr/bin/env bash
set -euo pipefail
REMOTE="${AI_BASE_REMOTE:-https://github.com/didisouzacosta/AI.git}"; SHARED=".ai/shared"
ROOT=""; UPDATE=false; CANDIDATE=""; STAGE=""; OLD=""; BACKUP=""; MUTATED=false; GIT_DIR=""; SUB_HEAD=""; SUB_BRANCH=""; SUB_CREATED=false; LEDGER=""; PROJECT_LEDGER=""
die() { echo "Erro: $*" >&2; exit 1; }
failpoint() { [ "${AI_TEST_FAIL_AT:-}" != "$1" ] || { echo "falha injetada: $1" >&2; return 91; }; }
restore_managed_path() { local rel="$1" source="$BACKUP/$1" dest="$ROOT/$1" parent tmp; safe_destination_parents "$rel" || return 0; parent="$(dirname "$dest")"; if [ -f "$source" ] && [ ! -L "$source" ]; then mkdir -p "$parent"; tmp="$(mktemp "$parent/.ai-rollback.XXXXXX")"; cp -p "$source" "$tmp"; mv -f "$tmp" "$dest"; else rm -f "$dest"; fi; }
record_project_file() { printf 'F\t%s\t%s\n' "$1" "$2" >> "$PROJECT_LEDGER"; }
record_project_link() { printf 'L\t%s\t%s\n' "$1" "$2" >> "$PROJECT_LEDGER"; }
restore_project_node() { local rel="$1" source="$BACKUP/$1" dest="$ROOT/$1" parent tmp; parent="$(dirname "$dest")"; [ ! -L "$parent" ] || return 0; mkdir -p "$parent"; if [ -L "$source" ]; then rm -rf "$dest"; ln -s "$(readlink "$source")" "$dest"; elif [ -f "$source" ] && [ ! -L "$source" ]; then tmp="$(mktemp "$parent/.ai-project-rollback.XXXXXX")"; cp -p "$source" "$tmp"; mv -f "$tmp" "$dest"; else rm -f "$dest"; fi; }
restore_project_ledger() { local kind expected rel current; [ -n "$PROJECT_LEDGER" ] && [ -f "$PROJECT_LEDGER" ] || return 0; while IFS=$'\t' read -r kind expected rel; do if [ "$kind" = F ]; then [ -f "$ROOT/$rel" ] && [ ! -L "$ROOT/$rel" ] || continue; current="$(shasum -a 256 "$ROOT/$rel" | awk '{print $1}')"; [ "$current" = "$expected" ] && restore_project_node "$rel"; elif [ "$kind" = L ]; then [ -L "$ROOT/$rel" ] && [ "$(readlink "$ROOT/$rel")" = "$expected" ] && restore_project_node "$rel"; elif [ "$kind" = M ]; then [ -f "$ROOT/$rel" ] && [ ! -L "$ROOT/$rel" ] || continue; current="$(shasum -a 256 "$ROOT/$rel" | awk '{print $1}')"; if [ "$current" = "$expected" ]; then [ -e "$ROOT/AGENTS.md" ] || [ -L "$ROOT/AGENTS.md" ] || restore_project_node AGENTS.md; rm -f "$ROOT/$rel"; fi; fi; done < "$PROJECT_LEDGER"; rmdir "$ROOT/.ai" 2>/dev/null || true; }
restore_ledger() { local marker hash rel current; [ -n "$LEDGER" ] && [ -f "$LEDGER" ] || return 0; while IFS=$'\t' read -r marker hash rel; do if [ "$marker" = W ]; then [ -f "$ROOT/$rel" ] && [ ! -L "$ROOT/$rel" ] || continue; current="$(shasum -a 256 "$ROOT/$rel" | awk '{print $1}')"; [ "$current" = "$hash" ] && restore_managed_path "$rel"; elif [ "$marker" = R ]; then [ ! -e "$ROOT/$rel" ] && [ ! -L "$ROOT/$rel" ] && restore_managed_path "$rel"; fi; done < "$LEDGER"; rmdir "$ROOT/.codex/agents" "$ROOT/.codex" "$ROOT/.agents/skills" "$ROOT/.agents" 2>/dev/null || true; }
cleanup() { local s="$?" path; if [ "$s" -ne 0 ] && [ "$MUTATED" = true ] && [ -n "$BACKUP" ]; then if [ "$SUB_CREATED" = true ]; then if [ -d "$ROOT/$SHARED" ] && [ -n "$(git -C "$ROOT/$SHARED" status --porcelain)" ]; then echo "Erro: rollback preservou alterações concorrentes no submodule criado." >&2; else rm -rf "$ROOT/$SHARED" "$GIT_DIR/modules/.ai/shared"; fi; elif [ -d "$ROOT/$SHARED" ]; then if [ -n "$(git -C "$ROOT/$SHARED" status --porcelain)" ]; then echo "Erro: rollback preservou alterações concorrentes no submodule." >&2; elif [ -n "$SUB_BRANCH" ]; then git -C "$ROOT/$SHARED" checkout -q -f "$SUB_BRANCH" || true; else [ -z "$SUB_HEAD" ] || git -C "$ROOT/$SHARED" checkout -q -f --detach "$SUB_HEAD" || true; fi; fi; if [ -f "$BACKUP/index" ]; then cp -p "$BACKUP/index" "$GIT_DIR/index"; else rm -f "$GIT_DIR/index"; fi; [ ! -f "$BACKUP/config" ] || cp -p "$BACKUP/config" "$GIT_DIR/config"; [ ! -f "$BACKUP/gitmodules" ] || cp -p "$BACKUP/gitmodules" "$ROOT/.gitmodules"; [ -f "$BACKUP/no-gitmodules" ] && rm -f "$ROOT/.gitmodules"; restore_project_ledger; restore_ledger; fi; [ -z "$CANDIDATE" ] || rm -rf "$CANDIDATE"; [ -z "$STAGE" ] || rm -rf "$STAGE"; [ -z "$OLD" ] || rm -f "$OLD"; [ -z "$BACKUP" ] || rm -rf "$BACKUP"; exit "$s"; }
trap cleanup EXIT
for arg in "$@"; do case "$arg" in --update) UPDATE=true;; *) die "opção inválida: $arg";; esac; done
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "execute dentro de um projeto Git consumidor."
GIT_DIR="$(git rev-parse --absolute-git-dir)"
cd "$ROOT"
safe_rel() { case "$1" in .codex/agents/*|.agents/skills/*) ;; *) return 1;; esac; [[ "$1" != */ && "$1" != *//* && "$1" != */./* && "$1" != */../* && "$1" != *$'\n'* && "$1" != *$'\r'* ]]; }
managed_before() { local wanted="$1" hash path; [ -n "$OLD" ] || return 1; while IFS=$'\t' read -r hash path; do [ "$path" = "$wanted" ] && return 0; done < "$OLD"; return 1; }
managed_hash() { local wanted="$1" hash path; [ -n "$OLD" ] || return 1; while IFS=$'\t' read -r hash path; do [ "$path" = "$wanted" ] && { printf '%s\n' "$hash"; return 0; }; done < "$OLD"; return 1; }
verify_current_managed() { local wanted="$1" hash path; while IFS=$'\t' read -r hash path; do if [ "$path" = "$wanted" ]; then [ -f "$ROOT/$wanted" ] && [ ! -L "$ROOT/$wanted" ] || die "arquivo gerenciado mudou: $wanted"; [ "$(shasum -a 256 "$ROOT/$wanted" | awk '{print $1}')" = "$hash" ] || die "arquivo gerenciado mudou: $wanted"; return 0; fi; done < "$OLD"; return 1; }
safe_destination_parents() {
  local rel="$1" current="$ROOT" component index=0 count
  local -a parts
  IFS=/ read -r -a parts <<< "$rel"; count=${#parts[@]}
  while [ "$index" -lt $((count - 1)) ]; do component="${parts[$index]}"; current="$current/$component"; [ ! -L "$current" ] || return 1; [ ! -e "$current" ] || [ -d "$current" ] || return 1; index=$((index + 1)); done
}
record_write() { printf 'W\t%s\t%s\n' "$2" "$1" >> "$LEDGER"; }
record_remove() { printf 'R\t-\t%s\n' "$1" >> "$LEDGER"; }
publish_file() {
  local rel="$1" source="$2" hash="$3" expected="$4" parent tmp current
  safe_destination_parents "$rel" || die "destino mudou durante a publicação: $rel"
  if [ -e "$ROOT/$rel" ] || [ -L "$ROOT/$rel" ]; then
    [ -f "$ROOT/$rel" ] && [ ! -L "$ROOT/$rel" ] || die "conflito com arquivo local: $rel"
    current="$(shasum -a 256 "$ROOT/$rel" | awk '{print $1}')"
    if [ -n "$expected" ]; then [ "$current" = "$expected" ] || die "arquivo gerenciado mudou: $rel"; else cmp -s "$ROOT/$rel" "$source" || die "conflito com arquivo local: $rel"; fi
  fi
  parent="$ROOT/$(dirname "$rel")"; mkdir -p "$parent"
  tmp="$(mktemp "$parent/.ai-managed.XXXXXX")"
  cp -p "$source" "$tmp"
  safe_destination_parents "$rel" || { rm -f "$tmp"; die "destino mudou durante a publicação: $rel"; }
  if [ -e "$ROOT/$rel" ] || [ -L "$ROOT/$rel" ]; then [ -f "$ROOT/$rel" ] && [ ! -L "$ROOT/$rel" ] || { rm -f "$tmp"; die "conflito com arquivo local: $rel"; }; current="$(shasum -a 256 "$ROOT/$rel" | awk '{print $1}')"; if [ -n "$expected" ]; then [ "$current" = "$expected" ] || { rm -f "$tmp"; die "arquivo gerenciado mudou: $rel"; }; else cmp -s "$ROOT/$rel" "$source" || { rm -f "$tmp"; die "conflito com arquivo local: $rel"; }; fi; fi
  mv -f "$tmp" "$ROOT/$rel"; record_write "$rel" "$hash"
}
validate_manifest() {
  local manifest="$1" out="$2" line hash rel last=""
  [ -f "$manifest" ] && [ ! -L "$manifest" ] || die "manifesto deve ser arquivo regular."
  : > "$out"
  while IFS= read -r line || [ -n "$line" ]; do
    [ "${#line}" -ge 67 ] && [ "${line:64:2}" = "  " ] || die "manifesto inválido."
    hash="${line:0:64}"; rel="${line:66}"
    [[ "$hash" =~ ^[0-9a-f]{64}$ ]] && safe_rel "$rel" || die "manifesto inválido."
    [ -z "$last" ] || [[ "$last" < "$rel" ]] || die "manifesto inválido: duplicado ou fora de ordem."
    printf '%s\t%s\n' "$hash" "$rel" >> "$out"; last="$rel"
  done < "$manifest"
}
[[ ! -e "$ROOT/ai" && ! -L "$ROOT/ai" ]] || die "layout legado detectado em ai."
[[ ! -e "$ROOT/AGENTS.override.md" && ! -L "$ROOT/AGENTS.override.md" ]] || die "AGENTS.override.md impede o carregamento das regras."
if [ -L "$ROOT/AGENTS.md" ]; then [ "$(readlink "$ROOT/AGENTS.md")" = ".ai/shared/AGENTS.md" ] || die "AGENTS.md é um symlink inesperado."; elif [ -e "$ROOT/AGENTS.md" ]; then [ -f "$ROOT/AGENTS.md" ] || die "AGENTS.md tem tipo especial."; [ ! -e "$ROOT/AGENTS_backup.md" ] && [ ! -L "$ROOT/AGENTS_backup.md" ] || die "AGENTS_backup.md já existe."; fi
for p in "$ROOT/.ai" "$ROOT/.codex" "$ROOT/.codex/agents" "$ROOT/.agents" "$ROOT/.agents/skills"; do [ ! -L "$p" ] || die "diretório gerenciado não pode ser symlink."; [ ! -e "$p" ] || [ -d "$p" ] || die "diretório gerenciado inválido."; done
if [ -e "$ROOT/$SHARED" ] || [ -L "$ROOT/$SHARED" ]; then [ -d "$ROOT/$SHARED" ] && [ ! -L "$ROOT/$SHARED" ] || die "$SHARED deve ser um diretório de submodule."; git -C "$ROOT/$SHARED" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$SHARED não é um submodule Git válido."; [ "$(git -C "$ROOT/$SHARED" rev-parse --show-toplevel)" = "$ROOT/$SHARED" ] || die "$SHARED não é um checkout de submodule."; git ls-files --stage -- "$SHARED" | awk '$1 == "160000" { found=1 } END { exit !found }' || die "$SHARED não possui gitlink."; [ -f "$ROOT/.gitmodules" ] && git config -f "$ROOT/.gitmodules" --get-regexp '^submodule\..*\.path$' | awk -v path="$SHARED" '$2 == path { found=1 } END { exit !found }' || die "$SHARED não consta em .gitmodules."; [ -z "$(git -C "$ROOT/$SHARED" status --porcelain)" ] || die "$SHARED possui alterações locais."; fi
OLD=""; if [ -e "$ROOT/.ai/managed-files.sha256" ] || [ -L "$ROOT/.ai/managed-files.sha256" ]; then OLD="$(mktemp "${TMPDIR:-/tmp}/ai-old.XXXXXX")"; validate_manifest "$ROOT/.ai/managed-files.sha256" "$OLD"; while IFS=$'\t' read -r hash rel; do safe_destination_parents "$rel" || die "caminho gerenciado inseguro: $rel"; [ -f "$ROOT/$rel" ] && [ ! -L "$ROOT/$rel" ] || die "arquivo gerenciado inseguro: $rel"; [ "$(shasum -a 256 "$ROOT/$rel" | awk '{print $1}')" = "$hash" ] || die "arquivo gerenciado foi editado: $rel"; done < "$OLD"; fi
CANDIDATE="$(mktemp -d "${TMPDIR:-/tmp}/ai-candidate.XXXXXX")"; git clone --quiet --depth 1 --branch main "$REMOTE" "$CANDIDATE/repo"
CANDIDATE_HEAD="$(git -C "$CANDIDATE/repo" rev-parse HEAD)"
if [ -n "${AI_TEST_PAUSE_AFTER_CANDIDATE:-}" ]; then
  : > "${AI_TEST_PAUSE_AFTER_CANDIDATE}/ready"
  while [ ! -f "${AI_TEST_PAUSE_AFTER_CANDIDATE}/continue" ]; do sleep 0.05; done
fi
for f in AGENTS.md .ai/CODEX_ORCHESTRATOR.md .ai/SWIFT_REFERENCE.md .ai/PROJECT_BRIEF.template.md .ai/PROJECT_GUIDE.template.md; do [ -f "$CANDIDATE/repo/$f" ] && [ ! -L "$CANDIDATE/repo/$f" ] || die "dependência sem $f"; done
for f in .codex/agents/luna.toml .codex/agents/sol.toml; do [ -f "$CANDIDATE/repo/$f" ] && [ ! -L "$CANDIDATE/repo/$f" ] || die "dependência sem $f"; done
while IFS= read -r p; do [ -d "$p" ] && [ ! -L "$p" ] && continue; [ -f "$p" ] && [ ! -L "$p" ] && continue; die "fonte gerenciada insegura."; done < <(find "$CANDIDATE/repo/.codex/agents" "$CANDIDATE/repo/.agents/skills" -print)
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/ai-stage.XXXXXX")"; (cd "$CANDIDATE/repo"; LC_ALL=C find .codex/agents .agents/skills -type f -print | LC_ALL=C sort) > "$STAGE/paths"
while IFS= read -r rel; do safe_rel "$rel" || die "fonte insegura."; safe_destination_parents "$rel" || die "destino inseguro: $rel"; mkdir -p "$STAGE/files/$(dirname "$rel")"; cp -p "$CANDIDATE/repo/$rel" "$STAGE/files/$rel"; printf '%s  %s\n' "$(shasum -a 256 "$CANDIDATE/repo/$rel" | awk '{print $1}')" "$rel" >> "$STAGE/manifest"; if [ -e "$ROOT/$rel" ] || [ -L "$ROOT/$rel" ]; then [ -f "$ROOT/$rel" ] && [ ! -L "$ROOT/$rel" ] || die "destino inseguro."; managed_before "$rel" || cmp -s "$ROOT/$rel" "$STAGE/files/$rel" || die "conflito com arquivo local: $rel"; fi; done < "$STAGE/paths"
for f in PROJECT_BRIEF.md PROJECT_GUIDE.md; do [ ! -L "$ROOT/.ai/$f" ] || die "$f symlink inseguro."; [ ! -e "$ROOT/.ai/$f" ] || [ -f "$ROOT/.ai/$f" ] || die "$f especial."; done
for f in CODEX_ORCHESTRATOR.md SWIFT_REFERENCE.md; do if [ -e "$ROOT/.ai/$f" ] || [ -L "$ROOT/.ai/$f" ]; then [ -L "$ROOT/.ai/$f" ] && [ "$(readlink "$ROOT/.ai/$f")" = "shared/.ai/$f" ] || die "$f conflita."; fi; done
BACKUP="$(mktemp -d "${TMPDIR:-/tmp}/ai-rollback.XXXXXX")"; [ ! -d "$ROOT/$SHARED" ] || { SUB_HEAD="$(git -C "$ROOT/$SHARED" rev-parse HEAD)"; SUB_BRANCH="$(git -C "$ROOT/$SHARED" branch --show-current)"; }; for path in .ai .codex .agents AGENTS.md AGENTS_backup.md; do [ ! -e "$ROOT/$path" ] && [ ! -L "$ROOT/$path" ] || cp -pR "$ROOT/$path" "$BACKUP/$path"; done; [ ! -f "$GIT_DIR/index" ] || cp -p "$GIT_DIR/index" "$BACKUP/index"; cp -p "$GIT_DIR/config" "$BACKUP/config"; if [ -f "$ROOT/.gitmodules" ]; then cp -p "$ROOT/.gitmodules" "$BACKUP/gitmodules"; else : > "$BACKUP/no-gitmodules"; fi; LEDGER="$BACKUP/ledger"; PROJECT_LEDGER="$BACKUP/project-ledger"; : > "$LEDGER"; : > "$PROJECT_LEDGER"; MUTATED=true
if [ -n "${AI_TEST_PAUSE_AFTER_BACKUP:-}" ]; then : > "${AI_TEST_PAUSE_AFTER_BACKUP}/ready"; while [ ! -f "${AI_TEST_PAUSE_AFTER_BACKUP}/continue" ]; do sleep 0.05; done; fi
if [ ! -d "$ROOT/$SHARED" ]; then mkdir -p "$ROOT/.ai"; git submodule add -b main "$REMOTE" "$SHARED"; SUB_CREATED=true; elif [ "$UPDATE" = true ]; then git submodule update --remote -- "$SHARED"; else git submodule update --init -- "$SHARED"; fi
git -C "$ROOT/$SHARED" fetch --quiet "$CANDIDATE/repo" "$CANDIDATE_HEAD"
git -C "$ROOT/$SHARED" checkout -q --detach "$CANDIDATE_HEAD"; git add "$SHARED"
if [ -n "${AI_TEST_PAUSE_AFTER_SUBMODULE:-}" ]; then : > "$AI_TEST_PAUSE_AFTER_SUBMODULE/ready"; while [ ! -f "$AI_TEST_PAUSE_AFTER_SUBMODULE/continue" ]; do sleep 0.05; done; fi
failpoint after-submodule
if [ -e "$ROOT/AGENTS.md" ] && [ ! -L "$ROOT/AGENTS.md" ]; then mv "$ROOT/AGENTS.md" "$ROOT/AGENTS_backup.md"; printf 'M\t%s\tAGENTS_backup.md\n' "$(shasum -a 256 "$ROOT/AGENTS_backup.md" | awk '{print $1}')" >> "$PROJECT_LEDGER"; fi
failpoint after-agents-move
[ -e "$ROOT/AGENTS.md" ] || [ -L "$ROOT/AGENTS.md" ] || { ln -s ".ai/shared/AGENTS.md" "$ROOT/AGENTS.md"; record_project_link ".ai/shared/AGENTS.md" AGENTS.md; }
for f in PROJECT_BRIEF PROJECT_GUIDE; do if [ ! -e "$ROOT/.ai/$f.md" ]; then cp "$ROOT/$SHARED/.ai/$f.template.md" "$ROOT/.ai/$f.md"; record_project_file "$(shasum -a 256 "$ROOT/.ai/$f.md" | awk '{print $1}')" ".ai/$f.md"; fi; done
for f in CODEX_ORCHESTRATOR.md SWIFT_REFERENCE.md; do if [ ! -e "$ROOT/.ai/$f" ] && [ ! -L "$ROOT/.ai/$f" ]; then ln -s "shared/.ai/$f" "$ROOT/.ai/$f"; record_project_link "shared/.ai/$f" ".ai/$f"; fi; done
if [ -n "${AI_TEST_PAUSE_AFTER_DOCUMENTS:-}" ]; then : > "$AI_TEST_PAUSE_AFTER_DOCUMENTS/ready"; while [ ! -f "$AI_TEST_PAUSE_AFTER_DOCUMENTS/continue" ]; do sleep 0.05; done; fi
failpoint after-documents
first_copy=true
while IFS= read -r rel; do expected="$(managed_hash "$rel" || true)"; if [ -n "$expected" ]; then verify_current_managed "$rel"; elif [ -e "$ROOT/$rel" ] || [ -L "$ROOT/$rel" ]; then [ -f "$ROOT/$rel" ] && [ ! -L "$ROOT/$rel" ] && cmp -s "$ROOT/$rel" "$STAGE/files/$rel" || die "conflito com arquivo local: $rel"; fi; publish_file "$rel" "$STAGE/files/$rel" "$(shasum -a 256 "$STAGE/files/$rel" | awk '{print $1}')" "$expected"; if [ "$first_copy" = true ]; then first_copy=false; if [ -n "${AI_TEST_PAUSE_AFTER_FIRST_COPY:-}" ]; then : > "$AI_TEST_PAUSE_AFTER_FIRST_COPY/ready"; while [ ! -f "$AI_TEST_PAUSE_AFTER_FIRST_COPY/continue" ]; do sleep 0.05; done; fi; failpoint after-first-copy; fi; failpoint during-copy; done < "$STAGE/paths"
if [ -n "$OLD" ]; then while IFS=$'\t' read -r hash rel; do if ! grep -Fqx "$rel" "$STAGE/paths"; then safe_destination_parents "$rel" || die "destino mudou durante a publicação: $rel"; verify_current_managed "$rel"; rm -f "$ROOT/$rel"; record_remove "$rel"; fi; done < "$OLD"; fi
tmp_manifest="$(mktemp "$ROOT/.ai/.ai-managed-manifest.XXXXXX")"; cp -p "$STAGE/manifest" "$tmp_manifest"; mv -f "$tmp_manifest" "$ROOT/.ai/managed-files.sha256"; record_project_file "$(shasum -a 256 "$ROOT/.ai/managed-files.sha256" | awk '{print $1}')" .ai/managed-files.sha256
echo "Projeto configurado: $ROOT"
