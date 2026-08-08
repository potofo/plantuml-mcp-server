# Implementation plan

## Phase 1 - Compile and smoke-test

- [x] Confirm Java MCP SDK 2.0.0 API compiles (fixed: `Tool.builder(name, McpJsonDefaults.getMapper(), schema)` — the 2-arg String overload does not exist)
- [x] Confirm plantuml-mit in-process rendering compiles (SourceStringReader / PSystemError)
- [x] Smoke test on Windows: initialize + `render_svg` over stdio returns SVG (sequence diagram, no Graphviz needed)
- [x] Build image (WSL Ubuntu 22.04, Docker Engine 28)
- [x] Test `render_svg` (returns downloadable SVG as EmbeddedResource)
- [x] Test `render_png` (returns ImageContent, displayed inline in Dify)
- [x] Test a Graphviz-dependent diagram (class diagram) inside the container

## Phase 2 - Docker MCP Gateway

- [x] Add local server entry (custom-catalog.yaml on the gateway server, referenced via docker-compose `--additional-catalog`)
- [x] Run tool calls from an MCP client (Dify agent, end-to-end verified — see research/dify-integration.md)
- [ ] Import the release-generated `catalog.yaml` (digest-pinned, attached to the GitHub Release)
- [ ] Connect profile to VS Code

## Phase 3 - Hardening

- [x] source size limit (100,000 chars)
- [ ] render timeout
- [ ] malformed PlantUML tests (PSystemError path)
- [ ] Unicode/Japanese tests
- [ ] stderr-only logging
- [x] non-root user (uid 10001)
- [ ] read-only filesystem evaluation
- [ ] pin base image (eclipse-temurin) by digest

## Phase 4 - Catalog release

- [ ] push to https://github.com/potofo/plantuml-mcp-server (public); `source.project` in server.yaml is already set
- [x] image publishing — automated (release workflow pushes to GHCR on tag)
- [x] amd64/arm64 — automated (buildx in release workflow)
- [x] image digest pinning — automated (release-generated catalog.yaml references the digest)
- [ ] set GHCR package visibility to public after the first release
- [ ] custom OCI catalog test
- [ ] official Docker MCP Catalog contribution (MIT license requirement: satisfied)

## Resolved by the in-process redesign

- Large-diagram GET URL length limit — no HTTP hop exists anymore
- PlantUML Server readiness probe / process supervision — single JVM
- GPL-3.0 license inheritance — replaced by plantuml-mit (MIT) + Graphviz (EPL, external process)
