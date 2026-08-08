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

さらに、GitHub APIのレート制限を避けるためトークンをexportしておく
(`task create` / `task catalog` はGitHub APIを呼び、未認証だと
`invalid character '<'` のようなJSONパースエラーで失敗することがある):

```bash
export GITHUB_TOKEN=$(gh auth token)
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

期待結果: ツール検出のためにイメージがビルドされ(`2 tools found.` と
表示される)、`servers/plantuml/server.yaml` が作成される。

**注意**: `task create` はソースリポジトリの参照マニフェストを
**読みません**。生成物には次の問題が含まれるため、Step 3での修正が
必須です:

- `about.title` / `about.description` が `TODO` のまま
- `about.icon` がリポジトリオーナーのアバターを指す(指定アイコンではない)
- 不要な `config:` セクション(TODO付き)が付く

一方、`source.commit` のピンは正しく付与されます(残すこと)。

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
  commit: <デフォルトブランチHEADのSHA>  # gh api repos/potofo/plantuml-mcp-server/commits/main --jq .sha
```

commitピンはレジストリの慣例です(既存エントリの大半が採用)。
手書きする場合も必ず含めること。

### Step 3 — 生成されたエントリの修正

`servers/plantuml/server.yaml` を入力情報の表と参照マニフェストに
合わせて**編集**する(照合だけでは不十分 — `task create` の生成物は
TODOを含む):

- [ ] `name` が `plantuml`(またはフォールバック名)である
- [ ] `meta.category` が `productivity` である
- [ ] `about.title` を `PlantUML` にする(生成値: `Plantuml (TODO)`)
- [ ] `about.description` を参照マニフェストの文に置き換える
      (非公認である旨の一文を含むこと)
- [ ] `about.icon` を入力情報の表のURLに置き換え(生成値はリポジトリ
      オーナーのアバター)、URLが画像を返すことを確認する
- [ ] `source.project` がソースリポジトリを指している
- [ ] `source.commit` のピンが残っている
- [ ] `config:` セクションを**削除**する(不要のため。生成物には
      TODO付きで含まれる)

### Step 4 — ローカル検証

まずCIに最も近いローカルチェックである `task validate` を実行する:

```bash
task validate -- --name plantuml
```

引数は必ず `--name plantuml` 形式にする(`-- plantuml` では空のnameと
解釈されて失敗する)。期待結果: 名前・ディレクトリ・タイトル・YAML
整形・commitピン・シークレット・config env・ライセンス・アイコン等の
全チェックが ✅ になる。

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

**既知の問題**: 環境によっては `task catalog` が
`invalid character '<' looking for beginning of value` で失敗する。
これは hub.docker.com のCloudflareがGoのHTTP/2クライアントの
TLSフィンガープリントをブロックしてHTMLを返すためで、エントリ起因
ではない(既存エントリでも再現する)。HTTP/1.1を強制すれば回避できる:

```bash
GODEBUG=http2client=0 task catalog -- plantuml
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
