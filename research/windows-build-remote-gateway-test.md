# Build on Windows (JDK + Maven), test on a remote Docker MCP Gateway server

This document describes how to develop and verify the PlantUML MCP Server
on a Windows machine using **only JDK and Maven — no Docker Desktop**,
then build the container image and test it on the Linux server where
Docker MCP Gateway runs. No GitHub push and no container registry are
required.

```text
Windows (verify jar)                Linux server (build image, run & test)
--------------------                ---------------------------------------
mvn package
(optional local run) ── scp/rsync ─▶  docker build
     source tree                      docker mcp catalog import
                                      docker mcp gateway run
```

The key idea: the `Dockerfile` is multi-stage and runs Maven inside its
build stage, so **the only machine that needs Docker is the Linux server
itself** — and it already has Docker Engine because the gateway runs
there. Since the image is built natively on the server, CPU-architecture
mismatches cannot happen (no `--platform` juggling).

## Prerequisites

| Machine | Requirement |
| --- | --- |
| Windows | JDK 17+ and Maven 3.9+ (install steps: see [README](../README.md#prerequisites-on-windows)), OpenSSH client (`scp`/`ssh`, bundled with Windows 10/11). **Docker Desktop is NOT required.** |
| Linux server | Docker Engine, Docker MCP Gateway (`docker mcp` CLI), SSH access |

## 1. Build and verify the jar on Windows

From the project root:

```powershell
mvn -q -DskipTests package
```

This catches compile errors in seconds. The jar is produced at
`target\plantuml-mcp.jar`. (It is not transferred anywhere — the server
rebuilds it inside `docker build`. This step is your fast local check.)

Optional: run the MCP server directly on Windows and render a sequence
diagram (sequence diagrams don't need Graphviz, so this works with JDK
alone). Save the three JSON-RPC lines as `req.jsonl`:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"render_svg","arguments":{"source":"@startuml\nAlice -> Bob : hello\n@enduml"}}}
```

Then run from Git Bash or WSL — **keep stdin open for a few seconds
after sending** (the server shuts down its transport on stdin EOF, so a
plain pipe may cut off the response), and let `timeout` stop the
long-running server process:

```bash
(cat req.jsonl; sleep 15) | timeout 20 java -Djava.awt.headless=true -jar target/plantuml-mcp.jar > resp.jsonl
grep -c "<svg" resp.jsonl   # 1 = success
```

## 2. Transfer the source tree to the Linux server

The server needs the sources (not the jar), because `docker build`
compiles inside the build stage:

```powershell
scp -r d:\Developments\plantuml-mcp-server user@linux-host:~/
```

For repeated transfers, excluding build output is faster (if rsync is
available, e.g. via Git Bash or WSL):

```bash
rsync -a --exclude target/ /d/Developments/plantuml-mcp-server/ user@linux-host:~/plantuml-mcp-server/
```

## 3. Build the image on the Linux server

```bash
ssh user@linux-host
cd ~/plantuml-mcp-server
docker build -t plantuml-mcp:dev .
```

Native build — the image automatically matches the server's architecture.

## 4. Smoke test on the server (no gateway)

The server speaks MCP over stdio, so you can test with raw JSON-RPC
before involving the gateway:

Reuse the `req.jsonl` from step 1 (or a class-diagram variant) and keep
stdin open for a few seconds after sending:

```bash
(cat req.jsonl; sleep 20) | timeout 25 docker run -i --rm plantuml-mcp:dev > resp.jsonl
grep -c "<svg" resp.jsonl   # 1 = success
```

Unlike the Windows-side check in step 1, this also covers
Graphviz-dependent diagrams (class diagrams etc.), since the container
bundles Graphviz.

## 5. Register the image in a local catalog

On the Linux server, create `catalog.local.yaml`:

```yaml
version: 2
name: plantuml-local
displayName: PlantUML Local Test
registry:
  plantuml:
    title: PlantUML (local dev)
    type: server
    image: plantuml-mcp:dev
    description: Local test build.
    longLived: false
    tools:
      - name: render_svg
      - name: render_png
```

`image:` references the server's local image store — the image built in
step 3 is used as-is, nothing is pulled. Import it:

```bash
docker mcp catalog import ./catalog.local.yaml
```

## 6. Test through the gateway

Run the gateway on the Linux server:

```bash
docker mcp gateway run
```

- For an MCP client on another machine (e.g. VS Code on Windows), start
  the gateway with a network transport instead, e.g.
  `docker mcp gateway run --transport streaming --port 8811`, and point
  the client at `http://linux-host:8811/mcp`. (Flag names vary slightly
  between `docker mcp` versions — check `docker mcp gateway run --help`.)
- If your `docker mcp` version provides them, `docker mcp tools list` and
  `docker mcp tools call render_svg source='@startuml...'` allow testing
  without any MCP client.

From the client, call `render_svg` with a small diagram and confirm SVG
text comes back.

## 7. Iterating and cleanup

The edit-test loop is: edit on Windows → `mvn -q -DskipTests package`
(fast check) → transfer (step 2) → `docker build` on the server (step 3;
same `dev` tag overwrites, the gateway picks up the new image on the next
container start).

Cleanup on the server:

```bash
docker mcp catalog reset          # remove the imported test catalog
docker rmi plantuml-mcp:dev
rm -rf ~/plantuml-mcp-server
```

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| Gateway tries to pull `plantuml-mcp:dev` | The image is missing on the server — re-check `docker image ls plantuml-mcp` after step 3 |
| No response on stdio test | Make sure `-i` is passed to `docker run`; stdout must stay MCP-only (logs go to stderr) |
| Class diagram fails on Windows (step 1) but works in the container | Expected — Graphviz is bundled in the image, not on Windows. Use sequence diagrams for the Windows-side check, or install Graphviz locally |
| Japanese text renders as boxes (tofu) | Symptom of old images (current image bundles Noto Sans CJK / Noto Serif CJK JP). Rebuild with the latest Dockerfile |

---

*Related: [docker-mcp-catalog-registration.md](docker-mcp-catalog-registration.md)
(publishing via GHCR / official catalog). This local flow is the manual
equivalent of what the release workflow automates.*
