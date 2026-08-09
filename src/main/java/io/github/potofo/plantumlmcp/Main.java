/*
 * PlantUML MCP Server
 * Copyright (c) 2026 potofo
 *
 * SPDX-License-Identifier: MIT
 * Licensed under the MIT License. See LICENSE.txt in the project root
 * for full license text.
 */
package io.github.potofo.plantumlmcp;

import io.modelcontextprotocol.json.McpJsonDefaults;
import io.modelcontextprotocol.server.McpServer;
import io.modelcontextprotocol.server.McpSyncServer;
import io.modelcontextprotocol.server.transport.StdioServerTransportProvider;
import io.modelcontextprotocol.spec.McpSchema;
import io.modelcontextprotocol.spec.McpSchema.CallToolResult;
import io.modelcontextprotocol.spec.McpSchema.ServerCapabilities;
import io.modelcontextprotocol.spec.McpSchema.Tool;

import java.util.Base64;
import java.util.List;
import java.util.Map;

public final class Main {
    private static final String SOURCE_SCHEMA = """
        {
          "type": "object",
          "properties": {
            "source": {
              "type": "string",
              "description": "PlantUML source text"
            }
          },
          "required": ["source"],
          "additionalProperties": false
        }
        """;

    public static void main(String[] args) {
        PlantUmlRenderer plantUml = new PlantUmlRenderer();
        var transport = new StdioServerTransportProvider(McpJsonDefaults.getMapper());

        // Advertise the exact renderer version so the calling LLM writes
        // syntax valid for this PlantUML release, not for whatever version
        // dominates its training data.
        String plantUmlVersion = net.sourceforge.plantuml.version.Version.versionString();

        Tool svgTool = Tool.builder("render_svg", McpJsonDefaults.getMapper(), SOURCE_SCHEMA)
            .description("Render PlantUML source as a downloadable SVG file (with an "
                + "inline PNG preview). Use ONLY when the user explicitly asks for "
                + "SVG format. To show a diagram to the user, use render_png "
                + "instead. Renderer: PlantUML " + plantUmlVersion
                + " (MIT build; ditaa and LaTeX math unavailable); write syntax "
                + "compatible with this version.")
            .build();

        Tool pngTool = Tool.builder("render_png", McpJsonDefaults.getMapper(), SOURCE_SCHEMA)
            .description("Render PlantUML source as a PNG image. Preferred tool for "
                + "displaying diagrams: the resulting image is shown to the user "
                + "automatically. Renderer: PlantUML " + plantUmlVersion
                + " (MIT build; ditaa and LaTeX math unavailable); write syntax "
                + "compatible with this version.")
            .build();

        McpSyncServer server = McpServer.sync(transport)
            .serverInfo("plantuml-mcp", "0.1.0")
            .capabilities(ServerCapabilities.builder().tools(true).build())
            .toolCall(svgTool, (exchange, request) -> {
                try {
                    String source = requireSource(request.arguments());
                    String svg = plantUml.renderSvg(source);
                    String pngBase64 = Base64.getEncoder()
                        .encodeToString(plantUml.renderPng(source));
                    // Three content items, tuned for multi-client delivery through
                    // the gateway (clientInfo cannot be used to branch — the
                    // gateway reconnects upstream with its own identity):
                    //  1. SVG as an embedded blob resource — becomes a downloadable
                    //     file on platforms that map blobs to files (e.g. Dify).
                    //     Deliberately NOT inlined as text: it would waste
                    //     thousands of tokens in the calling LLM's context.
                    //  2. PNG preview as image content — platforms that discard
                    //     blob resources (e.g. LibreChat) still display the
                    //     diagram inline. Never send SVG as type "image": LLM
                    //     providers reject image/svg+xml payloads.
                    //  3. Status text that must not claim an attachment exists —
                    //     clients that drop the blob would otherwise lead the
                    //     model to fabricate download links.
                    String blob = Base64.getEncoder().encodeToString(
                        svg.getBytes(java.nio.charset.StandardCharsets.UTF_8));
                    var resource = new McpSchema.BlobResourceContents(
                        "file:///diagram.svg", "image/svg+xml", blob);
                    return CallToolResult.builder()
                        .content(List.of(
                            new McpSchema.EmbeddedResource(null, resource),
                            new McpSchema.ImageContent(null, pngBase64, "image/png"),
                            new McpSchema.TextContent(
                                "PlantUML diagram rendered. A PNG preview is included "
                                    + "inline. On some clients the SVG also appears as "
                                    + "a downloadable file, but not on all - do not "
                                    + "claim an SVG file is available unless the user "
                                    + "confirms they can see it, and do not create or "
                                    + "fabricate download links for the SVG.")))
                        .build();
                } catch (Exception e) {
                    System.err.println("render_svg failed: " + e.getMessage());
                    return CallToolResult.builder()
                        .isError(true)
                        .content(List.of(new McpSchema.TextContent(
                            "PlantUML render failed: " + e.getMessage())))
                        .build();
                }
            })
            .toolCall(pngTool, (exchange, request) -> {
                try {
                    String source = requireSource(request.arguments());
                    String base64 = Base64.getEncoder().encodeToString(plantUml.renderPng(source));
                    return CallToolResult.builder()
                        .content(List.of(new McpSchema.ImageContent(null, base64, "image/png")))
                        .build();
                } catch (Exception e) {
                    System.err.println("render_png failed: " + e.getMessage());
                    return CallToolResult.builder()
                        .isError(true)
                        .content(List.of(new McpSchema.TextContent(
                            "PlantUML render failed: " + e.getMessage())))
                        .build();
                }
            })
            .build();

        Runtime.getRuntime().addShutdownHook(new Thread(server::closeGracefully));

        try {
            Thread.currentThread().join();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private static String requireSource(Map<String, Object> args) {
        Object value = args.get("source");
        if (!(value instanceof String source) || source.isBlank()) {
            throw new IllegalArgumentException("source must be a non-empty string");
        }
        return source;
    }
}
