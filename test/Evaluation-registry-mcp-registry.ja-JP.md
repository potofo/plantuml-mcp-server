# Docker MCP Registry 登録適性評価

> Docker MCP Registry(公式カタログ・Docker側ビルド提出)への登録適性に
> ついての `plantuml-mcp-server` の客観評価。観点別と総評をそれぞれ
> 100点満点で採点。
> 英語版: [Evaluation-registry-mcp-registry.md](Evaluation-registry-mcp-registry.md)
>
> 評価時点: 2026-08-09(ブランチ `fix/registry-review-items`、PR #9、コミット `613360d`)

## 総評: 90 / 100

公式カタログへの提出は現時点で可能です。MITライセンス戦略、コンテナ
エンジニアリング、要件IDにトレースされたテストスイートは、レジストリ
掲載エントリの一般的な水準を上回っています。残る差分はリリースの実行
のみ — PR #9 が未マージで `v0.1.0` タグも未実施のため、タグ駆動の
リリースワークフロー(マルチアーチGHCR push、digest固定 `catalog.yaml`)
が未実証です。初回リリースを完了すれば総評はおよそ93点に上がります。

## 観点別採点

| # | 観点 | 点数 | 根拠 |
|---|---|---:|---|
| 1 | ライセンス適合性 | 95 | MIT本体+`plantuml-mit`、Graphviz(EPL-1.0)は外部サブプロセスとして分離、全ソースにSPDXヘッダ、サードパーティ表示と`LICENSE_NOTES.md`のチェックリスト。レジストリの「MIT or Apache 2, not GPL」要件への模範解答。 |
| 2 | レジストリ要件適合 | 92 | `server.yaml`は必須フィールドを完備、Dockerfileはルート配置、公開GitHubリポジトリ、descriptionでPlantUMLプロジェクト非公認を明示。残リスクは`plantuml`という名前・アイコンがDockerレビューで改名要求を受ける可能性。 |
| 3 | コンテナ品質・セキュリティ | 90 | マルチステージビルド、Alpine JRE、非root(uid 10001)、フォント取得元のタグ固定、`PLANTUML_SECURITY_PROFILE=INTERNET`のトレードオフを文書化(ローカルファイル読取不可・`SANDBOX`への切替手順あり)、100,000文字/60秒のレンダリング上限。ベースイメージはタグ固定でdigest固定ではない(dependabotで補完)。 |
| 4 | MCP実装品質 | 90 | トークン効率を意識した応答設計(SVGは埋め込みリソース、PNGは画像コンテンツ)、ツールdescriptionでレンダラーバージョンを明示、空・過大・複数ブロック・構文エラーへの明示的エラー、キャンセル可能なワーカーでのタイムアウト、実際に発見した並行レンダリングのデッドロックを直列化で修正。直列化により同時レンダリングは1件ずつになるが、ゲートウェイ用途では許容範囲。 |
| 5 | CI/CD・リリース工学 | 92 | CI: push/PRごとにMavenビルド+ユニットテスト+イメージビルド+EARS受け入れスイート(グリーン実証済み)。タグ駆動リリース: マルチアーチビルド、GHCR push、digest固定カタログ生成 — 設計は良いが未実行。 |
| 6 | テスト | 89 | JUnitテスト8件(レンダリング・入力検証・並行性リグレッション)+ 全EARS要件IDをTAPチェックにトレースする23項目の受け入れスイートを、実イメージに対し`--network none`でCI実行。結果は`test/RESULTS.md`とCIアーティファクト`test-results`で追跡可能。自動化対象外: 60秒タイムアウト経路(設計レビューで検証)とマルチアーチ検証(リリース実行に委譲)。 |
| 7 | ドキュメント | 93 | 英日のREADME・要件書、アーキテクチャ図、セキュリティセクション、設計・ライセンスノート、ローカル/WSL/リモートのテスト手順と登録手順自体の調査ノート、Dify連携サンプル(`dify-sample/`)、再実行可能な評価プロンプト。 |
| 8 | 公開準備状況 | 75 | リポジトリ公開、CIグリーン、メタデータ設定、dependabot整理済み。未了: PR #9のマージ、`v0.1.0`タグ、リリースワークフローの実証、GHCRパッケージのpublic化。 |

## 判定

**登録可能。** 公式カタログ(Docker側ビルド)への提出PRは、PR #9の
マージ後すぐに `docker/mcp-registry` へ出せます。マルチアーチビルドの
実証とレビュアーが動かせる参照イメージの提供のため、先に `v0.1.0`
リリースを完了させることを強く推奨します。

## 根拠

- 受け入れスイート: [`test/acceptance-test.sh`](acceptance-test.sh)、
  要件書 [`test/ACCEPTANCE.ja-JP.md`](ACCEPTANCE.ja-JP.md)、直近結果
  [`test/RESULTS.md`](RESULTS.md) — 21 passed / 0 failed /
  2 skipped(設計どおり)。
- CI実行: `main` と PR #9 の `CI` ワークフロー(ビルド+テスト+受け入れ)。
  各実行はTAP出力と`RESULTS.md`をアーティファクト`test-results`として保存。
- 参照したレジストリ規約:
  [docker/mcp-registry CONTRIBUTING.md](https://github.com/docker/mcp-registry/blob/main/CONTRIBUTING.md)。
