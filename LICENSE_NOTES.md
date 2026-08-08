# License notes

This file is an engineering checklist, not legal advice.

## This project

- License: MIT (Copyright (c) 2026 potofo) — see `LICENSE.txt`
- Every source file carries an SPDX `MIT` header

## PlantUML

- Artifact: `net.sourceforge.plantuml:plantuml-mit` (Maven Central)
- License: MIT (PlantUML is multi-licensed; the `-mit` artifact is built
  from the same sources with GPL-only components stripped)
- Excluded features in the MIT build: ditaa, sudoku, jcckit
- Do NOT add the JLaTeXMath jar (GPL) — it would re-introduce GPL
  obligations for math rendering

## Graphviz

- License: EPL-1.0
- Installed in the Docker image as a separate external program
  (`/usr/bin/dot`); PlantUML invokes it as a subprocess, not via linking.
  Mere aggregation in the image does not affect this project's MIT license.

## MCP Java SDK

- Artifact: `io.modelcontextprotocol.sdk:mcp`
- License: MIT

## Fonts (bundled in the Docker image)

- Noto Sans CJK (Alpine `font-noto-cjk`) and Noto Serif CJK JP (fetched
  from the notofonts repository, pinned tag) — SIL Open Font License 1.1
- DejaVu (`ttf-dejavu`) — Bitstream Vera license
- Fonts are data consumed by the renderer, not linked code; OFL/Vera
  permit bundling and redistribution and do not affect this project's
  MIT license.

## Historical note

Earlier revisions of this project were based on the
`plantuml/plantuml-server` Docker image (GPL-3.0), which made the whole
distributed image GPL-3.0 and blocked official Docker MCP Registry
submission. That design was replaced by in-process rendering with
`plantuml-mit`.

## Release checklist

- [x] project license file (MIT) and SPDX headers
- [x] third-party license notices in README (PlantUML, MCP SDK, Graphviz)
- [x] record exact `plantuml-mit` version per release (pom.xml property,
      captured in the tagged source of each GitHub Release)
- [x] released image pinned by digest (release-generated catalog.yaml)
- [x] avoid implying official PlantUML endorsement
- [ ] review Docker MCP Catalog contribution requirements before submission
