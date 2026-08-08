# Design: PlantUML MCP Server for Docker MCP Gateway

## 1. Goal

Let users render PlantUML as SVG / PNG simply by adding this server from
the Docker MCP Catalog or a custom OCI catalog.
License the whole project under MIT so that it satisfies the license
requirement of the official Docker MCP Registry.

## 2. Runtime architecture

```text
Client
  |
  | MCP / Streamable HTTP
  v
Docker MCP Gateway
  |
  | MCP / stdio
  v
Java MCP Server
  |
  | PlantUML core API (in-process)
  v
plantuml-mit (MIT)
  |
  | subprocess (dot)
  v
Graphviz (EPL-1.0)
```

Rendering completes **inside a single JVM**. The previous design — a
separate PlantUML Server (Jetty) process — has been retired, which
resolves both the GPL-3.0 inheritance and the GET URL length limit.

## 3. Why stdio

- The Docker MCP Gateway manages the container lifecycle
- The MCP Server itself does not need to expose an HTTP port
- The Java MCP SDK ships a stdio transport out of the box
- stdout is reserved for the MCP protocol; logs go to stderr

## 4. Rendering

The MCP Server renders PlantUML source directly via `SourceStringReader`.

- No URL encoding over HTTP, so the GET URL length limit no longer exists
- Syntax errors are detected via `PSystemError` and returned as MCP
  `isError` results
- Layout for class / component / state / usecase diagrams is performed by
  PlantUML launching Graphviz (`dot`) as an external process

## 5. Container lifecycle

1. Container start = `java -jar plantuml-mcp.jar` (single process)
2. MCP Server exit = container exit

Readiness probing and child-process supervision are no longer needed.

## 6. MCP tools

- `render_svg`
- `render_png`

## 7. Security

- No exposed ports (stdio only)
- `PLANTUML_SECURITY_PROFILE=INTERNET`
- Source length limit (100,000 characters)
- Runs as a non-root user (uid 10001)
- No logging to stdout

## 8. Versioning

The PlantUML version is managed in a single Maven property in `pom.xml`.

```xml
<plantuml.version>1.2026.6</plantuml.version>
```

`plantuml-mit` is published to Maven Central from the same sources with
the same version numbers as the GPL artifact, so upgrading is a one-line
change.

## 9. Licensing

- This project: MIT (potofo)
- PlantUML: uses `plantuml-mit` (MIT). GPL-only features (ditaa,
  JLaTeXMath math rendering) are unavailable
- MCP Java SDK: MIT
- Graphviz: EPL-1.0, bundled in the image as a separate external program
  (invoked as a subprocess, not linked, so it does not affect the
  project's MIT license)

The distributed image contains no GPL components, so it satisfies the
official Docker MCP Registry license requirement (MIT/Apache welcome,
GPL not accepted).

## 10. Layout engine options

- Default: Graphviz (EPL-1.0, full quality)
- Alternative: Smetana (pure-Java Graphviz port built into PlantUML,
  `!pragma layout smetana`) — fallback option if a fully self-contained
  image without Graphviz ever becomes necessary
