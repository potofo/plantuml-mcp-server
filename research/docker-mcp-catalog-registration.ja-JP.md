# このプロジェクトを Docker MCP Catalog に登録する手順

PlantUML MCP Server を Docker MCP Catalog に登録する手順をまとめます。
ルートは 2 つあります。

- **ルート A: 公式 Docker MCP Catalog** —
  [docker/mcp-registry](https://github.com/docker/mcp-registry) への
  pull request で contribution する。全ユーザーの Docker Desktop
  MCP Toolkit / Docker Hub に掲載される。
- **ルート B: カスタムカタログ** — 自分の Docker MCP Gateway に
  カタログファイルを import する。自分/自組織のプライベート利用で、
  審査プロセスなし。

> **ルート A のライセンス要件: 充足済み**
> 公式レジストリは「consume できるライセンスであること (MIT or Apache 2
> are great, GPL is not)」を要件としています。本プロジェクトは MIT
> ライセンスです。レンダリングは MIT ライセンス版の
> `net.sourceforge.plantuml:plantuml-mit` による in-process 実行で、
> イメージに GPL-3.0 の `plantuml/plantuml-server` は含まれません。
> Graphviz（EPL-1.0）は独立した外部プログラムとしての同梱のみで、
> プロジェクトのライセンスには影響しません。したがって Docker 側ビルド
> （レジストリの Option A）での提出が可能です。

## 前提条件（両ルート共通）

1. **公開 GitHub リポジトリ** — 本プロジェクトを public な GitHub
   リポジトリに push すること。`Dockerfile` はリポジトリルートに必要
   （現在のレイアウトで満たしています）。[`server.yaml`](../server.yaml)
   の `source.project` を実際の URL に差し替えてください。
2. **publish 済み OCI イメージ**（ルート B、またはルート A で自前ビルド
   イメージを使う場合。推奨の Docker 側ビルドによるルート A ではこの
   手順は不要）— **リリースワークフローで自動化済み**
   （[`.github/workflows/release.yml`](../.github/workflows/release.yml)）。
   `v*` タグを push すると、マルチアーチ（amd64/arm64）イメージのビルド、
   `ghcr.io/<owner>/plantuml-mcp-server` への push、digest 固定済み
   `catalog.yaml` の GitHub Release への添付まで自動で行われます：

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. **ライセンス整備** — `LICENSE.txt`（MIT）、全ソースファイルの SPDX
   ヘッダー、README の License セクション（plantuml-mit / MCP Java SDK /
   Graphviz のサードパーティ表示を含む）は整備済みです。

## ルート A: 公式 Docker MCP Catalog（docker/mcp-registry）

### A-1. ツールの準備

- Go v1.24+
- [Task](https://taskfile.dev)
- Docker が使えるマシンへのアクセス — レジストリのツール（`task wizard` /
  `task build` / `task catalog`）はコンテナのビルド・実行を行います。
  Docker MCP Gateway が既に動いている Linux サーバで十分で、Docker
  Desktop は選択肢の 1 つにすぎません。Windows の開発マシン自体に
  必要なのは JDK + Maven だけです。

補足: リリースの publish にはローカルの Docker は一切不要です —
GitHub Actions のリリースワークフローがイメージのビルドと push を
行います。

### A-2. レジストリを fork & clone

```bash
gh repo fork docker/mcp-registry --clone
cd mcp-registry
```

### A-3. サーバーエントリの生成

対話式ウィザード（推奨 — GitHub リポジトリの Dockerfile を解析して
デフォルト値を埋めてくれます）：

```bash
task wizard
```

または非対話で実行します。本プロジェクトは MIT ライセンスなので、
Docker 側でビルドして `mcp/` namespace でホスティングしてもらう
（署名・SBOM・自動セキュリティ更新付き）のが推奨です：

```bash
task create -- --category productivity \
  https://github.com/<you>/plantuml-mcp-server
```

自前ビルドのイメージを使いたい場合は
`--image <your-registry>/plantuml-mcp:0.1.0` を追加します。

これでレジストリ側リポジトリに `servers/plantuml/server.yaml` が
作られます。本リポジトリの [`server.yaml`](../server.yaml) はすでに
要求フォーマット（`meta` / `about` / `source` ブロック）で書かれて
いるので、そのエントリの下敷きにできます。

### A-4. ローカルでのテスト

```bash
task build -- --tools plantuml        # イメージを build し、ツール一覧 (render_svg / render_png) を検証
task catalog -- plantuml              # ローカルカタログを生成
docker mcp catalog import $PWD/catalogs/plantuml/catalog.yaml
```

PlantUML サーバーを有効化してテストのツール呼び出しを実行します —
`docker mcp` CLI（`docker mcp server enable plantuml` のうえで
`docker mcp gateway run` 経由のツール呼び出し）、または Docker Desktop
利用時は MCP Toolkit の UI から行います。終わったら元に戻します：

```bash
docker mcp catalog reset
```

### A-5. Pull request の提出

1. ライセンス要件を確認する（冒頭のライセンス注記参照 — MIT で充足済み）。
2. `docker/mcp-registry` に対して分かりやすいタイトルで PR を出す
   （コミットは squash され、PR タイトルがコミットメッセージになります）。
3. CI を通す。
4. 審査に認証情報が必要なサーバーは PR テンプレートの Google Form で
   提出する（本サーバーは不要）。
5. Docker チームのレビューを待つ。

### A-6. マージ後

承認から 24 時間以内に、MCP catalog・Docker Desktop の MCP Toolkit・
（Docker ビルドイメージの場合）Docker Hub `mcp` namespace に反映されます。

## ルート B: カスタムカタログ（プライベート利用）

審査プロセスがないため、ルート A 提出前の動作確認や、自組織内だけで
使いたい場合に有用です。

1. リリースタグを push し（前提条件参照）、GitHub Release に添付された
   digest 固定済み `catalog.yaml` をダウンロードする。リリースワーク
   フローが自動生成するもので、意図的にリポジトリには置いていないため、
   手で編集するものはありません。
2. カタログを import する：

   ```bash
   docker mcp catalog import /path/to/plantuml-mcp-server/catalog.yaml
   ```

3. そのマシンの `docker mcp` CLI でサーバーを有効化して
   `docker mcp gateway run` を起動し（Docker Desktop 利用時は
   MCP Toolkit の UI でも可）、MCP クライアント（VS Code、
   Claude Desktop など）を接続する。リモートサーバ構成の詳細は
   [windows-build-remote-gateway-test.ja-JP.md](windows-build-remote-gateway-test.ja-JP.md)
   を参照。
4. 削除する場合：

   ```bash
   docker mcp catalog reset
   ```

## 本リポジトリのファイル対応表

| ファイル | 役割 |
| --- | --- |
| [`server.yaml`](../server.yaml) | docker/mcp-registry 形式のエントリ（ルート A） |
| `catalog.yaml` | リポジトリには非配置 — リリースごとに digest 固定で自動生成され GitHub Release に添付（ルート B） |
| [`.github/workflows/release.yml`](../.github/workflows/release.yml) | タグ駆動リリース: マルチアーチビルド、GHCR push、catalog.yaml 生成 |
| [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | push/PR 時のビルド＋レンダリングスモークテスト |
| [`.github/dependabot.yml`](../.github/dependabot.yml) | 自動更新 PR（plantuml-mit、ベースイメージ、actions） |
| [`Dockerfile`](../Dockerfile) | リポジトリルートに必須（ルート A の要件） |
| [`LICENSE.txt`](../LICENSE.txt) | MIT ライセンス全文 |
| [`LICENSE_NOTES.md`](../LICENSE_NOTES.md) | ライセンスのチェックリスト |

## 提出前の残 TODO

- [ ] 本プロジェクトを `https://github.com/potofo/plantuml-mcp-server`
      （public）に push する — `server.yaml` の `source.project` は
      設定済み
- [x] イメージ publish — リリースワークフローで自動化済み（タグ push）
- [x] リリースイメージの digest 固定 — 自動生成される `catalog.yaml` が
      digest 参照
- [ ] 初回リリース後: GHCR パッケージの可視性を public に設定する

---

*出典:
[docker/mcp-registry CONTRIBUTING.md](https://github.com/docker/mcp-registry/blob/main/CONTRIBUTING.md)、
[docker/mcp-registry README](https://github.com/docker/mcp-registry)。
2026-08-08 時点で確認。*
