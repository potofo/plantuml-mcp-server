# Runbook: docker/mcp-registry への提出手順(ルートA)

**自律型AIエージェント**が `plantuml-mcp-server` を公式 Docker MCP
Catalog に登録するため、[docker/mcp-registry](https://github.com/docker/mcp-registry)
へのpull request作成までを完遂するための手順書です。

作業は**別の作業ディレクトリ**(エージェントがforkした
`docker/mcp-registry` のclone)で行います — **本リポジトリ内では行いません**。
本リポジトリは提出のための読み取り専用の参照資料です。

英語版: [submit-to-docker-mcp-registry.md](submit-to-docker-mcp-registry.md)

## 入力情報

| 項目 | 値 |
| --- | --- |
| ソースリポジトリ | `https://github.com/potofo/plantuml-mcp-server` |
| ライセンス | MIT(`plantuml-mit` 使用、GPL成分なし) |
| サーバー名 | `plantuml`(衝突時のフォールバック: `plantuml-renderer`) |
| カテゴリ | `productivity` |
| ツール(一致必須) | `render_svg`、`render_png` |
| 設定・シークレット | 不要 |
| アイコン | `https://avatars.githubusercontent.com/u/33107703?s=200&v=4` |
| ビルド方式 | Docker側ビルド(Option A: Dockerが `mcp/` namespaceでビルド・ホスト) |
| 参照マニフェスト | ソースリポジトリのルートの [`server.yaml`](../server.yaml) |
| 実証済みリリース | `v0.1.0`(GHCRにマルチアーチ amd64/arm64、digest固定catalog.yaml) |

## 前提条件(開始前に検証)

各チェックを実行し、失敗したら**停止して報告**すること。

```bash
git --version                 # 最近のバージョンであればよい
gh auth status                # 認証済み。forkとPR作成が可能なアカウント
docker version --format '{{.Server.Version}}'   # デーモンに接続可能
go version                    # Go 1.24+
task --version                # Task (taskfile.dev)
```

マシン要件: Docker Engineが動作するLinux(またはWSL2)。
レジストリの `task` ツール群はローカルでコンテナのビルド・実行を行います。

## 手順

### Step 0 — 事前確認

1. ソースリポジトリがpublicでMITライセンスであることを確認:

   ```bash
   gh repo view potofo/plantuml-mcp-server --json visibility,licenseInfo \
     --jq '{visibility, license: .licenseInfo.key}'
   # 期待値: {"visibility":"PUBLIC","license":"mit"}
   ```

2. レジストリで名前が空いていることを確認:

   ```bash
   gh api repos/docker/mcp-registry/contents/servers/plantuml 2>&1 | head -1
   ```

   - HTTP 404 → `plantuml` は空いている。続行。
   - エントリが存在 → **判断ポイント**: 内容を確認する。ソースリポジトリが
     本プロジェクトを指しているなら提出済み(停止して報告)。別プロジェクト
     なら、以降のすべての手順でフォールバック名 `plantuml-renderer` を使う。

### Step 1 — レジストリをforkしてclone

```bash
gh repo fork docker/mcp-registry --clone
cd mcp-registry
git checkout -b add-plantuml
```

fork済みの場合、`gh repo fork` は既存forkを再利用します。先に同期すること:
`gh repo sync <アカウント>/mcp-registry --source docker/mcp-registry`

### Step 2 — サーバーエントリの生成

非対話で生成します(`task wizard` は対話式なので**使わない**):

```bash
task create -- --category productivity https://github.com/potofo/plantuml-mcp-server
```

期待結果: `servers/plantuml/server.yaml` が作成される。ツールはソース
リポジトリのDockerfileと `server.yaml` を読んでデフォルト値を埋めます。

**フォールバック** — `task create` が失敗した場合は、ソースリポジトリ
ルートの参照マニフェストに基づき `servers/plantuml/server.yaml` を
手書きします:

```yaml
name: plantuml
image: mcp/plantuml
type: server
meta:
  category: productivity
  tags:
    - plantuml
    - uml
    - diagrams
about:
  title: PlantUML
  icon: https://avatars.githubusercontent.com/u/33107703?s=200&v=4
  description: >-
    Render PlantUML source to SVG or PNG through Model Context Protocol.
    Community project, not affiliated with or endorsed by the PlantUML project.
source:
  project: https://github.com/potofo/plantuml-mcp-server
```

### Step 3 — 生成されたエントリのレビュー

`servers/plantuml/server.yaml` を入力情報の表と照合する:

- [ ] `name` が `plantuml`(またはフォールバック名)である
- [ ] `meta.category` が `productivity` である
- [ ] `about.description` に非公認である旨の一文が含まれる
- [ ] `about.icon` が設定され、URLが画像を返す
- [ ] `source.project` がソースリポジトリを指している
- [ ] `config` / `secrets` セクションが**ない**(不要のため)

### Step 4 — ローカル検証

```bash
task build -- --tools plantuml
```

期待結果: ソースリポジトリからイメージがビルドされ、検出されたツール
一覧がちょうど `render_svg` と `render_png` になる。ツールが欠けている
場合はコンテナが起動していない — ビルド出力を調査する。

```bash
task catalog -- plantuml
docker mcp catalog import $PWD/catalogs/plantuml/catalog.yaml
```

任意のエンドツーエンド確認: サーバーを有効化しゲートウェイ経由でツールを
呼ぶ(`docker mcp server enable plantuml` → `docker mcp gateway run` →
任意のMCPクライアントから `render_png` を呼び出す)。終わったら後始末:

```bash
docker mcp catalog reset
```

### Step 5 — コミットとpush

差分は `servers/plantuml/` 配下のファイル**のみ**であること。

```bash
git status --short          # servers/plantuml/ 以外に変更がないことを確認
git add servers/plantuml
git commit -m "Add PlantUML MCP server"
git push -u origin add-plantuml
```

### Step 6 — Pull requestの作成

PRタイトルはsquashコミットのメッセージになるため、正確にこの通りにする:

```bash
gh pr create --repo docker/mcp-registry \
  --title "Add PlantUML MCP server" \
  --body-file pr-body.md
```

`pr-body.md` の内容(英語で提出する):

```markdown
## What

Adds the PlantUML MCP server: renders PlantUML source to SVG or PNG over
MCP (stdio), in-process via the MIT-licensed `plantuml-mit` artifact —
no external PlantUML server required. Graphviz (EPL-1.0) is bundled in
the image as a separate external program for diagram layout.

- Source: https://github.com/potofo/plantuml-mcp-server
- License: MIT (`net.sourceforge.plantuml:plantuml-mit`; no GPL components)
- Tools: `render_svg`, `render_png` — no configuration or secrets required
- Docker-built image requested (`mcp/` namespace)
- Multi-arch proven: the v0.1.0 release publishes linux/amd64 + linux/arm64
- Community project; not affiliated with or endorsed by the PlantUML project

## Testing

- `task build -- --tools plantuml` discovers both tools
- `task catalog -- plantuml` + `docker mcp catalog import` verified locally
- The source repo runs an EARS-traced acceptance suite in CI
  (see `test/ACCEPTANCE.md` there)
```

テスト用認証情報のフォーム提出は不要(本サーバーは認証を使わない)。

### Step 7 — 提出後

1. CIを監視: `gh pr checks --repo docker/mcp-registry <PR番号> --watch`。
   失敗は `servers/plantuml/` 配下の修正のみで対応する。
2. Dockerチームのレビューコメントに対応する。想定される指摘:
   PlantUMLのブランドを理由とする**改名要求**。求められたら議論せず、
   ディレクトリと `name:` フィールドを改名(例: `plantuml-renderer`)して
   PRを更新する — フォールバック名はソースプロジェクト側で事前承認済み。
3. 承認・マージ後、約24時間以内にMCP catalog / Docker DesktopのMCP
   Toolkitに反映される。確認方法:
   `docker mcp catalog show | grep -i plantuml`(デフォルトカタログの
   任意のマシンで)。

## ガードレール

- レジストリリポジトリで `servers/plantuml/` の外は**一切変更しない**。
- 認証情報はコミットしない(本提出では一切不要)。
- `docker/mcp-registry` 本体には直接pushしない。pushはfork先のみ。
- 冪等性: 各ステップの前に結果が既に存在するか(fork・ブランチ・
  エントリ・PR)を確認し、重複作成せず再開する。
- 同じ理由で同一ステップが2回失敗したら、生のエラー出力を添えて停止・
  報告する。他のファイルを変更するような即席の回避策は行わない。

## 参照

- [docker/mcp-registry CONTRIBUTING.md](https://github.com/docker/mcp-registry/blob/main/CONTRIBUTING.md)
  (要件の一次情報。提出前に必ず再読すること)
- 本リポジトリ内の調査ノート:
  [research/docker-mcp-catalog-registration.ja-JP.md](../research/docker-mcp-catalog-registration.ja-JP.md)
- 登録適性評価:
  [test/Evaluation-registry-mcp-registry.ja-JP.md](../test/Evaluation-registry-mcp-registry.ja-JP.md)
