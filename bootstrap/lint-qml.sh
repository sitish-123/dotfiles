#!/usr/bin/env bash
# Lightweight QML sanity checks, tuned to bugs this repo has actually hit.
# Runs without a Qt/Quickshell environment (CI-friendly) — it's grep-based, not a
# full qmllint (which can't resolve the Quickshell modules on a generic runner).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QMLDIR="$ROOT/config/quickshell"
fail=0
note() { echo "::error file=$1::$2"; fail=1; }   # GitHub Actions annotation format

while IFS= read -r f; do
    # 1) ScriptModel is provided by the `Quickshell` module. Using it without a bare
    #    `import Quickshell` makes the whole component fail to load (blank page).
    if grep -q 'ScriptModel' "$f" && ! grep -qE '^\s*import[[:space:]]+Quickshell[[:space:]]*$' "$f"; then
        note "$f" "uses ScriptModel but is missing 'import Quickshell'"
    fi
    # 2) GridView/ListView delegate's required modelData should be typed/required —
    #    cheap check: a Repeater/View referencing modelData without declaring it.
    #    (Skipped: too many valid patterns; left as a placeholder for future rules.)
done < <(find "$QMLDIR" -name '*.qml' 2>/dev/null)

if [ "$fail" -eq 0 ]; then echo "QML checks passed ✓"; else echo "QML checks FAILED"; fi
exit $fail
