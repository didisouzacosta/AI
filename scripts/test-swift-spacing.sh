#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TMP="$(mktemp -d "${TMPDIR:-/tmp}/swift-spacing.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT INT TERM

lint() {
  swiftlint lint --strict --no-cache --config "$ROOT/.swiftlint.yml" "$1" > "$TMP/output" 2>&1
}

# A compliant fixture passes SwiftLint and SwiftFormat and the fixer leaves it untouched.
pass() {
  local name="$1" file="$TMP/$1.swift"
  cat > "$file"
  cp "$file" "$TMP/$name.original"
  lint "$file" || { cat "$TMP/output" >&2; echo "Expected spacing fixture to pass: $name" >&2; exit 1; }
  swiftformat --lint --config "$ROOT/.swiftformat" "$file" > "$TMP/format-output" 2>&1 || {
    cat "$TMP/format-output" >&2
    echo "Expected formatter fixture to pass: $name" >&2
    exit 1
  }
  perl "$ROOT/scripts/fix-swift-spacing.pl" "$file" > /dev/null
  cmp -s "$file" "$TMP/$name.original" || { echo "Fixer changed a compliant fixture: $name" >&2; exit 1; }
}

# A violating fixture fails the named rule, the fixer produces the expected text,
# the fixed text passes the rule and a second fixer run is a no-op.
fail_and_fix() {
  local name="$1" rule="$2" file="$TMP/$1.swift" expected="$TMP/$1.expected"
  awk '/^--- expected$/ { exit } { print }' > "$file" < "$TMP/fixture"
  awk 'found { print } /^--- expected$/ { found = 1 }' > "$expected" < "$TMP/fixture"
  if lint "$file"; then echo "Expected fixture to fail lint rule $rule: $name" >&2; exit 1; fi
  grep -Fq "($rule)" "$TMP/output" || { cat "$TMP/output" >&2; echo "Failure did not come from $rule: $name" >&2; exit 1; }
  perl "$ROOT/scripts/fix-swift-spacing.pl" "$file" > /dev/null
  diff -u "$expected" "$file" || { echo "Fixer output differs from expected: $name" >&2; exit 1; }
  lint "$file" || { cat "$TMP/output" >&2; echo "Fixed fixture still fails: $name" >&2; exit 1; }
  cp "$file" "$TMP/$name.fixed"
  perl "$ROOT/scripts/fix-swift-spacing.pl" "$file" > /dev/null
  cmp -s "$file" "$TMP/$name.fixed" || { echo "Fixer is not idempotent: $name" >&2; exit 1; }
}

pass compliant-blocks <<'SWIFT'
func process(_ values: [Int]) -> Int {
    let limit = 10
    let offset = 2

    var total = 0
    var count = 0

    guard values.isEmpty == false else {
        return 0
    }

    for value in values where value < limit {
        total += value + offset
        count += 1
    }

    if count > 1 {
        total /= count
    }

    return values.map { value in
        if value > limit {
            return limit
        }

        return value
    }.reduce(total, +)
}
SWIFT

pass switch-and-closures <<'SWIFT'
func describe(_ value: Int?) -> String {
    switch value {
    case let .some(number):
        if number > 0 {
            return "positive"
        }

        return "other"

    case .none:
        return "none"
    }
}
SWIFT

cat > "$TMP/fixture" <<'SWIFT'
func load(_ input: Int?) -> Int {
    let base = 1
    guard let input else {
        return base
    }
    return input + base
}
--- expected
func load(_ input: Int?) -> Int {
    let base = 1

    guard let input else {
        return base
    }

    return input + base
}
SWIFT
fail_and_fix guard-between-statements blank_line_before_block

cat > "$TMP/fixture" <<'SWIFT'
func sum(_ values: [Int]) -> Int {
    var total = 0

    for value in values {
        total += value
    }
    return total
}
--- expected
func sum(_ values: [Int]) -> Int {
    var total = 0

    for value in values {
        total += value
    }

    return total
}
SWIFT
fail_and_fix statement-after-block blank_line_after_block

cat > "$TMP/fixture" <<'SWIFT'
struct Settings {

    // MARK: - Values

    let name: String
    let limit: Int
    var isEnabled = false
    @State private var selection = 0
    private let identifier = 1
}

func build() {
    var buffer: [Int] = []
    let size = 4
    buffer.append(size)
}
--- expected
struct Settings {

    // MARK: - Values

    let name: String
    let limit: Int

    var isEnabled = false
    @State private var selection = 0

    private let identifier = 1
}

func build() {
    var buffer: [Int] = []

    let size = 4
    buffer.append(size)
}
SWIFT
fail_and_fix let-and-var-groups let_var_group_separation

echo 'OK: Swift spacing lint and fixer fixtures'
