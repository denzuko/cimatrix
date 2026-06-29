# cimatrix

[![SPDX-License-Identifier: BSD-2-Clause](https://img.shields.io/badge/SPDX-BSD--2--Clause-blue.svg)](https://spdx.org/licenses/BSD-2-Clause.html)
[![org.cispec: v1.0](https://img.shields.io/badge/org.cispec-v1.0-green.svg)](https://cispec.org/spec/)
[![IANA PEN: 42387](https://img.shields.io/badge/IANA%20PEN-42387-lightgrey.svg)](https://cispec.org/asn/)

`cimatrix` is the validation toolkit for the [`org.cispec`](https://cispec.org)
Change Item attribution standard.

```sh
# Verify a binary carries org.cispec.* attribution strings
cimatrix verify-binary ./my-binary

# Verify a Rego gate against the cispec standard
cimatrix verify-gate ./policy/slsa.rego --input attestation.json

# Verify a SLSA provenance attestation
cimatrix verify-slsa ./my-binary ./my-binary.intoto.jsonl \
  --source-uri github.com/denzuko/my-tool
```

## Relationship to denzuko/cispec

`cimatrix` is the **toolkit**. The **spec** lives at
[denzuko/cispec](https://github.com/denzuko/cispec) and is published at
[cispec.org](https://cispec.org). Gates are pulled from
`https://cispec.org/gates/` and cached in `~/.cache/cimatrix/gates/`.

## Installation

```sh
curl -sLf -o ~/.local/bin/cimatrix \
  https://github.com/denzuko/cimatrix/releases/latest/download/cimatrix-linux-amd64
chmod +x ~/.local/bin/cimatrix

# Verify SLSA attestation
slsa-verifier verify-artifact ~/.local/bin/cimatrix \
  --provenance-path cimatrix-linux-amd64.intoto.jsonl \
  --source-uri github.com/denzuko/cimatrix
```

## GitHub Action

```yaml
- uses: denzuko/cimatrix@v1
  with:
    binary: ./my-binary
    gate-dir: ./policy/
    slsa-provenance: ./my-binary.intoto.jsonl
    source-uri: github.com/denzuko/my-tool
```

## Build from source

```sh
ros install qlot
qlot install
qlot exec ros build roswell/cimatrix.ros
```

Requires: SBCL, Roswell, qlot.

## Tests

```sh
bats tests/
```

All shell/BATS projects in the denzuko org require BATS tests.
No test-less merges.

## Licence

BSD-2-Clause. SPDX-License-Identifier: `BSD-2-Clause`.  
D&B DUNS: 039-271-257 · IANA PEN: 42387  
Canonical spec: https://cispec.org/
