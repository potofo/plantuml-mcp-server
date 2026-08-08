# Build in WSL, copy the image to a Linux server, and test

This document describes how to build the container image inside WSL
(Ubuntu 22.04) on Windows, export it to `./containder/`, copy it to the
Linux server where Docker MCP Gateway runs, and test it there.
**No Docker Desktop, no GitHub push, no container registry required.**

```text
Windows + WSL (build & export)          Linux server (load, run & test)
------------------------------          -------------------------------
docker build (in WSL)
docker save → ./containder/*.tar.gz ── scp ──▶  docker load
                                                docker mcp catalog import
                                                docker mcp gateway run
```

Compared to [windows-build-remote-gateway-test.md](windows-build-remote-gateway-test.md)
(transfer sources, build on the server), this flow builds locally in WSL
and transfers the finished image. Choose this when you want to keep the
server free of build load, or verify the exact image bytes you tested
locally.

## Prerequisites

| Machine | Requirement |
| --- | --- |
| Windows | WSL2 with Ubuntu 22.04 and **Docker Engine installed inside WSL** (verify: `wsl -d Ubuntu-22.04 docker version`). Docker Desktop is NOT required. |
| Linux server | Docker Engine, Docker MCP Gateway (`docker mcp` CLI), SSH access |

**Architecture note**: WSL is x86_64, so the built image runs on x86_64
servers. For an ARM server, use the build-on-server flow instead
([windows-build-remote-gateway-test.md](windows-build-remote-gateway-test.md)).

## 1. Build the image in WSL

The project directory on `D:` is visible from WSL under `/mnt/d`.
From a Windows terminal (or a WSL terminal in VS Code):

```powershell
wsl -d Ubuntu-22.04 -- bash -c "cd /mnt/d/Developments/plantuml-mcp-server && docker build -t plantuml-mcp:dev ."
```

## 2. Export the image to ./containder/

```powershell
wsl -d Ubuntu-22.04 -- bash -c "mkdir -p /mnt/d/Developments/plantuml-mcp-server/containder && docker save plantuml-mcp:dev | gzip > /mnt/d/Developments/plantuml-mcp-server/containder/plantuml-mcp-dev.tar.gz"
```

This produces `containder/plantuml-mcp-dev.tar.gz` (~100 MB gzipped from
a ~244 MB image). The folder is listed in `.gitignore` — exported images
are local artifacts and must not be committed.

## 3. Copy the archive to the Linux server

From Windows (OpenSSH `scp` is bundled with Windows 10/11):

```powershell
scp d:\Developments\plantuml-mcp-server\containder\plantuml-mcp-dev.tar.gz user@linux-host:~/
```

## 4. Load the image on the server

`docker load` reads gzipped archives directly — no need to decompress:

```bash
ssh user@linux-host
docker load -i ~/plantuml-mcp-dev.tar.gz
docker image ls plantuml-mcp
```

## 5. Smoke test on the server (no gateway)

Create `req.jsonl`:

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"render_svg","arguments":{"source":"@startuml\nclass Car {\n  +drive()\n}\nclass Engine\nCar *-- Engine\n@enduml"}}}
```

Run it — **keep stdin open for a few seconds after sending** (the server
shuts down its transport on stdin EOF, so a plain pipe may cut off the
response):

```bash
(cat req.jsonl; sleep 20) | timeout 25 docker run -i --rm plantuml-mcp:dev > resp.jsonl
grep -o 'data-diagram-type=[^ ]*' resp.jsonl   # expect: CLASS
```

A class diagram is used deliberately — it exercises the bundled Graphviz.

## 6. Register in a local catalog and test through the gateway

Create `catalog.local.yaml` on the server:

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

```bash
docker mcp catalog import ./catalog.local.yaml
docker mcp gateway run
```

For an MCP client on another machine, start the gateway with a network
transport (e.g. `docker mcp gateway run --transport streaming --port 8811`)
and point the client at `http://linux-host:8811/mcp`. See
[windows-build-remote-gateway-test.md](windows-build-remote-gateway-test.md)
§6 for details.

## 7. Iterating and cleanup

Re-test after a code change = repeat steps 1–4 (same `dev` tag overwrites
on load; the gateway uses the new image on the next container start).

Cleanup on the server:

```bash
docker mcp catalog reset
docker rmi plantuml-mcp:dev
rm -f ~/plantuml-mcp-dev.tar.gz
```

On Windows, delete `containder/*.tar.gz` when no longer needed.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| `exec format error` on the server | The server is not x86_64 — use the build-on-server flow instead |
| `docker: command not found` in WSL | Docker Engine is not installed in the WSL distro — install it, or use the build-on-server flow |
| Smoke test returns only the `initialize` response | stdin closed too early — use the `(cat req.jsonl; sleep 20)` form shown above |
| Gateway tries to pull `plantuml-mcp:dev` | Image missing on the server — re-check `docker image ls` after step 4 |
