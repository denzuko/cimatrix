#!/usr/bin/env bats
# SPDX-License-Identifier: BSD-2-Clause
# cimatrix — BATS integration tests

CIMATRIX="${BATS_TEST_DIRNAME}/../cimatrix"
FIXTURES="${BATS_TEST_DIRNAME}/fixtures"

setup_file() {
    mkdir -p "${FIXTURES}"

    # Build a minimal conformant binary using the cimatrix binary itself
    # (cimatrix verify-binary cimatrix is a valid self-test)

    # Minimal conformant labels JSON
    cat > "${FIXTURES}/labels-pass.json" <<'EOF'
{
  "labels": {
    "org.cispec.organization": "daplanet",
    "org.cispec.orgunit": "dps",
    "org.cispec.application": "test-app",
    "org.cispec.version": "1.0.0",
    "org.cispec.oid": "iso.org.dod.internet.42387",
    "org.cispec.specversion": "1.0"
  }
}
EOF

    # Missing required key
    cat > "${FIXTURES}/labels-fail-missing.json" <<'EOF'
{
  "labels": {
    "org.cispec.organization": "daplanet",
    "org.cispec.orgunit": "dps"
  }
}
EOF

    # Invalid slug (uppercase)
    cat > "${FIXTURES}/labels-fail-slug.json" <<'EOF'
{
  "labels": {
    "org.cispec.organization": "DaPlanet",
    "org.cispec.orgunit": "dps",
    "org.cispec.application": "test-app",
    "org.cispec.version": "1.0.0"
  }
}
EOF

    # Invalid semver
    cat > "${FIXTURES}/labels-fail-semver.json" <<'EOF'
{
  "labels": {
    "org.cispec.organization": "daplanet",
    "org.cispec.orgunit": "dps",
    "org.cispec.application": "test-app",
    "org.cispec.version": "not-a-version"
  }
}
EOF
}

# ----------------------------------------------------------------
# verify-binary
# ----------------------------------------------------------------

@test "verify-binary: cimatrix self-attests" {
    run "${CIMATRIX}" verify-binary "${CIMATRIX}"
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "PASS" ]]
}

@test "verify-binary: exits 1 on missing labels" {
    # /bin/sh has no org.cispec strings
    run "${CIMATRIX}" verify-binary /bin/sh
    [ "${status}" -eq 1 ]
    [[ "${output}" =~ "FAIL" ]]
}

@test "verify-binary: exits 2 on missing file" {
    run "${CIMATRIX}" verify-binary /nonexistent/binary
    [ "${status}" -eq 2 ]
}

@test "verify-binary: --sarif writes output file" {
    SARIF_OUT=$(mktemp /tmp/cimatrix-test-XXXXXX.sarif)
    run "${CIMATRIX}" verify-binary "${CIMATRIX}" --sarif "${SARIF_OUT}"
    [ "${status}" -eq 0 ]
    [ -f "${SARIF_OUT}" ]
    grep -q '"version"' "${SARIF_OUT}"
    rm -f "${SARIF_OUT}"
}

# ----------------------------------------------------------------
# verify-gate — attribution gate
# ----------------------------------------------------------------

@test "verify-gate: passes on conformant labels" {
    run "${CIMATRIX}" verify-gate \
        "${BATS_TEST_DIRNAME}/../policy/cispec/attribution.rego" \
        --input "${FIXTURES}/labels-pass.json" \
        --offline
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "PASS" ]]
}

@test "verify-gate: fails on missing required keys" {
    run "${CIMATRIX}" verify-gate \
        "${BATS_TEST_DIRNAME}/../policy/cispec/attribution.rego" \
        --input "${FIXTURES}/labels-fail-missing.json" \
        --offline
    [ "${status}" -eq 1 ]
    [[ "${output}" =~ "FAIL" ]]
    [[ "${output}" =~ "missing required label" ]]
}

@test "verify-gate: fails on invalid slug" {
    run "${CIMATRIX}" verify-gate \
        "${BATS_TEST_DIRNAME}/../policy/cispec/attribution.rego" \
        --input "${FIXTURES}/labels-fail-slug.json" \
        --offline
    [ "${status}" -eq 1 ]
    [[ "${output}" =~ "not a valid slug" ]]
}

@test "verify-gate: fails on invalid semver" {
    run "${CIMATRIX}" verify-gate \
        "${BATS_TEST_DIRNAME}/../policy/cispec/attribution.rego" \
        --input "${FIXTURES}/labels-fail-semver.json" \
        --offline
    [ "${status}" -eq 1 ]
    [[ "${output}" =~ "semver" ]]
}

@test "verify-gate: opa check passes on all policy files" {
    for gate in "${BATS_TEST_DIRNAME}"/../policy/**/*.rego; do
        run opa check "${gate}"
        [ "${status}" -eq 0 ]
    done
}

@test "verify-gate: warns without --input" {
    run "${CIMATRIX}" verify-gate \
        "${BATS_TEST_DIRNAME}/../policy/cispec/attribution.rego" \
        --offline
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "syntax was verified" ]]
}

# ----------------------------------------------------------------
# Subcommand routing
# ----------------------------------------------------------------

@test "unknown subcommand exits 2" {
    run "${CIMATRIX}" frobnicate
    [ "${status}" -eq 2 ]
}

@test "--help exits 0" {
    run "${CIMATRIX}" --help
    [ "${status}" -eq 0 ]
    [[ "${output}" =~ "verify-binary" ]]
    [[ "${output}" =~ "verify-gate" ]]
    [[ "${output}" =~ "verify-slsa" ]]
}

# ----------------------------------------------------------------
# Attribution gate — policy file itself conforms to SPDX rules
# ----------------------------------------------------------------

@test "all policy files have SPDX-License-Identifier header" {
    for gate in "${BATS_TEST_DIRNAME}"/../policy/**/*.rego; do
        run grep -q "SPDX-License-Identifier: BSD-2-Clause" "${gate}"
        [ "${status}" -eq 0 ]
    done
}

@test "all policy files declare cispec_version" {
    for gate in "${BATS_TEST_DIRNAME}"/../policy/**/*.rego; do
        run grep -q 'cispec_version :=' "${gate}"
        [ "${status}" -eq 0 ]
    done
}
