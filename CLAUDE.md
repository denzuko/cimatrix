# CLAUDE.md — cimatrix

## What this repo is

`cimatrix` — validation toolkit for the `org.cispec` Change Item attribution
standard. Thin CLI wrapper around `strings(1)`, `opa`, and `slsa-verifier`.

Canonical spec: https://cispec.org/  
IANA PEN: 42387  
Licence: BSD-2-Clause  

## Architecture

Three subcommands, three source files:

| Subcommand | Source | Delegates to |
|---|---|---|
| `binary` | `src/strings-extract.lisp` | `strings(1)` |
| `gate` | `src/gate-runner.lisp` | `opa eval` |
| `slsa` | `src/slsa-runner.lisp` | `slsa-verifier` |

`src/cli.lisp` wires them together via `adopt`.  
`src/report.lisp` handles terminal output and SARIF 2.1.0 generation.  
`src/cache.lisp` manages the gate bundle cache at `~/.cache/cimatrix/gates/`.

## Build

```sh
qlot exec ros build roswell/cimatrix.ros
```

One binary, no shared Lisp runtime. The binary self-attests with
`org.cispec.*` strings verifiable by `cimatrix binary cimatrix`.

## Test workflow

BDD order: policy gate → BATS test → code → changelog → merge → tag.

```sh
opa check policy/**/*.rego     # gates pass first
bats tests/                    # then integration tests
```

No test-less merges. No test-less shell in the denzuko org.

## Gate bundle

Gates are pulled from `https://cispec.org/gates/` and cached in
`~/.cache/cimatrix/gates/` (24-hour TTL). The canonical copies in
`policy/` are what ships with the release and what the BATS tests use
with `--offline`.

## Versioning

semver 2.0. MAJOR = CLI interface break. MINOR = new subcommand or
gate. PATCH = everything else (freely exceeds 100).

## Conventional commits

Scope: `cli`, `gate`, `slsa`, `binary`, `cache`, `report`, `ci`, `docs`.

## Namespace rule

`org.cispec.*` only. Never introduce `net.matrix.*` strings.

## Attribution rule

The cimatrix binary must itself be verifiable by `cimatrix binary cimatrix`.
Every release build runs this self-check in CI before tagging.
