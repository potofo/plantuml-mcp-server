# PlantUML MCP Server

A Java-based stdio MCP Server that renders PlantUML diagrams, designed for
the Docker MCP Gateway. Rendering runs **in-process** using the MIT-licensed
PlantUML artifact (`net.sourceforge.plantuml:plantuml-mit`) — no separate
PlantUML Server is required. Graphviz (EPL-1.0) is bundled in the image as
an external program for diagram layout.

## Architecture

```text
MCP Client
   |
   | Streamable HTTP
   v
Docker MCP Gateway
   |
   | stdio
   v
+------------------------------------+
| Single Docker Container            |
|                                    |
|  Java MCP Server                   |
|      |                             |
|      | PlantUML core API           |
|      | (in-process, plantuml-mit)  |
|      v                             |
|  Graphviz "dot"                    |
|  (external process, EPL-1.0)       |
+------------------------------------+
```

## MVP tools

- `render_svg`
- `render_png`

## Build (local development)

```bash
mvn -q -DskipTests package
docker build -t plantuml-mcp:dev .
```

### Prerequisites on Windows

Building the jar with `mvn` requires **JDK 17+** and **Maven 3.9+** on
your machine. (If you only need the Docker image, Maven is *not*
required — `docker build` runs Maven inside the build stage.)

JDK — install with winget (skip if a JDK 17+ is already installed):

```powershell
winget install EclipseAdoptium.Temurin.17.JDK
```

Maven — **not available via winget**; install the binary zip manually
(no admin rights required):

```powershell
# 1. Download and extract to your user programs folder
Invoke-WebRequest https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip -OutFile "$env:TEMP\maven.zip"
Expand-Archive "$env:TEMP\maven.zip" -DestinationPath "$env:LOCALAPPDATA\Programs"

# 2. Set JAVA_HOME and add Maven to PATH (user scope, persistent)
[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Java\jdk-21", "User")   # adjust to your JDK path
[Environment]::SetEnvironmentVariable("PATH", [Environment]::GetEnvironmentVariable("PATH","User") + ";$env:LOCALAPPDATA\Programs\apache-maven-3.9.9\bin", "User")
```

(Alternatively `choco install maven` / `scoop install maven` if you use
those package managers.)

Open a **new** terminal and verify:

```powershell
mvn -version   # should show Maven 3.9+ and Java 17+
```

## Release (automated)

Releases are fully automated by GitHub Actions — the only manual step is
pushing a tag:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The release workflow then:

1. builds a multi-arch (amd64/arm64) image
2. pushes it to GHCR as `ghcr.io/<owner>/plantuml-mcp-server` (derived
   from the repository name, so forks publish to their own GHCR without
   editing any file)
3. generates a **digest-pinned `catalog.yaml`** and attaches it to the
   GitHub Release

Note for forks: enable GitHub Actions once after forking, and set the
GHCR package to public after the first release if you want anonymous pulls.

## Upgrading PlantUML

The PlantUML version is a single Maven property in [pom.xml](pom.xml):

```xml
<plantuml.version>1.2026.6</plantuml.version>
```

`plantuml-mit` is published to Maven Central with the same version numbers
and release cadence as the GPL artifact, so upgrading is a one-line change
plus a rebuild.

## Docker MCP catalog

- **Official catalog** — `server.yaml` is the manifest in the official
  [docker/mcp-registry](https://github.com/docker/mcp-registry)
  contribution format. The project is MIT-licensed, which satisfies the
  official catalog's license requirement.
- **Custom catalog** — download the digest-pinned `catalog.yaml` attached
  to a [GitHub Release](https://github.com/potofo/plantuml-mcp-server/releases)
  (generated automatically by the release workflow; it is not kept in the
  repository) and import it:

```bash
docker mcp catalog import ./catalog.yaml
```

## Feature notes (MIT build)

The MIT build of PlantUML excludes a few GPL-only components. In practice:

- **ditaa** diagrams are not available
- **AsciiMath/LaTeX math** rendering is not available (would require the
  GPL-licensed JLaTeXMath jar, which is deliberately not included)
- All UML diagram types, JSON/YAML, mindmap, WBS, Gantt, nwdiag, salt, etc.
  work as usual

## Fonts

The image bundles DejaVu (Latin), **Noto Sans CJK** (gothic) and
**Noto Serif CJK JP** (mincho), so Japanese/Chinese/Korean labels render
out of the box. Select a font per diagram with skinparam:

```plantuml
skinparam defaultFontName "Noto Serif CJK JP"   ' mincho
skinparam defaultFontName "Noto Sans CJK JP"    ' gothic (default fallback)
```

Per-element variants (`titleFontName`, `actorFontName`, ...) work as well.

## License

PlantUML MCP Server

Copyright (c) 2026 potofo

Licensed under the MIT License. See [LICENSE.txt](LICENSE.txt).

Third-party components:

- PlantUML (`net.sourceforge.plantuml:plantuml-mit`) — MIT License,
  Copyright PlantUML authors (Arnaud Roques)
- MCP Java SDK (`io.modelcontextprotocol.sdk:mcp`) — MIT License
- Graphviz — Eclipse Public License 1.0, installed in the Docker image as
  a separate external program (invoked as a subprocess, not linked)
- Noto Sans CJK / Noto Serif CJK fonts — SIL Open Font License 1.1
- DejaVu fonts — Bitstream Vera license (free)

This project is not affiliated with or endorsed by the PlantUML project.
