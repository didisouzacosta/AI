#!/usr/bin/env bash
# Sourced by ai-bootstrap and ai-update. Fast-forwards the local AI checkout before the
# command runs and, when it moved, re-executes the command with the updated scripts.
# Skipped when AI_SKIP_SELF_UPDATE is set, after one re-execution, on a branch other
# than main, with local changes or when the pull fails; the command then keeps the
# local version (setup-consumer.sh still switches to main's setup script by itself).
self_update_base() {
  local root="$1" script="$2" branch before after
  shift 2

  [[ -z "${AI_SKIP_SELF_UPDATE:-}" && -z "${AI_SELF_UPDATED:-}" ]] || return 0
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  branch="$(git -C "$root" branch --show-current)"

  if [[ "$branch" != main ]]; then
    echo "Aviso: a base AI está no branch '${branch:-detached}'; atualização automática ignorada." >&2
    return 0
  fi

  if [[ -n "$(git -C "$root" status --porcelain)" ]]; then
    echo "Aviso: a base AI tem alterações locais; atualização automática ignorada." >&2
    return 0
  fi

  before="$(git -C "$root" rev-parse HEAD)"

  if ! git -C "$root" pull --ff-only --quiet origin main >/dev/null 2>&1; then
    echo "Aviso: não foi possível atualizar a base AI com git pull; usando a versão local." >&2
    return 0
  fi

  after="$(git -C "$root" rev-parse HEAD)"
  [[ "$before" != "$after" ]] || return 0

  echo "Base AI atualizada: ${before:0:7} -> ${after:0:7}" >&2
  AI_SELF_UPDATED=1 exec bash "$script" "$@"
}
