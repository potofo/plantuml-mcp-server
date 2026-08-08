/*
 * PlantUML MCP Server
 * Copyright (c) 2026 potofo
 *
 * SPDX-License-Identifier: MIT
 * Licensed under the MIT License. See LICENSE.txt in the project root
 * for full license text.
 */
package io.github.potofo.plantumlmcp;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Uses sequence diagrams throughout: PlantUML lays them out natively,
 * so the tests do not depend on Graphviz being installed on the host.
 */
class PlantUmlRendererTest {
    private static final String SEQUENCE = "@startuml\nAlice -> Bob : hello\n@enduml\n";

    private final PlantUmlRenderer renderer = new PlantUmlRenderer();

    @Test
    void rendersSvg() throws Exception {
        String svg = renderer.renderSvg(SEQUENCE);
        assertTrue(svg.contains("<svg"), "expected an <svg> root element");
        assertTrue(svg.contains("hello"), "expected the message label in the output");
    }

    @Test
    void rendersPng() throws Exception {
        byte[] png = renderer.renderPng(SEQUENCE);
        assertTrue(png.length > 8, "expected non-trivial PNG output");
        assertEquals((byte) 0x89, png[0]);
        assertEquals('P', png[1]);
        assertEquals('N', png[2]);
        assertEquals('G', png[3]);
    }

    @Test
    void rejectsBlankSource() {
        assertThrows(IllegalArgumentException.class, () -> renderer.renderSvg("   "));
    }

    @Test
    void rejectsOversizedSource() {
        String big = "@startuml\n" + "'comment\n".repeat(20_000) + "@enduml\n";
        IllegalArgumentException e = assertThrows(
            IllegalArgumentException.class, () -> renderer.renderSvg(big));
        assertTrue(e.getMessage().contains("exceeds"));
    }

    @Test
    void rejectsSourceWithoutDiagram() {
        assertThrows(IllegalArgumentException.class,
            () -> renderer.renderSvg("just some text"));
    }

    @Test
    void reportsSyntaxErrors() {
        String bad = "@startuml\nthis is not valid plantuml at all\n@enduml\n";
        IllegalArgumentException e = assertThrows(
            IllegalArgumentException.class, () -> renderer.renderSvg(bad));
        assertTrue(e.getMessage().contains("syntax error"),
            "unexpected message: " + e.getMessage());
    }

    @Test
    void rendersConcurrentRequests() throws Exception {
        // Regression test: concurrent first renders used to deadlock inside
        // the PlantUML core; renders are now serialized by the renderer.
        var executor = java.util.concurrent.Executors.newFixedThreadPool(4);
        try {
            var futures = new java.util.ArrayList<java.util.concurrent.Future<String>>();
            for (int i = 0; i < 4; i++) {
                futures.add(executor.submit(() -> renderer.renderSvg(SEQUENCE)));
            }
            for (var future : futures) {
                String svg = future.get(90, java.util.concurrent.TimeUnit.SECONDS);
                assertTrue(svg.contains("<svg"));
            }
        } finally {
            executor.shutdownNow();
        }
    }

    @Test
    void rejectsMultipleDiagramBlocks() {
        String two = SEQUENCE + SEQUENCE;
        IllegalArgumentException e = assertThrows(
            IllegalArgumentException.class, () -> renderer.renderSvg(two));
        assertTrue(e.getMessage().contains("exactly one"),
            "unexpected message: " + e.getMessage());
    }
}
