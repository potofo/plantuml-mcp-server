# Docker MCP Registry Readiness Evaluation

> Objective evaluation of `plantuml-mcp-server` for registration in the
> Docker MCP Registry (official catalog, Docker-built submission).
> Scored out of 100 per perspective, plus an overall assessment.
> Japanese version: [Evaluation-registry-mcp-registry.ja-JP.md](Evaluation-registry-mcp-registry.ja-JP.md)
>
> Snapshot date: 2026-08-09 (main `7778c50`, release `v0.1.0` published)

## Overall assessment: 93 / 100

Every submission prerequisite is now met and proven: the repository is
public with green CI, the `v0.1.0` release ran end-to-end (multi-arch
amd64/arm64 image on GHCR, digest-pinned `catalog.yaml` attached to the
GitHub Release), and the GHCR package is publicly pullable. The release
pipeline earned extra confidence the hard way — its first run failed on
a real defect (the amd64-only `17-jre-alpine` base) that was diagnosed,
fixed, and verified within the same cycle. The remaining deductions are
inherent risks, not open work: the `plantuml` name/icon could draw a
rename request during Docker review, and renders are serialized by
design.

## Scores by perspective

| # | Perspective | Score | Rationale |
|---|---|---:|---|
| 1 | License compliance | 95 | MIT project + `plantuml-mit` artifact; Graphviz (EPL-1.0) isolated as an external subprocess; SPDX headers everywhere; third-party notices and `LICENSE_NOTES.md` engineering checklist. Exactly what the registry's "MIT or Apache 2, not GPL" rule asks for. |
| 2 | Registry requirements fit | 92 | `server.yaml` carries all required fields; Dockerfile at repo root; public GitHub repo; non-affiliation with the PlantUML project stated in the description. Residual risk: the `plantuml` name/icon could still draw a rename request during Docker review. |
| 3 | Container quality & security | 90 | Multi-stage build, Alpine JRE 21 runtime (Java 17 bytecode), non-root (uid 10001), pinned font sources, documented `PLANTUML_SECURITY_PROFILE=INTERNET` trade-off (no local file reads; `SANDBOX` opt-out documented), 100k-char and 60s render bounds. Base images are tag-pinned, not digest-pinned (dependabot compensates). |
| 4 | MCP implementation quality | 90 | Token-conscious result design (SVG as embedded resource, PNG as image content), renderer version advertised in tool descriptions, explicit errors for blank/oversized/multi-block/syntax-error input, render timeout on a cancellable worker, renders serialized after a real concurrency deadlock was found and fixed. Serialization caps throughput at one render at a time — acceptable for gateway usage. |
| 5 | CI/CD & release engineering | 95 | CI: Maven build + unit tests + image build + EARS acceptance suite on every push/PR, results persisted as artifacts. Release: tag-driven multi-arch build, GHCR push, digest-pinned catalog — **proven by the published `v0.1.0`**, including a diagnose-fix-verify cycle when the first attempt failed. |
| 6 | Testing | 90 | 8 JUnit tests (rendering, validation, concurrency regression) + 23-item acceptance suite tracing every EARS requirement ID to a TAP check, run in CI against the real image with `--network none`; results tracked in `test/RESULTS.md` and the `test-results` CI artifact. REQ-CAT-007 (multi-arch, digest-pinned release) is now verified by the actual release run. Not automated: the 60s timeout path (design-reviewed). |
| 7 | Documentation | 93 | Bilingual README/requirements, architecture diagram, security section, design and license notes, research notes covering local/WSL/remote test flows and the registration procedure itself, Dify integration samples (`dify-sample/`), and a rerunnable evaluation prompt. |
| 8 | Release readiness | 95 | `v0.1.0` published: multi-arch image at `ghcr.io/potofo/plantuml-mcp-server` (amd64+arm64 verified in the manifest), digest-pinned `catalog.yaml` attached to the GitHub Release, anonymous pull confirmed (package is public). Only history is thin: a single release so far. |

## Verdict

**Registrable — ready to submit.** All prerequisites for the official
catalog (Docker-built) are met. The next concrete action is the
submission itself: fork `docker/mcp-registry`, generate the entry
(`task create -- --category productivity https://github.com/potofo/plantuml-mcp-server`),
test with `task build` / `task catalog`, and open the PR. Route B
(custom catalog) is available immediately via the release-attached
`catalog.yaml`.

## Evidence

- Release run: `Release` workflow on tag `v0.1.0` — all steps green
  (multi-arch build & push, catalog generation, GitHub Release).
- Image: `ghcr.io/potofo/plantuml-mcp-server:0.1.0` — manifest lists
  amd64 + arm64; anonymous registry pull returns HTTP 200 (public).
- Acceptance suite: [`test/acceptance-test.sh`](acceptance-test.sh),
  requirements in [`test/ACCEPTANCE.md`](ACCEPTANCE.md), latest results
  in [`test/RESULTS.md`](RESULTS.md) — 21 passed, 0 failed, 2 skipped
  (by design).
- CI runs: `CI` workflow green on `main` and all merged PRs; each run
  uploads the TAP output and `RESULTS.md` as the `test-results` artifact.
- Registry rules referenced:
  [docker/mcp-registry CONTRIBUTING.md](https://github.com/docker/mcp-registry/blob/main/CONTRIBUTING.md).
