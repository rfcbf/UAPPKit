#!/usr/bin/env bash

set -euo pipefail

bin_dir="$(swift build --show-bin-path)"
test_binary="$bin_dir/UAPPKitTests.xctest/Contents/MacOS/UAPPKitTests"
profile_dir="$bin_dir/codecov"
profile="$profile_dir/default.profdata"

xcrun llvm-profdata merge -sparse "$profile_dir"/*.profraw -o "$profile"

report="$(xcrun llvm-cov report \
    "$test_binary" \
    -instr-profile "$profile" \
    -ignore-filename-regex='(GeneratedAssetSymbols|GeneratedStringSymbols|resource_bundle_accessor|test_entry_point|/Tests/)')"

printf '%s\n' "$report"

line_coverage="$(printf '%s\n' "$report" | awk '$1 == "TOTAL" { gsub("%", "", $10); print $10 }')"

if [[ -z "$line_coverage" ]]; then
    echo "Não foi possível determinar a cobertura de linhas." >&2
    exit 1
fi

awk -v coverage="$line_coverage" 'BEGIN {
    if (coverage < 80) {
        printf "Cobertura de linhas abaixo do mínimo: %.2f%% (mínimo: 80%%)\n", coverage > "/dev/stderr"
        exit 1
    }
    printf "Cobertura de linhas aprovada: %.2f%% (mínimo: 80%%)\n", coverage
}'
