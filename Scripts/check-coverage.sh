#!/usr/bin/env bash

set -euo pipefail

# Flags extras do SwiftPM (por exemplo, "--build-system swiftbuild"), para que
# os caminhos consultados aqui sejam os mesmos usados em `swift test`.
# shellcheck disable=SC2086
bin_dir="$(swift build ${UAPP_SWIFT_BUILD_FLAGS:-} --show-bin-path)"
test_binary="$bin_dir/UAPPKitTests.xctest/Contents/MacOS/UAPPKitTests"
profile_dir="$bin_dir/codecov"

# O layout de saída muda conforme o build system; localiza os artefatos quando
# não estão no caminho padrão.
if [[ ! -f "$test_binary" ]]; then
    test_binary="$(find .build -type f -path '*UAPPKitTests.xctest/Contents/MacOS/UAPPKitTests' | head -n 1)"
fi

if ! compgen -G "$profile_dir/*.profraw" >/dev/null; then
    profile_dir="$(find .build -type f -name '*.profraw' -exec dirname {} \; | sort -u | head -n 1)"
fi

if [[ -z "$test_binary" || -z "$profile_dir" ]]; then
    echo "Não foi possível localizar o binário de testes ou os dados de cobertura." >&2
    exit 1
fi

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
