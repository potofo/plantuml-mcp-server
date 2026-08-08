# Using the PlantUML MCP Server from Dify (integration guide)

How to call the PlantUML MCP Server from a Dify agent through the Docker
MCP Gateway, with diagrams displayed inline and downloadable in chat —
including the pitfalls we actually hit (verified 2026-08-09).

```text
Dify (Agent / FunctionCalling)
  |
  | Streamable HTTP (+ Bearer token)
  v
nginx (reverse proxy stripping Origin)
  |
  v
docker/mcp-gateway (docker-compose)
  |
  | stdio (container per call: --pull never)
  v
plantuml-mcp:dev container
```

## 1. Response design on the MCP server side (crucial)

How results appear in Dify is determined by the MCP content type the
tool returns.

| Tool | Return type | Appearance in Dify |
| --- | --- | --- |
| `render_png` | `ImageContent` (Base64 + `image/png`) | Converted to `files`: inline image in chat + download |
| `render_svg` | `EmbeddedResource` (blob, `image/svg+xml`) + short status text | Converted to `files`: attached as a downloadable file |

Design lessons:

- **Never return image data as `TextContent`.** A Base64 string is just
  text to Dify, and it tempts the LLM into transcribing it into the
  answer (broken rendering + wasted tokens).
- **Don't return full SVG text either.** Tool responses are injected
  into the calling LLM's context; we measured 25,000+ prompt tokens for
  one large diagram. Returning a blob (file) means the LLM only sees a
  one-line status.
- **Steer the LLM with tool descriptions.** Descriptions reach the LLM
  under every agent strategy, more reliably than the instruction. This
  server says "Preferred tool for displaying diagrams" on render_png and
  "Use ONLY when the user explicitly asks for SVG format" on render_svg.
- **Advertise the renderer version in the description.** LLMs tend to
  write whatever PlantUML syntax dominates their training data, which
  drifts from the actual renderer and causes syntax errors. This server
  reads the real version at startup via `Version.versionString()` and
  embeds "Renderer: PlantUML 1.2026.6 (MIT build; ditaa and LaTeX math
  unavailable); write syntax compatible with this version." into both
  tool descriptions — automatically tracking jar upgrades, unlike
  hand-written instruction text. Line-numbered syntax errors returned to
  the LLM complete the self-correction loop.

## 2. Dify setup

1. **Register the MCP provider** — gateway URL (e.g.
   `http://<host>:8080/mcp`) plus the Bearer token.
2. **Agent node**
   - Strategy: **Agent > FunctionCalling** (the standard one).
     `EnhanceFunctionCalling` injects its own task-decomposition prompts,
     which conflicted with the instruction and destabilized tool choice.
   - Model: **pin a current-generation model with strong tool calling**
     (verified stable with Claude Sonnet 4.5+). gpt-4o was unreliable
     (wrote the source without calling any tool, or announced rendering
     and stopped). AutoRouter is unsuitable for verification because the
     model changes per request.
   - Toolbox: enable `render_png` / `render_svg`.
3. **Answer node** — put `Agent {x}text` and `Agent {x}files` in the
   response (images and SVG files arrive via `files`).

## 3. INSTRUCTION (final, verified version — Japanese)

See the Japanese guide
([dify-integration.ja-JP.md](dify-integration.ja-JP.md) §3) for the full
instruction text used in production. Its structure:

- **Tool selection (single authoritative section)**: render_png is the
  default; render_svg only on explicit request
- **Procedure**: build PlantUML source → MUST call the tool (writing
  source alone is forbidden) → on error, read the line-numbered message,
  fix, retry up to 3 times
- **Drawing rules**: Japanese labels allowed (Noto Sans CJK gothic and
  Noto Serif CJK JP mincho are bundled; select via
  `skinparam defaultFontName`), source size limit
- **Output format**: include the PlantUML source in a code block;
  embedding images (`![](data:...)`) or transcribing Base64/SVG bodies
  is forbidden — attachments happen automatically

**Prompt-design lesson**: state critical policies (like tool priority)
in **exactly one place**. Duplicated statements drift apart on edits, and
capable models dutifully agonize over the contradiction — Sonnet's
thinking log literally said "conflicting instructions" and then picked
the wrong side.

## 4. Propagation flow after updating the server image

```bash
# 1. Load the new image on the server
docker load -i plantuml-mcp-dev.tar.gz

# 2. Restart the gateway (tool definitions are cached at gateway startup)
cd /docker/mcp-gateway-compose
docker compose restart mcp-gateway-core
```

3. **Re-sync tools in Dify** — Dify caches tool definitions too;
   refresh the tool list (a changed description confirms propagation).

Because a fresh container is started per tool call (`longLived: false`),
**behavior changes take effect right after `docker load`**. The restart
and re-sync are only needed when tool definitions (names, descriptions,
schemas) change.

## 5. Troubleshooting (all actually encountered)

| Symptom | Cause | Fix |
| --- | --- | --- |
| SVG/Base64 shows as text in chat | Tool returns `TextContent` | Return `ImageContent` / `EmbeddedResource` from the server |
| Broken image icon | Dify `FILES_URL` misconfiguration (trailing slash, api/worker not restarted, `/files` path not proxied) | Set `FILES_URL` empty to isolate; if setting it, no trailing slash + restart api/worker + proxy `/files` |
| LLM writes the source but never calls a tool | Weak tool-calling model (frequent with gpt-4o) | Use a current-generation model; instruction states "writing source alone is forbidden" |
| LLM picks the wrong tool | Contradictions left in the instruction, or EnhanceFunctionCalling's injected prompts | Keep each policy in one place; use plain FunctionCalling; steer via tool descriptions |
| LLM transcribes Base64 into the answer | Model believes it must "show" the image | Say attachments are automatic; forbid data-URI form with a concrete example |
| Tool descriptions stay stale | Gateway/Dify caches | Restart gateway + re-sync Dify tools (§4) |
| Abnormally high prompt tokens | Full SVG text injected into LLM context | render_svg returns a blob now (fixed in this design) |

## 6. Related documents

- [wsl-build-image-transfer-test.md](wsl-build-image-transfer-test.md) — building and transferring the image
- [docker-mcp-catalog-registration.md](docker-mcp-catalog-registration.md) — catalog registration (this deployment references a custom catalog via docker-compose `--additional-catalog`)
