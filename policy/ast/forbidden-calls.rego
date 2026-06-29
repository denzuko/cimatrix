# SPDX-License-Identifier: BSD-2-Clause
# Package: cispec.ast.forbidden_calls
# Canonical source: https://cispec.org/gates/ast/forbidden-calls.rego
# Spec version: 1.0
#
# Verifies that a C99 project's static analysis output (SARIF format)
# contains no calls to forbidden functions.
#
# Forbidden functions follow the BCHS/C99 DPS coding standard:
#   - gets()      — no length checking
#   - strcpy()    — use strlcpy or strncpy
#   - strcat()    — use strlcat or strncat
#   - sprintf()   — use snprintf
#   - scanf()     — use fgets + sscanf
#   - system()    — shell injection risk
#   - popen()     — shell injection risk
#
# Input: a SARIF 2.1.0 document or a JSON array of call-site records:
#   [{"function": "gets", "file": "main.c", "line": 42}]

package cispec.ast.forbidden_calls

import future.keywords.contains
import future.keywords.if
import future.keywords.in

cispec_version := "1.0"

forbidden := {
    "gets":    "use fgets(); gets() has no length limit",
    "strcpy":  "use strlcpy() or strncpy(); strcpy() risks buffer overflow",
    "strcat":  "use strlcat() or strncat(); strcat() risks buffer overflow",
    "sprintf": "use snprintf(); sprintf() risks buffer overflow",
    "scanf":   "use fgets() + sscanf(); scanf() risks buffer overflow",
    "system":  "do not call system(); shell injection risk",
    "popen":   "do not call popen(); shell injection risk",
}

# ----------------------------------------------------------------
# SARIF input mode (preferred)
# ----------------------------------------------------------------

deny contains msg if {
    # SARIF: input.runs[*].results[*]
    some run in input.runs
    some result in run.results
    fn := result.ruleId
    reason := forbidden[fn]
    loc := result.locations[0].physicalLocation
    msg := sprintf("forbidden call to %s() at %s:%d — %s",
                   [fn,
                    loc.artifactLocation.uri,
                    loc.region.startLine,
                    reason])
}

# ----------------------------------------------------------------
# Simple call-site array input mode
# ----------------------------------------------------------------

deny contains msg if {
    not input.runs   # not SARIF — treat as call-site array
    some call in input
    reason := forbidden[call.function]
    msg := sprintf("forbidden call to %s() at %s:%d — %s",
                   [call.function, call.file, call.line, reason])
}

# ----------------------------------------------------------------
# Advisory: warn on deprecated-but-not-forbidden patterns
# ----------------------------------------------------------------

deprecated := {
    "strncpy": "strncpy() does not guarantee NUL termination; prefer strlcpy()",
    "strncat": "strncat() length argument is remaining space, not total; prefer strlcat()",
}

warn contains msg if {
    not input.runs
    some call in input
    reason := deprecated[call.function]
    msg := sprintf("deprecated function %s() at %s:%d — %s",
                   [call.function, call.file, call.line, reason])
}
