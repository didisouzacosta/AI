#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TMP="$(mktemp -d "${TMPDIR:-/tmp}/swift-type-mark.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM

pass() {
  local name="$1"
  cat > "$TMP/$name.swift"
  swiftlint lint --strict --no-cache --config "$ROOT/.swiftlint.yml" "$TMP/$name.swift" > "$TMP/output" 2>&1 || {
    cat "$TMP/output" >&2
    echo "Expected MARK fixture to pass: $name" >&2
    exit 1
  }
  swiftformat --lint --config "$ROOT/.swiftformat" "$TMP/$name.swift" > "$TMP/format-output" 2>&1 || {
    cat "$TMP/format-output" >&2
    echo "Expected formatter fixture to pass: $name" >&2
    exit 1
  }
}

fail() {
  local name="$1" rule="${2:-required_type_mark}"
  cat > "$TMP/$name.swift"
  if swiftlint lint --strict --no-cache --config "$ROOT/.swiftlint.yml" "$TMP/$name.swift" > "$TMP/output" 2>&1; then
    echo "Expected fixture to fail lint rule $rule: $name" >&2
    exit 1
  fi
  grep -Fq "($rule)" "$TMP/output" || {
    cat "$TMP/output" >&2
    echo "Failure did not come from $rule: $name" >&2
    exit 1
  }
}

pass attributes-and-modifiers <<'SWIFT'
import Observation

/// A documentation comment before the declaration must not count as a type section.
@MainActor
@Observable
public final class PresentationModel {

    // MARK: - Presentation state

    let isReady = true
    let title = "Title"
    let subtitle = "Subtitle"

    var count = 0
    var selection = 0
    var isEditing = false

    func reset() {
        count = 0
    }
}
SWIFT

pass nested-types <<'SWIFT'
struct Outer {

    // MARK: - Outer layout

    let first = 1
    let second = 2

    func total() -> Int {
        first + second
    }

    enum Nested {

        // MARK: - Nested cases

        case first
        case second
        case third
        case fourth
        case fifth
        case sixth
        case seventh
        case eighth
    }
}
SWIFT

pass small-types-are-exempt <<'SWIFT'
enum Direction {
    case upward
    case downward
}

struct Point {
    let horizontal: Int
    let vertical: Int
}

extension Point {
    var sum: Int {
        horizontal + vertical
    }
}
SWIFT

pass class-members-are-not-types <<'SWIFT'
class Base {

    // MARK: - Factory

    class var name: String {
        "Base"
    }

    class func make() -> Base {
        Base()
    }

    func describe() -> String {
        Self.name
    }
}
SWIFT

fail missing-mark-in-class <<'SWIFT'
final class MissingMark {
    let first = 1
    let second = 2
    let third = 3
    let fourth = 4
    let fifth = 5
    let sixth = 6
    let seventh = 7
    let eighth = 8
    let ninth = 9
    let tenth = 10
}
SWIFT

fail missing-mark-in-extension <<'SWIFT'
extension String {
    func first() -> String {
        self
    }

    func second() -> String {
        self
    }

    func third() -> String {
        self
    }
}
SWIFT

fail missing-mark-in-actor <<'SWIFT'
actor Counter {
    private var value = 0

    func increment() {
        value += 1
    }

    func decrement() {
        value -= 1
    }

    func current() -> Int {
        value
    }
}
SWIFT

fail mark-without-leading-blank-line <<'SWIFT'
struct Glued {
    // MARK: - Values

    let first = 1
    let second = 2
    let third = 3
    let fourth = 4
    let fifth = 5
    let sixth = 6
    let seventh = 7
    let eighth = 8
    let ninth = 9
}
SWIFT

fail declaration-comment-is-not-type-section <<'SWIFT'
// MARK: - This comment is outside the type.
enum Outside {
    case first
    case second
    case third
    case fourth
    case fifth
    case sixth
    case seventh
    case eighth
    case ninth
    case tenth
}
SWIFT

fail nested-type-without-mark <<'SWIFT'
struct Outer {

    // MARK: - Outer layout

    let value = 1

    struct Nested {
        let first = 1
        let second = 2
        let third = 3
        let fourth = 4
        let fifth = 5
        let sixth = 6
        let seventh = 7
        let eighth = 8
        let ninth = 9
        let tenth = 10
    }
}
SWIFT

fail force-unwrap force_unwrapping <<'SWIFT'
func value(_ input: Int?) -> Int {
    input!
}
SWIFT

mkdir "$TMP/drafts"
cat > "$TMP/drafts/Recorder+FrameProcessing.swift" <<'SWIFT'
extension Recorder {
    func first() -> Int {
        1
    }

    func second() -> Int {
        2
    }

    func third() -> Int {
        3
    }
}
SWIFT
cat > "$TMP/drafts/Settings.swift" <<'SWIFT'
struct Settings {
    let first = 1
    let second = 2
    let third = 3
    let fourth = 4
    let fifth = 5
    let sixth = 6
    let seventh = 7
    let eighth = 8
    let ninth = 9
    let tenth = 10
}
SWIFT
python3 "$ROOT/scripts/add-type-marks.py" "$TMP/drafts/Recorder+FrameProcessing.swift" "$TMP/drafts/Settings.swift" > "$TMP/drafts.out"
grep -Fq '// MARK: - Frame Processing' "$TMP/drafts/Recorder+FrameProcessing.swift" || { cat "$TMP/drafts.out" >&2; echo "Expected feature MARK draft" >&2; exit 1; }
grep -Fq '// MARK: - Public Properties' "$TMP/drafts/Settings.swift" || { cat "$TMP/drafts.out" >&2; echo "Expected category MARK draft" >&2; exit 1; }
swiftlint lint --strict --no-cache --config "$ROOT/.swiftlint.yml" "$TMP/drafts" > "$TMP/output" 2>&1 || {
  cat "$TMP/output" >&2
  echo "Drafted MARKs still fail lint" >&2
  exit 1
}

echo 'OK: required type MARK lint fixtures'
