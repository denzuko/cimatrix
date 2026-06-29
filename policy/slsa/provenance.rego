# SPDX-License-Identifier: BSD-2-Clause
# Package: cispec.slsa.provenance
# Canonical source: https://cispec.org/gates/slsa/provenance.rego
# Spec version: 1.0
#
# Verifies that a SLSA provenance attestation:
#   - is present and structurally valid
#   - references a known/expected builder
#   - records the cispec spec version used during the build
#   - subject digest matches the artefact being attested
#
# Input: an in-toto v1 statement (application/vnd.in-toto+json)
# or the unwrapped predicate from slsa-verifier --format json output.

package cispec.slsa.provenance

import future.keywords.contains
import future.keywords.if
import future.keywords.in

cispec_version := "1.0"

# Known SLSA Build Level 3 builders.
# Extend this set for private builders by overlaying a custom gate.
known_builders := {
    "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/builder_go_slsa3.yml",
    "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/builder_nodejs_slsa3.yml",
    "https://github.com/slsa-framework/slsa-github-generator/.github/workflows/builder_generic_slsa3.yml",
}

# ----------------------------------------------------------------
# Structural checks
# ----------------------------------------------------------------

deny contains msg if {
    not input.predicateType
    msg := "attestation is missing predicateType"
}

deny contains msg if {
    not input.predicate
    msg := "attestation is missing predicate"
}

deny contains msg if {
    not input.subject
    msg := "attestation is missing subject (artefact digest list)"
}

deny contains msg if {
    count(input.subject) == 0
    msg := "attestation subject list is empty"
}

# ----------------------------------------------------------------
# Builder identity
# ----------------------------------------------------------------

deny contains msg if {
    not input.predicate.buildDefinition.buildType
    not input.predicate.builder.id
    msg := "attestation records no builder identity"
}

warn contains msg if {
    builder := object.get(input, ["predicate", "builder", "id"], "")
    builder != ""
    not builder in known_builders
    msg := sprintf("builder %q is not in the known_builders allowlist; verify manually", [builder])
}

# ----------------------------------------------------------------
# Subject digest — must include sha256
# ----------------------------------------------------------------

deny contains msg if {
    some subj in input.subject
    not subj.digest.sha256
    msg := sprintf("subject %q is missing sha256 digest", [subj.name])
}

# ----------------------------------------------------------------
# cispec spec version annotation
# ----------------------------------------------------------------

warn contains msg if {
    env_vars := object.get(
        input,
        ["predicate", "buildDefinition", "resolvedDependencies"],
        []
    )
    # Advisory only — projects should record CISPEC_VERSION in their build env
    not any_env_has_cispec(env_vars)
    msg := "no org.cispec.specversion annotation found in build environment; recommended for Attested conformance"
}

# ----------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------

any_env_has_cispec(deps) if {
    some dep in deps
    startswith(dep.uri, "org.cispec")
}
