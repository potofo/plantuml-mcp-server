# Acceptance Requirements (EARS format)

Acceptance requirements for the PlantUML MCP Server, derived from the
[Docker MCP Catalog acceptance criteria](https://github.com/docker/mcp-registry/blob/main/CONTRIBUTING.md)
and this project's own functional requirements.

Each requirement is written in EARS (Easy Approach to Requirements
Syntax) and carries a stable ID. Automated requirements are verified by
[`acceptance-test.sh`](acceptance-test.sh), which CI runs against the
image built in the same workflow (see
[`.github/workflows/ci.yml`](../.github/workflows/ci.yml)). The script
reports one TAP-style `ok` / `not ok` line per requirement ID, so a CI
failure names the exact requirement that was violated.

Japanese version: [ACCEPTANCE.ja-JP.md](ACCEPTANCE.ja-JP.md)

## EARS patterns used

| Pattern | Template |
| --- | --- |
| Ubiquitous | The \<system\> shall \<response\>. |
| Event-driven | When \<trigger\>, the \<system\> shall \<response\>. |
| State-driven | While \<state\>, the \<system\> shall \<response\>. |
| Unwanted behavior | If \<condition\>, then the \<system\> shall \<response\>. |

## 1. Docker MCP Catalog compliance (REQ-CAT)

| ID | Pattern | Requirement | Verification |
| --- | --- | --- | --- |
| REQ-CAT-001 | Ubiquitous | The project shall be licensed under the MIT license, with the full license text present in `LICENSE.txt` at the repository root. | Automated |
| REQ-CAT-002 | Ubiquitous | The repository shall provide a `server.yaml` in docker/mcp-registry format containing `name`, `type`, `meta.category`, `about.title`, `about.icon`, `about.description` and `source.project`. | Automated |
| REQ-CAT-003 | Ubiquitous | The repository shall provide a `Dockerfile` at its root from which the container image builds successfully. | Automated (CI `docker build` step) |
| REQ-CAT-004 | Ubiquitous | The container shall run as a non-root user. | Automated |
| REQ-CAT-005 | Event-driven | When an MCP client sends `initialize` over stdio, the server shall respond with a success result identifying itself as `plantuml-mcp`. | Automated |
| REQ-CAT-006 | Event-driven | When an MCP client requests `tools/list` without any prior configuration, secrets, or environment variables, the server shall list exactly the tools `render_svg` and `render_png`, each with a JSON Schema input definition. | Automated |
| REQ-CAT-007 | Ubiquitous | Release images shall be published for `linux/amd64` and `linux/arm64` and shall be referenced by digest in the release-generated `catalog.yaml`. | Inspection of `release.yml` + release run |
| REQ-CAT-008 | State-driven | While rendering diagrams that do not use URL `!include` directives, the server shall not require outbound network access. | Automated (test container runs with `--network none`) |

## 2. Functional requirements (REQ-FUN)

| ID | Pattern | Requirement | Verification |
| --- | --- | --- | --- |
| REQ-FUN-001 | Event-driven | When `render_svg` is called with valid PlantUML source, the server shall return an embedded resource with MIME type `image/svg+xml` containing the rendered SVG, plus a short status text, and shall not inline the SVG text into the text content. | Automated |
| REQ-FUN-002 | Event-driven | When `render_png` is called with valid PlantUML source, the server shall return an image content item with MIME type `image/png` containing a valid PNG. | Automated |
| REQ-FUN-003 | Event-driven | When the source requires Graphviz layout (e.g. a class diagram), the server shall render it using the Graphviz bundled in the image. | Automated |
| REQ-FUN-004 | Event-driven | When the source contains CJK (e.g. Japanese) labels, the server shall render them using the bundled Noto CJK fonts, such that the labels appear in the output. | Automated |
| REQ-FUN-005 | Ubiquitous | The description of every tool shall advertise the exact PlantUML renderer version, so the calling LLM writes syntax valid for that release. | Automated |

## 3. Error handling — unwanted behavior (REQ-ERR)

| ID | Pattern | Requirement | Verification |
| --- | --- | --- | --- |
| REQ-ERR-001 | Unwanted | If the `source` argument is missing, empty, or blank, then the server shall return a tool error (`isError: true`) stating that a non-empty string is required. | Automated |
| REQ-ERR-002 | Unwanted | If the source exceeds 100,000 characters, then the server shall return a tool error stating the limit. | Automated |
| REQ-ERR-003 | Unwanted | If the source contains a PlantUML syntax error, then the server shall return a tool error containing the message "syntax error" and the offending line number. | Automated |
| REQ-ERR-004 | Unwanted | If the source contains more than one `@startuml` block, then the server shall return a tool error instructing the caller to send exactly one block per call. | Automated |
| REQ-ERR-005 | Unwanted | If a feature absent from the MIT build (e.g. ditaa) is requested, then the server shall respond without terminating — either with a tool error or with a rendered notice that the feature is unavailable. | Automated |
| REQ-ERR-006 | Unwanted | If a render does not complete within 60 seconds, then the server shall abort it and return a timeout error. | Design review + unit-level inspection (`PlantUmlRenderer`) |

## 4. Operational requirements (REQ-OPS)

| ID | Pattern | Requirement | Verification |
| --- | --- | --- | --- |
| REQ-OPS-001 | State-driven | While running, the server shall write only JSON-RPC protocol messages to stdout; diagnostic logs shall go to stderr. | Automated (every stdout line must parse as JSON) |
| REQ-OPS-002 | Event-driven | When the container receives SIGTERM (e.g. from the gateway stopping it), the server shall shut down within 10 seconds. | Automated |
| REQ-OPS-003 | Event-driven | When a tool call has returned an error, the server shall continue serving subsequent requests. | Automated |
| REQ-OPS-004 | Event-driven | When multiple tool calls are in flight concurrently, the server shall respond to every one of them (no deadlock or dropped request). | Automated (the test session submits all requests in one batch) + unit test |

## Running the automated verification

Locally (image must exist; any tag works):

```bash
docker build -t plantuml-mcp:ci .
IMAGE=plantuml-mcp:ci bash test/acceptance-test.sh
```

Requirements not covered by the script (REQ-CAT-007, REQ-ERR-006) are
reported as `# SKIP` lines with the alternative verification method, so
the TAP output always lists every requirement ID.

Dependencies: `bash`, `docker`, `jq`, `base64`, `od` (all present on
GitHub `ubuntu-latest` runners).
