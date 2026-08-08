# PlantUML MCP Server

Docker MCP Gateway 向けに設計された、PlantUML ダイアグラムをレンダリングする
Java 製 stdio MCP Server です。レンダリングは MIT ライセンス版 PlantUML
（`net.sourceforge.plantuml:plantuml-mit`）を使った **in-process 実行**で、
別プロセスの PlantUML Server は不要です。レイアウト用の Graphviz（EPL-1.0）は
外部プログラムとしてイメージに同梱します。

## Architecture

```text
MCP Client
   |
   | Streamable HTTP
   v
Docker MCP Gateway
   |
   | stdio
   v
+------------------------------------+
| Single Docker Container            |
|                                    |
|  Java MCP Server                   |
|      |                             |
|      | PlantUML core API           |
|      | (in-process, plantuml-mit)  |
|      v                             |
|  Graphviz "dot"                    |
|  (external process, EPL-1.0)       |
+------------------------------------+
```

## MVP tools

- `render_svg`
- `render_png`

## Build（ローカル開発）

```bash
mvn -q -DskipTests package
docker build -t plantuml-mcp:dev .
```

### Windows での前提条件

`mvn` で jar をビルドするには **JDK 17 以上**と **Maven 3.9 以上**が
必要です（Docker イメージだけが必要な場合、Maven は不要です —
`docker build` がビルドステージ内で Maven を実行します）。

JDK — winget でインストール（JDK 17+ が既にあればスキップ）：

```powershell
winget install EclipseAdoptium.Temurin.17.JDK
```

Maven — **winget では提供されていません**。binary zip を手動で
インストールします（管理者権限不要）：

```powershell
# 1. ダウンロードしてユーザーのプログラムフォルダに展開
Invoke-WebRequest https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.zip -OutFile "$env:TEMP\maven.zip"
Expand-Archive "$env:TEMP\maven.zip" -DestinationPath "$env:LOCALAPPDATA\Programs"

# 2. JAVA_HOME の設定と Maven の PATH 追加（ユーザースコープ、恒久設定）
[Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Java\jdk-21", "User")   # JDK のパスに合わせて調整
[Environment]::SetEnvironmentVariable("PATH", [Environment]::GetEnvironmentVariable("PATH","User") + ";$env:LOCALAPPDATA\Programs\apache-maven-3.9.9\bin", "User")
```

（Chocolatey / Scoop 利用者は `choco install maven` / `scoop install maven`
でも可。）

**新しい**ターミナルを開いて確認：

```powershell
mvn -version   # Maven 3.9+ と Java 17+ が表示されれば OK
```

## Release（自動化済み）

リリースは GitHub Actions で完全自動化されています。人間の操作はタグの
push だけです。

```bash
git tag v0.1.0
git push origin v0.1.0
```

リリースワークフローが以下を実行します。

1. マルチアーチ（amd64/arm64）イメージのビルド
2. `ghcr.io/<owner>/plantuml-mcp-server` への push（イメージ名は
   リポジトリ名から自動導出されるため、fork してもファイルを一切
   編集せずに fork 先の GHCR に publish されます）
3. **digest 固定済み `catalog.yaml`** を生成し、GitHub Release に添付

fork 時の注意: fork 後に GitHub Actions を一度有効化してください。また、
匿名 pull を許可したい場合は初回リリース後に GHCR パッケージを public に
設定してください。

## PlantUML のバージョンアップ

PlantUML のバージョンは [pom.xml](pom.xml) の Maven プロパティ 1 箇所に
集約されています。

```xml
<plantuml.version>1.2026.6</plantuml.version>
```

`plantuml-mit` は GPL 版と同一のバージョン番号・リリースサイクルで
Maven Central に公開されているため、バージョンアップはこの 1 行の変更と
リビルドだけで完了します。

## Docker MCP catalog

- **公式カタログ** — `server.yaml` が公式 [docker/mcp-registry](https://github.com/docker/mcp-registry) への contribution 形式のマニフェストです。本プロジェクトは MIT ライセンスなので、公式カタログのライセンス要件を満たします。
- **カスタムカタログ** — [GitHub Release](https://github.com/potofo/plantuml-mcp-server/releases) に添付される digest 固定済み `catalog.yaml` をダウンロードして取り込みます（リリースワークフローが自動生成するため、リポジトリには置いていません）。

```bash
docker mcp catalog import ./catalog.yaml
```

## 機能に関する注意（MIT ビルド）

PlantUML の MIT ビルドでは GPL 専用コンポーネントが除外されています。
実用上の影響は次の通りです。

- **ditaa** ダイアグラムは利用不可
- **AsciiMath/LaTeX 数式**レンダリングは利用不可（GPL ライセンスの
  JLaTeXMath jar が必要になるため、意図的に含めていません）
- UML 全図法、JSON/YAML、mindmap、WBS、Gantt、nwdiag、salt などは
  通常どおり動作します

## フォント

イメージには DejaVu（欧文）、**Noto Sans CJK**（ゴシック）、
**Noto Serif CJK JP**（明朝）を同梱しており、日本語・中国語・韓国語の
ラベルがそのまま描画できます。図ごとのフォント指定は skinparam で行います：

```plantuml
skinparam defaultFontName "Noto Serif CJK JP"   ' 明朝
skinparam defaultFontName "Noto Sans CJK JP"    ' ゴシック（既定のフォールバック）
```

要素別の指定（`titleFontName`、`actorFontName` など）も使えます。

## License

PlantUML MCP Server

Copyright (c) 2026 potofo

MIT License で配布します。全文は [LICENSE.txt](LICENSE.txt) を参照してください。

サードパーティコンポーネント:

- PlantUML（`net.sourceforge.plantuml:plantuml-mit`）— MIT License、
  Copyright PlantUML authors (Arnaud Roques)
- MCP Java SDK（`io.modelcontextprotocol.sdk:mcp`）— MIT License
- Graphviz — Eclipse Public License 1.0。Docker イメージに独立した
  外部プログラムとして同梱（サブプロセス実行であり、リンクはしない）
- Noto Sans CJK / Noto Serif CJK フォント — SIL Open Font License 1.1
- DejaVu フォント — Bitstream Vera ライセンス（フリー）

本プロジェクトは PlantUML プロジェクトの公式・公認プロジェクトではありません。
