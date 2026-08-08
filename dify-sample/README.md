# Dify Sample DSL: PlantUML MCP Server Evaluation

This folder contains a sample [Dify](https://dify.ai/) app DSL for testing the PlantUML MCP server through Docker MCP Gateway.

## Files

- [plantuml-mit-eval.yml](plantuml-mit-eval.yml) — English DSL: description, opening statement, suggested questions, and agent instructions are all in English (an advanced-chat / Chatflow app: `Start → Agent → Answer`)
- [plantuml-mit-eval.ja-JP.yml](plantuml-mit-eval.ja-JP.yml) — Japanese DSL: the same app with all user-facing text and agent instructions in Japanese

Japanese version of this README: [README.ja-JP.md](README.ja-JP.md)

## What it does

The app is a PlantUML diagramming assistant. A user describes the diagram they want in natural language (the sample prompts are in Japanese), and the Agent node:

1. Decides the best diagram type from the request (sequence, class, use case, activity, state, component, ER, Gantt, mind map, JSON/YAML visualization, etc.)
2. Writes PlantUML source wrapped in `@startuml` / `@enduml` (`@startjson`, `@startmindmap` where applicable)
3. Calls the MCP tool `render_png` (default) or `render_svg` (only when the user explicitly asks for SVG); the rendered image is attached to the answer automatically
4. On a rendering error, reads the error message (with line numbers), fixes the source, and retries — up to 3 attempts before asking the user

The answer includes the explanation and the PlantUML source used for rendering, but never inlines Base64 image data or raw SVG markup.

## Prerequisites

- Dify **1.7.0+** (the Agent node uses the `langgenius/agent` FunctionCalling strategy)
- The PlantUML MCP server running behind **Docker MCP Gateway**, registered in Dify as an MCP tool provider named `mcp-gateway`, exposing the `render_png` and `render_svg` tools
- An LLM provider — the sample uses `anthropic/claude-sonnet-4.6` via the OpenRouter plugin; swap in any function-calling-capable model you have configured

## How to use

1. In Dify, go to **Studio → Import DSL** and select `plantuml-mit-eval.yml`
2. Open the Agent node and re-select your model and the `render_png` / `render_svg` MCP tools if they are not resolved automatically
3. Publish the app and try one of the suggested questions, e.g. *"Create a sequence diagram of a user logging in and receiving an auth token"*

## Notes

- CJK fonts (Noto Sans CJK / Noto Serif CJK JP) are bundled in the PlantUML server image, so Japanese labels render correctly; the agent adds `skinparam defaultFontName "Noto Serif CJK JP"` when a serif (Mincho) style is requested
- PlantUML source is limited to 100,000 characters
