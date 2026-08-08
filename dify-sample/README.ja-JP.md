# Dify サンプルDSL: PlantUML MCPサーバー評価用

このフォルダには、Docker MCP Gateway経由でPlantUML MCPサーバーをテストするための [Dify](https://dify.ai/) アプリDSLサンプルが含まれています。

## ファイル

- [plantuml-mit-eval.yml](plantuml-mit-eval.yml) — 英語版DSL：description、オープニングメッセージ、サジェスト質問、Agent指示文がすべて英語（advanced-chat / Chatflowアプリ: `Start → Agent → Answer`）
- [plantuml-mit-eval.ja-JP.yml](plantuml-mit-eval.ja-JP.yml) — 日本語版DSL：ユーザー向けテキストとAgent指示文がすべて日本語の同一アプリ

## 動作内容

このアプリはPlantUML作図アシスタントです。ユーザーが作りたい図を自然言語（日本語）で説明すると、Agentノードが以下を行います。

1. 要望から最適な図の種類を判断する（シーケンス図、クラス図、ユースケース図、アクティビティ図、状態遷移図、コンポーネント図、ER図、ガントチャート、マインドマップ、JSON/YAML可視化など）
2. `@startuml` / `@enduml`（JSONは `@startjson`、mindmapは `@startmindmap`）で囲んだPlantUMLソースを作成する
3. MCPツール `render_png`（既定）または `render_svg`（ユーザーがSVGを明示指定した場合のみ）を呼び出す。レンダリングされた画像は回答に自動添付される
4. レンダリングエラー時は、エラーメッセージ（行番号付き）を読み取ってソースを修正し再実行する。3回失敗した場合はエラー内容とソースを提示してユーザーに確認する

回答本文には説明とレンダリングに使用したPlantUMLソースが含まれますが、Base64画像データやSVGマークアップの書き写しは行いません。

## 前提条件

- Dify **1.7.0以上**（Agentノードが `langgenius/agent` のFunctionCalling戦略を使用）
- **Docker MCP Gateway** の背後で稼働するPlantUML MCPサーバーが、`mcp-gateway` という名前のMCPツールプロバイダーとしてDifyに登録され、`render_png` と `render_svg` ツールが利用可能であること
- LLMプロバイダー — サンプルではOpenRouterプラグイン経由の `anthropic/claude-sonnet-4.6` を使用。Function Calling対応モデルであれば、設定済みの任意のモデルに差し替え可能

## 使い方

1. Difyの **スタジオ → DSLインポート** から `plantuml-mit-eval.yml`（または `plantuml-mit-eval.ja-JP.yml`）を選択する
2. Agentノードを開き、モデルと `render_png` / `render_svg` MCPツールが自動解決されていない場合は再選択する
3. アプリを公開し、サジェスト質問（例：「ユーザーがログインして認証トークンを受け取るまでのシーケンス図を作って」）を試す

## 補足

- PlantUMLサーバーのイメージにはCJKフォント（Noto Sans CJK / Noto Serif CJK JP）が同梱されているため、日本語ラベルも正しくレンダリングされます。明朝体の指定があった場合、エージェントはソース先頭に `skinparam defaultFontName "Noto Serif CJK JP"` を追加します
- PlantUMLソースは100,000文字以内に制限されています
