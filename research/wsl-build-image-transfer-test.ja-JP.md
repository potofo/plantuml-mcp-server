# WSL でビルドしたコンテナイメージを Linux サーバにコピーしてテストする手順

Windows の WSL（Ubuntu 22.04）内でコンテナイメージをビルドし、
`./containder/` にエクスポートして、Docker MCP Gateway が動いている
Linux サーバにコピーしてテストする手順です。
**Docker Desktop も GitHub への push もコンテナレジストリも不要です。**

```text
Windows + WSL (ビルド & エクスポート)     Linux サーバ (load・実行・テスト)
------------------------------          -------------------------------
docker build (WSL 内)
docker save → ./containder/*.tar.gz ── scp ──▶  docker load
                                                docker mcp catalog import
                                                docker mcp gateway run
```

[windows-build-remote-gateway-test.ja-JP.md](windows-build-remote-gateway-test.ja-JP.md)
（ソースを転送してサーバ側でビルド）との違いは、WSL でローカルビルド
した**完成済みイメージそのもの**を転送する点です。サーバにビルド負荷を
かけたくない場合や、ローカルで検証したイメージと同一バイトのものを
サーバで動かしたい場合はこちらを選びます。

## 前提条件

| マシン | 必要なもの |
| --- | --- |
| Windows | WSL2 + Ubuntu 22.04 で、**WSL 内に Docker Engine がインストール済み**であること（確認: `wsl -d Ubuntu-22.04 docker version`）。Docker Desktop は不要です。 |
| Linux サーバ | Docker Engine、Docker MCP Gateway（`docker mcp` CLI）、SSH アクセス |

**アーキテクチャ注意**: WSL は x86_64 なので、ビルドしたイメージは
x86_64 サーバで動きます。ARM サーバの場合はサーバ側ビルドの手順
（[windows-build-remote-gateway-test.ja-JP.md](windows-build-remote-gateway-test.ja-JP.md)）
を使ってください。

## 1. WSL でイメージをビルド

`D:` のプロジェクトディレクトリは WSL から `/mnt/d` で見えます。
Windows のターミナル（または VS Code の WSL ターミナル）から：

```powershell
wsl -d Ubuntu-22.04 -- bash -c "cd /mnt/d/Developments/plantuml-mcp-server && docker build -t plantuml-mcp:dev ."
```

## 2. イメージを ./containder/ にエクスポート

```powershell
wsl -d Ubuntu-22.04 -- bash -c "mkdir -p /mnt/d/Developments/plantuml-mcp-server/containder && docker save plantuml-mcp:dev | gzip > /mnt/d/Developments/plantuml-mcp-server/containder/plantuml-mcp-dev.tar.gz"
```

`containder/plantuml-mcp-dev.tar.gz`（約 244 MB のイメージが gzip で
約 100 MB）が生成されます。このフォルダは `.gitignore` に登録済みです —
エクスポートしたイメージはローカル成果物であり、コミットしてはいけません。

## 3. アーカイブを Linux サーバにコピー

Windows から（OpenSSH の `scp` は Windows 10/11 に標準搭載）：

```powershell
scp d:\Developments\plantuml-mcp-server\containder\plantuml-mcp-dev.tar.gz user@linux-host:~/
```

## 4. サーバでイメージを load

`docker load` は gzip 圧縮のまま読み込めます（解凍不要）：

```bash
ssh user@linux-host
docker load -i ~/plantuml-mcp-dev.tar.gz
docker image ls plantuml-mcp
```

## 5. サーバ上でのスモークテスト（ゲートウェイなし）

`req.jsonl` を作成します：

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}
{"jsonrpc":"2.0","method":"notifications/initialized"}
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"render_svg","arguments":{"source":"@startuml\nclass Car {\n  +drive()\n}\nclass Engine\nCar *-- Engine\n@enduml"}}}
```

実行します — **送信後も数秒間 stdin を開いたままにする**のがポイント
です（サーバは stdin の EOF でトランスポートを終了するため、単純な
パイプだとレスポンス前に切れることがあります）：

```bash
(cat req.jsonl; sleep 20) | timeout 25 docker run -i --rm plantuml-mcp:dev > resp.jsonl
grep -o 'data-diagram-type=[^ ]*' resp.jsonl   # CLASS が出れば成功
```

クラス図を使っているのは意図的です — 同梱 Graphviz の動作確認を
兼ねています。

## 6. ローカルカタログに登録してゲートウェイ経由でテスト

サーバ上で `catalog.local.yaml` を作成します：

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

```bash
docker mcp catalog import ./catalog.local.yaml
docker mcp gateway run
```

別マシンの MCP クライアントから使う場合は、ネットワークトランスポート
（例: `docker mcp gateway run --transport streaming --port 8811`）で
起動し、クライアントに `http://linux-host:8811/mcp` を設定します。
詳細は [windows-build-remote-gateway-test.ja-JP.md](windows-build-remote-gateway-test.ja-JP.md)
の §6 を参照してください。

## 7. 反復とクリーンアップ

コード修正後の再テストは手順 1〜4 の繰り返しです（同じ `dev` タグが
load 時に上書きされ、次回のコンテナ起動から新イメージが使われます）。

サーバ側のクリーンアップ：

```bash
docker mcp catalog reset
docker rmi plantuml-mcp:dev
rm -f ~/plantuml-mcp-dev.tar.gz
```

Windows 側では、不要になったら `containder/*.tar.gz` を削除します。

## トラブルシューティング

| 症状 | 原因 / 対処 |
| --- | --- |
| サーバで `exec format error` | サーバが x86_64 ではない — サーバ側ビルドの手順を使う |
| WSL で `docker: command not found` | WSL ディストリビューション内に Docker Engine が未インストール — インストールするか、サーバ側ビルドの手順を使う |
| スモークテストで `initialize` の応答しか返らない | stdin を早く閉じすぎ — 上記の `(cat req.jsonl; sleep 20)` 形式を使う |
| ゲートウェイが `plantuml-mcp:dev` を pull しようとする | サーバにイメージがない — 手順 4 の後に `docker image ls` を再確認 |
