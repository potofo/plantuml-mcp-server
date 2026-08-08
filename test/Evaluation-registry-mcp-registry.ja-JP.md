# Docker MCP Registry 登録適性評価

> Docker MCP Registry(公式カタログ・Docker側ビルド提出)への登録適性に
> ついての `plantuml-mcp-server` の客観評価。観点別と総評をそれぞれ
> 100点満点で採点。
> 英語版: [Evaluation-registry-mcp-registry.md](Evaluation-registry-mcp-registry.md)
>
> 評価時点: 2026-08-09(main `7778c50`、リリース `v0.1.0` 公開済み)

## 総評: 93 / 100

提出の前提条件はすべて満たし、かつ実証済みになりました。リポジトリは
公開済みでCIグリーン、`v0.1.0` リリースはエンドツーエンドで成功
(マルチアーチ amd64/arm64 イメージをGHCRへpush、digest固定
`catalog.yaml` をGitHub Releaseに添付)、GHCRパッケージは匿名pull可能
(public)です。リリースパイプラインは初回実行が実欠陥(amd64のみの
`17-jre-alpine` ベース)で失敗し、同一サイクル内で診断・修正・検証を
完了したことで、むしろ信頼性の裏付けが増しました。残る減点は未了作業
ではなく固有リスクです: `plantuml` という名前・アイコンがDockerレビューで
改名要求を受ける可能性、およびレンダリングが設計上直列であること。

## 観点別採点

| # | 観点 | 点数 | 根拠 |
|---|---|---:|---|
| 1 | ライセンス適合性 | 95 | MIT本体+`plantuml-mit`、Graphviz(EPL-1.0)は外部サブプロセスとして分離、全ソースにSPDXヘッダ、サードパーティ表示と`LICENSE_NOTES.md`のチェックリスト。レジストリの「MIT or Apache 2, not GPL」要件への模範解答。 |
| 2 | レジストリ要件適合 | 92 | `server.yaml`は必須フィールドを完備、Dockerfileはルート配置、公開GitHubリポジトリ、descriptionでPlantUMLプロジェクト非公認を明示。残リスクは`plantuml`という名前・アイコンがDockerレビューで改名要求を受ける可能性。 |
| 3 | コンテナ品質・セキュリティ | 90 | マルチステージビルド、Alpine JRE 21ランタイム(Java 17バイトコード)、非root(uid 10001)、フォント取得元のタグ固定、`PLANTUML_SECURITY_PROFILE=INTERNET`のトレードオフを文書化(ローカルファイル読取不可・`SANDBOX`への切替手順あり)、100,000文字/60秒のレンダリング上限。ベースイメージはタグ固定でdigest固定ではない(dependabotで補完)。 |
| 4 | MCP実装品質 | 90 | トークン効率を意識した応答設計(SVGは埋め込みリソース、PNGは画像コンテンツ)、ツールdescriptionでレンダラーバージョンを明示、空・過大・複数ブロック・構文エラーへの明示的エラー、キャンセル可能なワーカーでのタイムアウト、実際に発見した並行レンダリングのデッドロックを直列化で修正。直列化により同時レンダリングは1件ずつになるが、ゲートウェイ用途では許容範囲。 |
| 5 | CI/CD・リリース工学 | 95 | CI: push/PRごとにMavenビルド+ユニットテスト+イメージビルド+EARS受け入れスイート、結果をアーティファクトとして保存。リリース: タグ駆動のマルチアーチビルド、GHCR push、digest固定カタログ — **公開済み`v0.1.0`で実証済み**。初回失敗→診断→修正→検証のサイクルも同日内に完了。 |
| 6 | テスト | 90 | JUnitテスト8件(レンダリング・入力検証・並行性リグレッション)+ 全EARS要件IDをTAPチェックにトレースする23項目の受け入れスイートを、実イメージに対し`--network none`でCI実行。結果は`test/RESULTS.md`とCIアーティファクト`test-results`で追跡可能。REQ-CAT-007(マルチアーチ・digest固定リリース)は実リリースで検証完了。自動化対象外は60秒タイムアウト経路のみ(設計レビューで検証)。 |
| 7 | ドキュメント | 93 | 英日のREADME・要件書、アーキテクチャ図、セキュリティセクション、設計・ライセンスノート、ローカル/WSL/リモートのテスト手順と登録手順自体の調査ノート、Dify連携サンプル(`dify-sample/`)、再実行可能な評価プロンプト。 |
| 8 | 公開準備状況 | 95 | `v0.1.0` 公開済み: `ghcr.io/potofo/plantuml-mcp-server` のマルチアーチイメージ(manifestでamd64+arm64を確認)、digest固定`catalog.yaml`をGitHub Releaseに添付、匿名pull可能(パッケージはpublic)を確認。薄いのはリリース実績が1回のみという点だけ。 |

## 判定

**登録可能 — 提出できる状態。** 公式カタログ(Docker側ビルド)の前提
条件はすべて充足。次の具体的アクションは提出そのものです:
`docker/mcp-registry` をfork →
`task create -- --category productivity https://github.com/potofo/plantuml-mcp-server`
でエントリ生成 → `task build` / `task catalog` でローカルテスト → PR提出。
ルートB(カスタムカタログ)はリリース添付の `catalog.yaml` で即時利用可能です。

## 根拠

- リリース実行: タグ `v0.1.0` の `Release` ワークフローが全ステップ成功
  (マルチアーチのビルド&push、カタログ生成、GitHub Release作成)。
- イメージ: `ghcr.io/potofo/plantuml-mcp-server:0.1.0` — manifestに
  amd64+arm64、匿名のレジストリpullがHTTP 200(public)。
- 受け入れスイート: [`test/acceptance-test.sh`](acceptance-test.sh)、
  要件書 [`test/ACCEPTANCE.ja-JP.md`](ACCEPTANCE.ja-JP.md)、直近結果
  [`test/RESULTS.md`](RESULTS.md) — 21 passed / 0 failed / 2 skipped
  (設計どおり)。
- CI実行: `main` と全マージ済みPRで `CI` ワークフローがグリーン。各実行は
  TAP出力と`RESULTS.md`をアーティファクト`test-results`として保存。
- 参照したレジストリ規約:
  [docker/mcp-registry CONTRIBUTING.md](https://github.com/docker/mcp-registry/blob/main/CONTRIBUTING.md)。
