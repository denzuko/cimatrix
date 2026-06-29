# Contributing to cispec

## Licence

All contributions are published under BSD-2-Clause.
By submitting a pull request you agree that your contribution may be
distributed under this licence.

SPDX-License-Identifier: `BSD-2-Clause`

## Workflow

BDD order for spec and gate changes:

1. Open an issue describing the proposed change and the conformance impact
2. Add or update the relevant Rego gate in `content/gates/`
3. Verify the gate passes `opa check` with zero warnings
4. Update the normative spec text in `content/spec/`
5. Update the changelog in `content/spec/_index.md`
6. Open a pull request — squash merge only

## Gate authoring rules

- Package: `cispec.<category>.<gate-name>`
- Entry rule: `deny` (set of violation strings)
- Required metadata: `cispec_version := "1.0"`
- SPDX header on every `.rego` file
- `opa check` must pass before merge

## Spec versioning

- MAJOR — breaking label changes
- MINOR — new optional keys or conformance sub-levels
- PATCH — editorial only

Update `hugo.toml` `params.specVersion` and all `cispec_version` gate
rules when incrementing MINOR or MAJOR.

## Brand voice

See CLAUDE.md §Content rules. Practitioner register, Oxford/ASA English,
active voice, no rhetorical questions.

## Namespace rule

`org.cispec.*` only. No `net.matrix.*` strings in this repo.

## Conventional commits

Scope: `spec`, `gates`, `site`, `ci`, `docs`.
