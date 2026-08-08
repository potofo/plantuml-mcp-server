# syntax=docker/dockerfile:1
# PlantUML MCP Server
# Copyright (c) 2026 potofo
#
# SPDX-License-Identifier: MIT
# Licensed under the MIT License. See LICENSE.txt in the project root
# for full license text.
#
# PlantUML rendering is provided in-process by the MIT-licensed
# net.sourceforge.plantuml:plantuml-mit artifact. Graphviz (EPL-1.0) is
# installed as a separate external program that PlantUML invokes as a
# subprocess for layout of class/component/state/usecase diagrams.

# --platform=$BUILDPLATFORM: the jar is architecture-independent, so build it
# once natively instead of under QEMU emulation for each target platform.
FROM --platform=$BUILDPLATFORM maven:3-eclipse-temurin-26 AS mcp-build
WORKDIR /build
COPY pom.xml .
RUN mvn -q -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:17-jre-alpine

# graphviz: layout engine (EPL-1.0, invoked as external process)
# fontconfig + ttf-dejavu: fonts for headless text rendering
# font-noto-cjk: Noto Sans CJK = gothic CJK glyphs (SIL OFL 1.1)
RUN apk add --no-cache graphviz fontconfig ttf-dejavu font-noto-cjk && \
    adduser -D -u 10001 mcp

# Noto Serif CJK JP (mincho) is not packaged in Alpine; fetch from the
# official notofonts repository, pinned to a release tag (SIL OFL 1.1).
ARG NOTO_SERIF_CJK_TAG=Serif2.002
ADD https://github.com/notofonts/noto-cjk/raw/${NOTO_SERIF_CJK_TAG}/Serif/OTF/Japanese/NotoSerifCJKjp-Regular.otf /usr/share/fonts/noto-serif-cjk/
ADD https://github.com/notofonts/noto-cjk/raw/${NOTO_SERIF_CJK_TAG}/Serif/OTF/Japanese/NotoSerifCJKjp-Bold.otf /usr/share/fonts/noto-serif-cjk/
RUN chmod 644 /usr/share/fonts/noto-serif-cjk/*.otf && fc-cache -f

COPY --from=mcp-build /build/target/plantuml-mcp.jar /opt/plantuml-mcp/plantuml-mcp.jar

ENV GRAPHVIZ_DOT=/usr/bin/dot
ENV PLANTUML_SECURITY_PROFILE=INTERNET

USER mcp
ENTRYPOINT ["java", "-Djava.awt.headless=true", "-jar", "/opt/plantuml-mcp/plantuml-mcp.jar"]
