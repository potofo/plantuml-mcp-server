/*
 * PlantUML MCP Server
 * Copyright (c) 2026 potofo
 *
 * SPDX-License-Identifier: MIT
 * Licensed under the MIT License. See LICENSE.txt in the project root
 * for full license text.
 */
package io.github.potofo.plantumlmcp;

import net.sourceforge.plantuml.BlockUml;
import net.sourceforge.plantuml.FileFormat;
import net.sourceforge.plantuml.FileFormatOption;
import net.sourceforge.plantuml.SourceStringReader;
import net.sourceforge.plantuml.core.Diagram;
import net.sourceforge.plantuml.error.PSystemError;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.locks.ReentrantLock;
import java.util.stream.Collectors;

/**
 * Renders PlantUML source in-process via the PlantUML core API
 * (MIT-licensed {@code plantuml-mit} artifact). Layout for class,
 * component, state and similar diagrams is delegated to Graphviz,
 * which PlantUML invokes as an external {@code dot} process.
 */
final class PlantUmlRenderer {
    private static final int MAX_SOURCE_LENGTH = 100_000;
    private static final int RENDER_TIMEOUT_SECONDS = 60;

    // Daemon threads: a runaway render must never block JVM shutdown.
    private final ExecutorService executor = Executors.newCachedThreadPool(runnable -> {
        Thread thread = new Thread(runnable, "plantuml-render");
        thread.setDaemon(true);
        return thread;
    });

    // The PlantUML core is not safe under concurrent rendering (concurrent
    // first renders deadlock in its static/font initialization), so renders
    // are serialized. Fair + interruptible: queued tasks keep FIFO order and
    // can still be cancelled by the per-request timeout while waiting.
    private final ReentrantLock renderLock = new ReentrantLock(true);

    String renderSvg(String source) throws IOException {
        return new String(render(source, FileFormat.SVG), StandardCharsets.UTF_8);
    }

    byte[] renderPng(String source) throws IOException {
        return render(source, FileFormat.PNG);
    }

    private byte[] render(String source, FileFormat format) throws IOException {
        if (source == null || source.isBlank()) {
            throw new IllegalArgumentException("source must not be blank");
        }
        if (source.length() > MAX_SOURCE_LENGTH) {
            throw new IllegalArgumentException(
                "source exceeds " + MAX_SOURCE_LENGTH + " characters");
        }

        // Parsing and layout (including the external Graphviz process) run on
        // a worker thread so a pathological diagram cannot hang the server.
        Future<byte[]> task = executor.submit(() -> doRender(source, format));
        try {
            return task.get(RENDER_TIMEOUT_SECONDS, TimeUnit.SECONDS);
        } catch (TimeoutException e) {
            task.cancel(true);
            throw new IOException(
                "rendering timed out after " + RENDER_TIMEOUT_SECONDS + " seconds");
        } catch (InterruptedException e) {
            task.cancel(true);
            Thread.currentThread().interrupt();
            throw new IOException("rendering was interrupted");
        } catch (ExecutionException e) {
            Throwable cause = e.getCause();
            if (cause instanceof IOException io) {
                throw io;
            }
            if (cause instanceof RuntimeException runtime) {
                throw runtime;
            }
            throw new IOException(cause);
        }
    }

    private byte[] doRender(String source, FileFormat format)
            throws IOException, InterruptedException {
        renderLock.lockInterruptibly();
        try {
            return doRenderLocked(source, format);
        } finally {
            renderLock.unlock();
        }
    }

    private byte[] doRenderLocked(String source, FileFormat format) throws IOException {
        SourceStringReader reader = new SourceStringReader(source);
        List<BlockUml> blocks = reader.getBlocks();
        if (blocks.isEmpty()) {
            throw new IllegalArgumentException(
                "no diagram found (missing @startuml/@enduml?)");
        }
        if (blocks.size() > 1) {
            throw new IllegalArgumentException(
                "source contains " + blocks.size() + " diagrams; send exactly one "
                    + "@startuml/@enduml block per call");
        }

        Diagram diagram = blocks.get(0).getDiagram();
        if (diagram instanceof PSystemError error) {
            String messages = error.getErrorsUml().stream()
                .map(e -> e.getError() + " (line " + (e.getPosition() + 1) + ")")
                .distinct()
                .collect(Collectors.joining("; "));
            throw new IllegalArgumentException("PlantUML syntax error: " + messages);
        }

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        diagram.exportDiagram(out, 0, new FileFormatOption(format));
        return out.toByteArray();
    }
}
