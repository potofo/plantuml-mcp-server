# Windows（JDK + Maven）でビルドし、リモートの Docker MCP Gateway サーバでテストする手順

Windows マシンでは **JDK と Maven だけ（Docker Desktop 不要）**で開発・
検証し、コンテナイメージのビルドとテストは Docker MCP Gateway が動いて
いる Linux サーバ側で行う手順です。GitHub への push もコンテナレジストリ
も不要です。

```text
Windows (jar の検証)                Linux サーバ (イメージビルド・実行・テスト)
--------------------                ---------------------------------------
mvn package
(任意でローカル実行) ── scp/rsync ─▶  docker build
     ソース一式                       docker mcp catalog import
                                      docker mcp gateway run
```

ポイント: `Dockerfile` はマルチステージ構成でビルドステージ内で Maven を
実行するため、**Docker が必要なのは Linux サーバだけ**です — そして
そのサーバにはゲートウェイが動いている時点で Docker Engine が入って
います。イメージはサーバ上でネイティブビルドされるので、CPU
アーキテクチャの不一致も起こりません（`--platform` の指定が不要）。

## 前提条件

| マシン | 必要なもの |
| --- | --- |
| Windows | JDK 17+ と Maven 3.9+（インストール手順: [README](../README.ja-JP.md#windows-での前提条件) 参照）、OpenSSH クライアント（`scp`/`ssh`、Windows 10/11 標準搭載）。**Docker Desktop は不要です。** |
| Linux サーバ | Docker Engine、Docker MCP Gateway（`docker mcp` CLI）、SSH アクセス |

## 1. Windows で jar をビルド・検証

プロジェクトルートで実行します：

```powershell
mvn -q -DskipTests package
```

コンパイルエラーを数秒で検出できます。jar は `target\plantuml-mcp.jar`
に生成されます（この jar は転送しません — サーバ側の `docker build` が
再ビルドします。この手順は手元での高速チェックです）。

任意: MCP Server を Windows 上で直接動かし、シーケンス図をレンダリング
してみることもできます（シーケンス図は Graphviz 不要なので JDK だけで
動きます）。次の 3 行を `req.jsonl` として保存します：

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"render_svg","arguments":{"source":"@startuml\nAlice -> Bob : hello\n@enduml"}}}
```

Git Bash または WSL から実行します — **送信後も数秒間 stdin を開いた
ままにする**のがポイントです（サーバは stdin の EOF でトランスポートを
終了するため、単純なパイプだとレスポンス前に切れることがあります）。
動き続けるサーバプロセスは `timeout` で止めます：

```bash
(cat req.jsonl; sleep 15) | timeout 20 java -Djava.awt.headless=true -jar target/plantuml-mcp.jar > resp.jsonl
grep -c "<svg" resp.jsonl   # 1 なら成功
```

## 2. ソース一式を Linux サーバに転送

サーバに必要なのは（jar ではなく）ソースです。`docker build` がビルド
ステージ内でコンパイルするためです：

```powershell
scp -r d:\Developments\plantuml-mcp-server user@linux-host:~/
```

繰り返し転送する場合は、ビルド成果物を除外すると高速です（Git Bash や
WSL で rsync が使える場合）：

```bash
rsync -a --exclude target/ /d/Developments/plantuml-mcp-server/ user@linux-host:~/plantuml-mcp-server/
```

## 3. Linux サーバでイメージをビルド

```bash
ssh user@linux-host
cd ~/plantuml-mcp-server
docker build -t plantuml-mcp:dev .
```

ネイティブビルドなので、イメージは自動的にサーバのアーキテクチャに
一致します。

## 4. サーバ上でのスモークテスト（ゲートウェイなし）

MCP Server は stdio で JSON-RPC を話すので、ゲートウェイを介さず直接
テストできます：

手順 1 の `req.jsonl`（またはクラス図版）を再利用し、送信後も数秒間
stdin を開いたままにして実行します：

```bash
(cat req.jsonl; sleep 20) | timeout 25 docker run -i --rm plantuml-mcp:dev > resp.jsonl
grep -c "<svg" resp.jsonl   # 1 なら成功
```

手順 1 の Windows 側チェックと違い、コンテナには Graphviz が同梱されて
いるため、クラス図などの Graphviz 依存ダイアグラムもここで検証できます。

## 5. ローカルカタログにイメージを登録

Linux サーバ上で `catalog.local.yaml` を作成します：

```yaml
version: 2
name: plantuml-local
displayName: PlantUML Local Test
registry:
  plantuml:
    title: PlantUML (local dev)
    type: server
    image: plantuml-mcp:dev
    description: Local test build.
    longLived: false
    tools:
      - name: render_svg
      - name: render_png
```

`image:` はサーバのローカルイメージストアを参照します。手順 3 で
ビルドしたイメージがそのまま使われ、pull は発生しません。import します：

```bash
docker mcp catalog import ./catalog.local.yaml
```

## 6. ゲートウェイ経由のテスト

Linux サーバでゲートウェイを起動します：

```bash
docker mcp gateway run
```

- 別マシンの MCP クライアント（Windows 上の VS Code など）から使う場合
  は、ネットワークトランスポートで起動します。例：
  `docker mcp gateway run --transport streaming --port 8811` として、
  クライアントに `http://linux-host:8811/mcp` を設定します。
  （フラグ名は `docker mcp` のバージョンで多少異なります —
  `docker mcp gateway run --help` で確認してください。）
- お使いの `docker mcp` バージョンにあれば、`docker mcp tools list` と
  `docker mcp tools call render_svg source='@startuml...'` で MCP
  クライアントなしでもテストできます。

クライアントから小さなダイアグラムで `render_svg` を呼び、SVG テキスト
が返ることを確認します。

## 7. 反復とクリーンアップ

修正のたびのループは「Windows で編集 → `mvn -q -DskipTests package`
（高速チェック）→ 転送（手順 2）→ サーバで `docker build`（手順 3。
同じ `dev` タグで上書きされ、次回のコンテナ起動から新イメージが
使われます）」です。

サーバ側のクリーンアップ：

```bash
docker mcp catalog reset          # テスト用カタログを削除
docker rmi plantuml-mcp:dev
rm -rf ~/plantuml-mcp-server
```

## トラブルシューティング

| 症状 | 原因 / 対処 |
| --- | --- |
| ゲートウェイが `plantuml-mcp:dev` を pull しようとする | サーバにイメージがない — 手順 3 の後に `docker image ls plantuml-mcp` を再確認 |
| stdio テストで応答がない | `docker run` に `-i` を付けているか確認。stdout は MCP 専用（ログは stderr） |
| クラス図が Windows（手順 1）で失敗するがコンテナでは動く | 想定どおり — Graphviz はイメージに同梱されており Windows にはないため。Windows 側チェックはシーケンス図で行うか、ローカルに Graphviz をインストール |
| 日本語が豆腐（□）になる | 旧イメージの症状（現行イメージは Noto Sans CJK / Noto Serif CJK JP 同梱済み）。最新の Dockerfile でリビルドする |

---

*関連: [docker-mcp-catalog-registration.ja-JP.md](docker-mcp-catalog-registration.ja-JP.md)
（GHCR / 公式カタログでの公開手順）。本手順は、リリースワークフローが
自動化している内容の手動版に相当します。*
