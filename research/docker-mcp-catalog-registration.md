# Registering this project in the Docker MCP Catalog

This document describes how to register the PlantUML MCP Server in the
Docker MCP Catalog. There are two routes:

- **Route A: Official Docker MCP Catalog** — contribute to
  [docker/mcp-registry](https://github.com/docker/mcp-registry) via pull
  request. The server appears in Docker Desktop's MCP Toolkit and Docker Hub
  for all users.
- **Route B: Custom catalog** — import a catalog file into your own Docker
  MCP Gateway. Private to you / your organization, no review process.

> **License status for Route A: satisfied.**
> The official registry requires a license that "allows people to consume
> it. (MIT or Apache 2 are great, GPL is not)." This project is MIT-licensed:
> rendering runs in-process with the MIT-licensed
> `net.sourceforge.plantuml:plantuml-mit` artifact, and the image no longer
> contains the GPL-3.0 `plantuml/plantuml-server`. Graphviz (EPL-1.0) is
> included only as a separate external program, which does not affect the
> project license. Docker-built submission (Option A in the registry's terms)
> is therefore available.

## Prerequisites (both routes)

1. **Public GitHub repository** — this project must be pushed to a public
   GitHub repository with the `Dockerfile` at the repository root (already
   satisfied by this repo layout). Update `source.project` in
   [`server.yaml`](../server.yaml) with the real URL.
2. **Published OCI image** (Route B, or Route A with a self-built image —
   for the recommended Docker-built Route A this step is not needed) —
   **automated by the release workflow**
   ([`.github/workflows/release.yml`](../.github/workflows/release.yml)).
   Pushing a `v*` tag builds a multi-arch (amd64/arm64) image, pushes it
   to `ghcr.io/<owner>/plantuml-mcp-server`, and attaches a digest-pinned
   `catalog.yaml` to the GitHub Release:

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. **License housekeeping** — `LICENSE.txt` (MIT), SPDX headers in every
   source file, and the README License sections (including third-party
   notices for plantuml-mit, the MCP Java SDK, and Graphviz) are already
   in place.

## Route A: Official Docker MCP Catalog (docker/mcp-registry)

### A-1. Install tooling

- Go v1.24+
- [Task](https://taskfile.dev)
- Access to a machine with Docker — the registry tooling (`task wizard` /
  `task build` / `task catalog`) builds and runs containers. The Linux
  server that already runs Docker MCP Gateway works fine; Docker Desktop
  is an option, not a requirement. Your Windows dev machine itself needs
  only JDK + Maven.

Note: publishing a release requires no local Docker at all — the GitHub
Actions release workflow builds and pushes the image.

### A-2. Fork and clone the registry

```bash
gh repo fork docker/mcp-registry --clone
cd mcp-registry
```

### A-3. Generate the server entry

Interactive wizard (recommended — it analyzes the GitHub repo's Dockerfile
and pre-fills defaults):

```bash
task wizard
```

Or non-interactive. Since the project is MIT-licensed, the recommended
path is to let Docker build and host the image in the `mcp/` namespace
(with signatures, SBOMs, and automatic security updates):

```bash
task create -- --category productivity \
  https://github.com/<you>/plantuml-mcp-server
```

To use a self-built image instead, add
`--image <your-registry>/plantuml-mcp:0.1.0`.

This creates `servers/plantuml/server.yaml` in the registry repo. The
[`server.yaml`](../server.yaml) in this repository is already written in
the required format (`meta`, `about`, `source` blocks) and can be used as
the basis for that entry.

### A-4. Test locally

```bash
task build -- --tools plantuml        # builds and verifies the tool list (render_svg / render_png)
task catalog -- plantuml              # generates a local catalog
docker mcp catalog import $PWD/catalogs/plantuml/catalog.yaml
```

Then enable the PlantUML server and run a test tool call — with the
`docker mcp` CLI (`docker mcp server enable plantuml`, then a tool call
through `docker mcp gateway run`), or via Docker Desktop's MCP Toolkit UI
if you use Docker Desktop. Afterwards:

```bash
docker mcp catalog reset
```

### A-5. Submit the pull request

1. Confirm the license requirement (see the license note above — MIT,
   satisfied).
2. Open a PR against `docker/mcp-registry` with a descriptive title
   (commits are squashed; the PR title becomes the commit message).
3. Make CI pass.
4. If the server needs credentials for review, submit them via the Google
   Form linked in the PR template (not applicable to this server).
5. Wait for Docker team review.

### A-6. After merge

Within 24 hours of approval the server appears in the MCP catalog, Docker
Desktop's MCP Toolkit, and (for Docker-built images) the Docker Hub `mcp`
namespace.

## Route B: Custom catalog (private use)

No review process — useful for testing before a Route A submission, or
for keeping the server private to your organization.

1. Push a release tag (see Prerequisites) and download the digest-pinned
   `catalog.yaml` attached to the GitHub Release. It is generated by the
   release workflow and intentionally not kept in the repository, so
   there is nothing to edit by hand.
2. Import the catalog:

   ```bash
   docker mcp catalog import /path/to/plantuml-mcp-server/catalog.yaml
   ```

3. Enable the server with the `docker mcp` CLI on that machine (or via
   Docker Desktop's MCP Toolkit UI if you use Docker Desktop), run
   `docker mcp gateway run`, and connect your MCP client (VS Code,
   Claude Desktop, etc.). See
   [windows-build-remote-gateway-test.md](windows-build-remote-gateway-test.md)
   for the full remote-server flow.
4. To remove it later:

   ```bash
   docker mcp catalog reset
   ```

## File map in this repository

| File | Role |
| --- | --- |
| [`server.yaml`](../server.yaml) | Entry in docker/mcp-registry format (Route A) |
| `catalog.yaml` | Not in the repository — generated digest-pinned per release and attached to the GitHub Release (Route B) |
| [`.github/workflows/release.yml`](../.github/workflows/release.yml) | Tag-driven release: multi-arch build, GHCR push, catalog.yaml generation |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | Build + render smoke test on push/PR |
| [`.github/dependabot.yml`](../.github/dependabot.yml) | Automated update PRs (plantuml-mit, base images, actions) |
| [`Dockerfile`](../Dockerfile) | Must stay at repo root (Route A requirement) |
| [`LICENSE.txt`](../LICENSE.txt) | MIT license text |
| [`LICENSE_NOTES.md`](../LICENSE_NOTES.md) | Licensing checklist |

## Remaining TODOs before submission

- [ ] Push this project to `https://github.com/potofo/plantuml-mcp-server`
      (public) — `source.project` in `server.yaml` already points there
- [x] Image publishing — automated by the release workflow (tag push)
- [x] Digest pinning of the released image — the generated `catalog.yaml`
      references the image by digest
- [ ] After the first release: set the GHCR package visibility to public

---

*Sources:
[docker/mcp-registry CONTRIBUTING.md](https://github.com/docker/mcp-registry/blob/main/CONTRIBUTING.md),
[docker/mcp-registry README](https://github.com/docker/mcp-registry).
Verified on 2026-08-08.*
