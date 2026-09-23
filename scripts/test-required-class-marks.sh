#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TMP="$(mktemp -d "${TMPDIR:-/tmp}/swift-class-mark.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM

pass() {
  local name="$1"
  cat > "$TMP/$name.swift"
  swiftlint lint --strict --no-cache --config "$ROOT/.swiftlint.yml" "$TMP/$name.swift" > "$TMP/output" 2>&1 || {
    cat "$TMP/output" >&2
    echo "Expected MARK fixture to pass: $name" >&2
    exit 1
  }
  xcrun swift-format lint --strict --configuration "$ROOT/.swift-format" "$TMP/$name.swift" > "$TMP/format-output" 2>&1 || {
    cat "$TMP/format-output" >&2
    echo "Expected formatter fixture to pass: $name" >&2
    exit 1
  }
}

fail() {
  local name="$1" rule="${2:-required_class_mark}"
  cat > "$TMP/$name.swift"
  if swiftlint lint --strict --no-cache --config "$ROOT/.swiftlint.yml" "$TMP/$name.swift" > "$TMP/output" 2>&1; then
    echo "Expected fixture to fail lint rule $rule: $name" >&2
    exit 1
  fi
  grep -Fq "$rule" "$TMP/output" || {
    cat "$TMP/output" >&2
    echo "Failure did not come from $rule: $name" >&2
    exit 1
  }
}

pass attributes-and-modifiers <<'SWIFT'
// A documentation comment before the declaration must not count as a class section.
@MainActor
@Observable
public final class ShortClass {
  // MARK: - Presentation state
  let isReady = true
}
SWIFT

pass nested-classes <<'SWIFT'
class Outer {
  // MARK: - Outer lifecycle
  init() {}

  private final class Nested {
    // MARK: - Nested value
    let value = 1
  }
}
SWIFT

fail short-class <<'SWIFT'
final class MissingMark {
  let value = 1
}
SWIFT

fail inline-empty-class <<'SWIFT'
final class MissingMark {}
SWIFT

fail inline-member-class <<'SWIFT'
final class MissingMark { let value = 1 }
SWIFT

fail declaration-comment-is-not-class-section <<'SWIFT'
// MARK: - This comment is outside the class.
class MissingMark {
  let value = 1
}
SWIFT

fail force-unwrap force_unwrapping <<'SWIFT'
func value(_ input: Int?) -> Int {
  input!
}
SWIFT

fail nested-class <<'SWIFT'
class Outer {
  // MARK: - Outer lifecycle
  private final class MissingNestedMark {}
}
SWIFT

echo 'OK: required class MARK lint fixtures'
