# Runbook: Submit this server to docker/mcp-registry (Route A)

Step-by-step procedure for an **autonomous AI agent** to submit
`plantuml-mcp-server` to the official Docker MCP Catalog by opening a
pull request against [docker/mcp-registry](https://github.com/docker/mcp-registry).

The work happens in a **separate working directory** (a clone of the
agent's fork of `docker/mcp-registry`) — **never in this repository**.
This repository is read-only reference material for the submission.

Japanese version: [submit-to-docker-mcp-registry.ja-JP.md](submit-to-docker-mcp-registry.ja-JP.md)

## Inputs

| Key | Value |
| --- | --- |
| Source repository | `https://github.com/potofo/plantuml-mcp-server` |
| License | MIT (uses `plantuml-mit`; no GPL components) |
| Server name | `plantuml` (fallback on collision: `plantuml-renderer`) |
| Category | `productivity` |
| Tools (must match) | `render_svg`, `render_png` |
| Configuration/secrets | None required |
| Icon | `https://avatars.githubusercontent.com/u/33107703?s=200&v=4` |
| Build option | Docker-built (Option A: Docker builds and hosts in the `mcp/` namespace) |
| Reference manifest | [`server.yaml`](../server.yaml) at the source repo root |
| Evidence release | `v0.1.0` (multi-arch amd64/arm64 on GHCR, digest-pinned catalog.yaml) |

## Prerequisites (verify before starting)

Run each check; **stop and report** if any fails.

```bash
git --version                 # any recent version
gh auth status                # authenticated; account can fork and open PRs
docker version --format '{{.Server.Version}}'   # daemon reachable
go version                    # Go 1.24+
task --version                # Task (taskfile.dev)
```

Machine requirements: Linux (or WSL2) with a working Docker Engine.
The registry's `task` tooling builds and runs containers locally.

## Procedure

### Step 0 — Preflight

1. Confirm the source repo is public and the license is MIT:

   ```bash
   gh repo view potofo/plantuml-mcp-server --json visibility,licenseInfo \
     --jq '{visibility, license: .licenseInfo.key}'
   # expect: {"visibility":"PUBLIC","license":"mit"}
   ```

2. Confirm the name is free in the registry:

   ```bash
   gh api repos/docker/mcp-registry/contents/servers/plantuml 2>&1 | head -1
   ```

   - HTTP 404 → name `plantuml` is free; proceed.
   - Entry exists → **decision point**: inspect it. If it points to this
     source repo, the submission already exists (stop, report). If it is
     a different project, use the fallback name `plantuml-renderer` for
     every remaining step.

### Step 1 — Fork and clone the registry

```bash
gh repo fork docker/mcp-registry --clone
cd mcp-registry
git checkout -b add-plantuml
```

If the fork already exists, `gh repo fork` reuses it; sync it first:
`gh repo sync <your-account>/mcp-registry --source docker/mcp-registry`.

### Step 2 — Generate the server entry

Non-interactive generation (do NOT use `task wizard`; it is interactive):

```bash
task create -- --category productivity https://github.com/potofo/plantuml-mcp-server
```

Expected result: `servers/plantuml/server.yaml` is created. The tool
reads the source repo's Dockerfile and `server.yaml` to fill defaults.

**Fallback** — if `task create` fails, write `servers/plantuml/server.yaml`
by hand, based on the reference manifest at the source repo root:

```yaml
name: plantuml
image: mcp/plantuml
type: server
meta:
  category: productivity
  tags:
    - plantuml
    - uml
    - diagrams
about:
  title: PlantUML
  icon: https://avatars.githubusercontent.com/u/33107703?s=200&v=4
  description: >-
    Render PlantUML source to SVG or PNG through Model Context Protocol.
    Community project, not affiliated with or endorsed by the PlantUML project.
source:
  project: https://github.com/potofo/plantuml-mcp-server
```

### Step 3 — Review the generated entry

Check `servers/plantuml/server.yaml` against the Inputs table:

- [ ] `name` is `plantuml` (or the fallback name)
- [ ] `meta.category` is `productivity`
- [ ] `about.description` includes the non-affiliation sentence
- [ ] `about.icon` is set and the URL returns an image
- [ ] `source.project` points to the source repository
- [ ] There is **no** `config` / `secrets` section (none is needed)

### Step 4 — Validate locally

```bash
task build -- --tools plantuml
```

Expected: the image builds from the source repo and the discovered tool
list contains exactly `render_svg` and `render_png`. If tools are
missing, the container failed to start — inspect the build output.

```bash
task catalog -- plantuml
docker mcp catalog import $PWD/catalogs/plantuml/catalog.yaml
```

Optional end-to-end check: enable the server and call a tool through
the gateway (`docker mcp server enable plantuml`, then
`docker mcp gateway run` and issue a `render_png` call from any MCP
client). Clean up afterwards:

```bash
docker mcp catalog reset
```

### Step 5 — Commit and push

The diff must contain **only** files under `servers/plantuml/`.

```bash
git status --short          # verify: nothing outside servers/plantuml/
git add servers/plantuml
git commit -m "Add PlantUML MCP server"
git push -u origin add-plantuml
```

### Step 6 — Open the pull request

PR title becomes the squash-commit message — keep it exact:

```bash
gh pr create --repo docker/mcp-registry \
  --title "Add PlantUML MCP server" \
  --body-file pr-body.md
```

`pr-body.md` content:

```markdown
## What

Adds the PlantUML MCP server: renders PlantUML source to SVG or PNG over
MCP (stdio), in-process via the MIT-licensed `plantuml-mit` artifact —
no external PlantUML server required. Graphviz (EPL-1.0) is bundled in
the image as a separate external program for diagram layout.

- Source: https://github.com/potofo/plantuml-mcp-server
- License: MIT (`net.sourceforge.plantuml:plantuml-mit`; no GPL components)
- Tools: `render_svg`, `render_png` — no configuration or secrets required
- Docker-built image requested (`mcp/` namespace)
- Multi-arch proven: the v0.1.0 release publishes linux/amd64 + linux/arm64
- Community project; not affiliated with or endorsed by the PlantUML project

## Testing

- `task build -- --tools plantuml` discovers both tools
- `task catalog -- plantuml` + `docker mcp catalog import` verified locally
- The source repo runs an EARS-traced acceptance suite in CI
  (see `test/ACCEPTANCE.md` there)
```

No test credentials form is needed (the server takes no auth).

### Step 7 — Post-submission

1. Watch CI: `gh pr checks --repo docker/mcp-registry <pr-number> --watch`.
   Fix failures by amending files under `servers/plantuml/` only.
2. Respond to Docker-team review comments. Known likely request:
   **rename** due to PlantUML branding. If asked, rename the directory
   and the `name:` field (e.g. `plantuml-renderer`), and update the PR —
   do not argue the point; the fallback name is pre-approved by the
   source project.
3. After approval and merge, the server appears in the MCP catalog /
   Docker Desktop MCP Toolkit within ~24 hours. Verify with:
   `docker mcp catalog show | grep -i plantuml` (on any machine with the
   default catalog).

## Guardrails

- Modify **nothing** outside `servers/plantuml/` in the registry repo.
- Never commit credentials; this submission requires none.
- Do not push to `docker/mcp-registry` directly; only to the fork.
- Idempotency: before each step, check whether its result already exists
  (fork, branch, entry, PR) and resume instead of duplicating.
- If any step fails twice for the same reason, stop and report the raw
  error output; do not improvise workarounds that alter other files.

## References

- [docker/mcp-registry CONTRIBUTING.md](https://github.com/docker/mcp-registry/blob/main/CONTRIBUTING.md)
  (authoritative requirements; re-read before submitting)
- Background research in this repo:
  [research/docker-mcp-catalog-registration.md](../research/docker-mcp-catalog-registration.md)
- Registry readiness evaluation:
  [test/Evaluation-registry-mcp-registry.md](../test/Evaluation-registry-mcp-registry.md)
