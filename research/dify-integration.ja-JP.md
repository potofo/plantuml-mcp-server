# Dify から PlantUML MCP Server を使う手順（連携ガイド）

Dify のエージェントから Docker MCP Gateway 経由で PlantUML MCP Server を
呼び出し、チャットに図を画像表示・ファイルダウンロードさせるまでの
構成と、実際にハマったポイントをまとめます（2026-08-09 実証済み）。

```text
Dify (Agent / FunctionCalling)
  |
  | Streamable HTTP (+ Bearer token)
  v
nginx (Origin 除去リバースプロキシ)
  |
  v
docker/mcp-gateway (docker-compose)
  |
  | stdio (コンテナ起動: --pull never)
  v
plantuml-mcp:dev コンテナ
```

## 1. MCP サーバー側のレスポンス設計（重要）

Dify での見え方はツールが返す MCP コンテンツ型で決まります。

| ツール | 返却型 | Dify での見え方 |
| --- | --- | --- |
| `render_png` | `ImageContent`（Base64 + `image/png`） | `files` に変換され、チャットにインライン画像表示＋ダウンロード |
| `render_svg` | `EmbeddedResource`（`image/svg+xml` の blob）＋短いステータステキスト | `files` に変換され、ファイルとして添付 |

設計上のポイント：

- **`TextContent` で画像データを返さない。** Base64 文字列のテキストは
  Dify ではただの文字列で、LLM が本文に書き写す事故（表示崩れ＋
  トークン浪費）の温床になります。
- **SVG 全文もテキストで返さない。** ツールレスポンスは LLM の
  コンテキストに注入されるため、大きな図で 25,000 トークン超の浪費が
  実測されました。blob（ファイル）で返せば LLM には短いステータス
  1 行だけが渡ります。
- **ツールの description で LLM を誘導する。** description はどの
  エージェント戦略でも必ず LLM に渡るため、INSTRUCTION より確実に
  効きます。本サーバーでは render_png に「Preferred tool for
  displaying diagrams」、render_svg に「Use ONLY when the user
  explicitly asks for SVG format」と記述しています。
- **レンダラーのバージョンを description で広告する。** LLM は学習
  データ内で多数派の PlantUML 構文を書きがちで、実レンダラーの
  バージョンと乖離すると構文エラーの原因になります。本サーバーは
  起動時に `Version.versionString()` から実バージョンを取得し、
  「Renderer: PlantUML 1.2026.6 (MIT build; ditaa and LaTeX math
  unavailable); write syntax compatible with this version.」を両ツールの
  description に自動で埋め込みます（jar 更新に自動追従。手書きの
  INSTRUCTION と違い記述がズレない）。構文エラー時は行番号付きで
  返して LLM に自己修正させるループも併用します。

## 2. Dify 側のセットアップ

1. **MCP プロバイダー登録** — ゲートウェイの URL（例:
   `http://<host>:8080/mcp`）と Bearer トークンを設定
2. **エージェントノード**
   - 戦略: **Agent > FunctionCalling**（標準）を使う。
     `EnhanceFunctionCalling` は独自のタスク分解プロンプトを注入する
     ため、INSTRUCTION と競合してツール選択が不安定になった
   - モデル: **ツール呼び出しに強い現行世代を固定**（Claude Sonnet 4.5+
     で安定動作を確認）。gpt-4o は「ツールを呼ばずソースだけ書く」
     「宣言だけして終わる」など不安定。AutoRouter はモデルが毎回変わる
     ため検証に不向き
   - ツールボックス: `render_png` / `render_svg` を有効化
3. **回答ノード** — 応答に `Agent {x}text` と `Agent {x}files` を並べる
   （画像・SVG ファイルは `files` 経由で表示される）

## 3. INSTRUCTION（動作確認済みの完成版）

```text
あなたはPlantUMLダイアグラム作成アシスタントです。ユーザーの指示から適切なPlantUMLソースを作成し、必ずツールでレンダリングして結果を返します。

## ツールの使い分け（最重要）
- render_png: 【既定】図を作るときは常にこれを呼ぶ。返された画像は自動的に回答に添付される
- render_svg: ユーザーが「SVGで」と明示的に指定したときだけ使う

## 手順
1. ユーザーの要望から図の種類を判断する（シーケンス図、クラス図、ユースケース図、アクティビティ図、状態遷移図、コンポーネント図、ER図、ガント、mindmap、JSON/YAML可視化など）
2. PlantUMLソースを作成する。必ず @startuml で始め @enduml で終える（JSONは @startjson、mindmapは @startmindmap）
3. 【必須】render_png（SVG明示指定時のみrender_svg）を呼び出す。ソースを書くだけで終わることを禁止する
4. ツールがエラーを返したら、エラーメッセージ（行番号付き）を読んでソースを修正し再実行する。3回失敗したらエラー内容とソースを提示してユーザーに確認する

## 作図ルール
- 図の種類が未指定なら内容から最適な種類を選び、選択理由を一言添える
- 指示が曖昧な部分は常識的に補い、補った箇所を回答で明示する
- ラベルは日本語で構わない（ゴシック=Noto Sans CJK と明朝=Noto Serif CJK JP を同梱）。明朝を求められたら skinparam defaultFontName "Noto Serif CJK JP" をソース先頭に入れる
- ソースは100,000文字以内

## 出力形式
- 回答本文には、説明とレンダリングに使ったPlantUMLソース（```plantuml コードブロック）を含める
- 画像はツール結果から自動で添付されるため、本文への埋め込み（![...](data:...) やBase64の書き写し）を禁止する
- render_svgを使った場合、SVGファイルは自動的に添付される。SVGの中身を本文に書き写すことは禁止する
```

**プロンプト設計の教訓**: ツールの優先順位のような重要な仕様は
**1 箇所だけ**に書くこと。複数箇所に書くと更新漏れで矛盾が生まれ、
高性能モデルほど矛盾に律儀に悩んで誤った側に倒れます（実際に
Sonnet の思考ログで "conflicting instructions" と指摘された）。

## 4. サーバー更新時の反映フロー

MCP サーバーのイメージを更新したら、以下の順で反映が必要です。
どれか 1 つでも欠けると古い挙動・古いツール定義が残ります。

```bash
# 1. サーバに新イメージを load
docker load -i plantuml-mcp-dev.tar.gz

# 2. ゲートウェイ再起動（ツール定義はゲートウェイ起動時にキャッシュされる）
cd /docker/mcp-gateway-compose
docker compose restart mcp-gateway-core
```

3. **Dify のツール再同期** — Dify もツール定義をキャッシュしている
   ため、ツール一覧を再取得する（description の変化で反映を確認できる）

なお、ツール呼び出しごとにコンテナは新規起動される（`longLived: false`）
ため、**挙動そのものは docker load だけで切り替わります**。再起動・
再同期が必要なのはツール定義（名前・説明・スキーマ）の変更時です。

## 5. トラブルシューティング（実際に踏んだもの）

| 症状 | 原因 | 対処 |
| --- | --- | --- |
| SVG/Base64 がテキストのままチャットに出る | ツールが `TextContent` で返している | `ImageContent` / `EmbeddedResource` を返すようサーバーを改修 |
| 画像が壊れたアイコンになる | Dify の `FILES_URL` 設定不備（末尾スラッシュ、api/worker 再起動漏れ、`/files` パスのプロキシ欠落） | まず `FILES_URL` を空に戻して切り分け。設定するなら末尾スラッシュなし＋api/worker 再起動＋リバースプロキシで `/files` を通す |
| LLM がツールを呼ばずソースだけ書いて終わる | モデルのツール実行能力不足（gpt-4o で頻発） | 現行世代モデルに変更。INSTRUCTION に「ソースを書くだけで終わることを禁止」と明記 |
| LLM が意図しない方のツールを選ぶ | INSTRUCTION 内の矛盾（旧記述の残骸）、または EnhanceFunctionCalling の注入プロンプト | 仕様は 1 箇所だけに書く。標準 FunctionCalling 戦略に変更。ツール description でも誘導 |
| LLM が Base64 を本文に書き写す | 「画像を見せなければ」とモデルが判断 | 「自動的に添付される」と役割を明示し、data URI 形式を具体例つきで禁止 |
| ツール説明が古いまま | ゲートウェイ／Dify のキャッシュ | ゲートウェイ再起動＋ Dify ツール再同期（§4） |
| プロンプトトークンが異常に多い | SVG 全文が LLM コンテキストに注入されていた | render_svg を blob 返しに改修（本構成では対処済み） |

## 6. 関連ドキュメント

- [wsl-build-image-transfer-test.ja-JP.md](wsl-build-image-transfer-test.ja-JP.md) — イメージのビルドと転送
- [docker-mcp-catalog-registration.ja-JP.md](docker-mcp-catalog-registration.ja-JP.md) — カタログ登録（本構成はカスタムカタログを docker-compose の `--additional-catalog` で参照する方式）
