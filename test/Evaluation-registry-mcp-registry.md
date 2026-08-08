# Docker MCP Registry Readiness Evaluation

> Objective evaluation of `plantuml-mcp-server` for registration in the
> Docker MCP Registry (official catalog, Docker-built submission).
> Scored out of 100 per perspective, plus an overall assessment.
> Japanese version: [Evaluation-registry-mcp-registry.ja-JP.md](Evaluation-registry-mcp-registry.ja-JP.md)
>
> Snapshot date: 2026-08-09 (branch `fix/registry-review-items`, PR #9, commit `613360d`)

## Overall assessment: 90 / 100

Submission to the official catalog is possible now. The MIT licensing
strategy, container engineering, and requirement-traced test suite are
above the bar typically seen in registry entries. The remaining gap is
release execution — PR #9 is awaiting merge, `v0.1.0` has not been
tagged, so the tag-driven release workflow (multi-arch GHCR push,
digest-pinned `catalog.yaml`) is still unproven. Completing the first
release would raise the overall score to roughly 93.

## Scores by perspective

| # | Perspective | Score | Rationale |
|---|---|---:|---|
| 1 | License compliance | 95 | MIT project + `plantuml-mit` artifact; Graphviz (EPL-1.0) isolated as an external subprocess; SPDX headers everywhere; third-party notices and `LICENSE_NOTES.md` engineering checklist. Exactly what the registry's "MIT or Apache 2, not GPL" rule asks for. |
| 2 | Registry requirements fit | 92 | `server.yaml` carries all required fields; Dockerfile at repo root; public GitHub repo; non-affiliation with the PlantUML project stated in the description. Residual risk: the `plantuml` name/icon could still draw a rename request during Docker review. |
| 3 | Container quality & security | 90 | Multi-stage build, Alpine JRE, non-root (uid 10001), pinned font sources, documented `PLANTUML_SECURITY_PROFILE=INTERNET` trade-off (no local file reads; `SANDBOX` opt-out documented), 100k-char and 60s render bounds. Base images are tag-pinned, not digest-pinned (dependabot compensates). |
| 4 | MCP implementation quality | 90 | Token-conscious result design (SVG as embedded resource, PNG as image content), renderer version advertised in tool descriptions, explicit errors for blank/oversized/multi-block/syntax-error input, render timeout on a cancellable worker, renders serialized after a real concurrency deadlock was found and fixed. Serialization caps throughput at one render at a time — acceptable for gateway usage. |
| 5 | CI/CD & release engineering | 92 | CI: Maven build + unit tests + image build + EARS acceptance suite on every push/PR (proven green). Tag-driven release: multi-arch build, GHCR push, digest-pinned catalog generation — well designed but not yet exercised. |
| 6 | Testing | 89 | 8 JUnit tests (rendering, validation, concurrency regression) + 23-item acceptance suite tracing every EARS requirement ID to a TAP check, run in CI against the real image with `--network none`. Results tracked in `test/RESULTS.md` and the `test-results` CI artifact. Not automated: the 60s timeout path (design-reviewed) and multi-arch verification (deferred to the release run). |
| 7 | Documentation | 93 | Bilingual README/requirements, architecture diagram, security section, design and license notes, research notes covering local/WSL/remote test flows and the registration procedure itself, Dify integration samples (`dify-sample/`), and a rerunnable evaluation prompt. |
| 8 | Release readiness | 75 | Repo public, CI green, metadata set, dependabot triaged. Open items: merge PR #9, tag `v0.1.0`, verify the release workflow, set the GHCR package public. |

## Verdict

**Registrable.** For the official catalog (Docker-built), the submission
PR to `docker/mcp-registry` can be opened as soon as PR #9 is merged;
a proven `v0.1.0` release is strongly recommended first because it
demonstrates the multi-arch build and gives reviewers a runnable
reference image.

## Evidence

- Acceptance suite: [`test/acceptance-test.sh`](acceptance-test.sh),
  requirements in [`test/ACCEPTANCE.md`](ACCEPTANCE.md), latest results
  in [`test/RESULTS.md`](RESULTS.md) — 21 passed, 0 failed, 2 skipped
  (by design).
- CI runs: `CI` workflow on `main` and PR #9 (build + tests +
  acceptance); each run uploads the TAP output and `RESULTS.md` as the
  `test-results` artifact.
- Registry rules referenced:
  [docker/mcp-registry CONTRIBUTING.md](https://github.com/docker/mcp-registry/blob/main/CONTRIBUTING.md).
