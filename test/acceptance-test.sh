#!/usr/bin/env bash
# Acceptance tests for the EARS requirements in ACCEPTANCE.md.
#
# Verifies a built image against the automatable requirements and prints
# one TAP-style line per requirement ID. Exits non-zero if any check fails.
#
# Usage:
#   docker build -t plantuml-mcp:ci .
#   IMAGE=plantuml-mcp:ci bash test/acceptance-test.sh
#
# Dependencies: bash, docker, jq, base64, od.
set -u

IMAGE="${IMAGE:-plantuml-mcp:ci}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Markdown summary regenerated on every run; set RESULTS_MD=/dev/null to skip.
RESULTS_MD="${RESULTS_MD:-$REPO_ROOT/test/RESULTS.md}"
WORKDIR="$(mktemp -d)"
CNAME="plantuml-acceptance-$$"
trap 'docker rm -f "$CNAME" >/dev/null 2>&1; rm -rf "$WORKDIR"' EXIT

for dep in docker jq base64 od; do
  command -v "$dep" >/dev/null 2>&1 || { echo "Bail out! missing dependency: $dep"; exit 2; }
done

PASS=0; FAIL=0; N=0
ROWS=()
report() { # report <req-id> <description> <status(0=ok)>
  N=$((N + 1))
  if [ "$3" -eq 0 ]; then
    echo "ok $N - $1: $2"
    PASS=$((PASS + 1))
    ROWS+=("| $N | $1 | ✅ pass | $2 |")
  else
    echo "not ok $N - $1: $2"
    FAIL=$((FAIL + 1))
    ROWS+=("| $N | $1 | ❌ **FAIL** | $2 |")
  fi
}
skip() { # skip <req-id> <how it is verified instead>
  N=$((N + 1))
  echo "ok $N - $1 # SKIP $2"
  ROWS+=("| $N | $1 | ⏭️ skip | $2 |")
}

# --- Repository-level checks (no container needed) -------------------------

test -f "$REPO_ROOT/LICENSE.txt" && grep -q "MIT License" "$REPO_ROOT/LICENSE.txt"
report REQ-CAT-001 "MIT license text in LICENSE.txt" $?

sy_ok=0
for key in "name:" "type:" "category:" "title:" "icon:" "description:" "project:"; do
  grep -q "$key" "$REPO_ROOT/server.yaml" || sy_ok=1
done
report REQ-CAT-002 "server.yaml has required registry fields" $sy_ok

test -f "$REPO_ROOT/Dockerfile"
report REQ-CAT-003 "Dockerfile at repository root (image build proven by CI build step)" $?

# --- Container identity -----------------------------------------------------

uid="$(docker run --rm --entrypoint id "$IMAGE" -u 2>/dev/null | tr -d '[:space:]')"
[ -n "$uid" ] && [ "$uid" != "0" ]
report REQ-CAT-004 "container runs as non-root (uid=$uid)" $?

# --- One MCP session over stdio covering protocol + render requirements ----
# The container gets NO network (REQ-CAT-008): every diagram below must
# render offline.

REQ="$WORKDIR/requests.jsonl"
RESP="$WORKDIR/resp.jsonl"

j() { printf '%s\n' "$1" >> "$REQ"; }
tool_call() { # tool_call <id> <tool> <source>
  jq -cn --argjson id "$1" --arg tool "$2" --arg src "$3" \
    '{jsonrpc:"2.0",id:$id,method:"tools/call",params:{name:$tool,arguments:{source:$src}}}' >> "$REQ"
}

: > "$REQ"
j '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"acceptance","version":"0"}}}'
j '{"jsonrpc":"2.0","method":"notifications/initialized"}'
j '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
SEQUENCE=$'@startuml\nAlice -> Bob : hello\n@enduml'
tool_call 3 render_svg "$SEQUENCE"
tool_call 4 render_png "$SEQUENCE"
tool_call 5 render_svg $'@startuml\nclass Car {\n  +drive()\n}\nclass Engine\nCar *-- Engine\n@enduml'
tool_call 6 render_svg $'@startuml\nactor 利用者\n利用者 -> Server : 依頼\n@enduml'
tool_call 7 render_svg '   '
tool_call 8 render_svg "$SEQUENCE"$'\n'"$SEQUENCE"
tool_call 9 render_svg $'@startuml\nthis is not valid plantuml at all\n@enduml'
tool_call 10 render_svg $'@startditaa\n+---+\n| A |\n+---+\n@endditaa'
tool_call 11 render_svg "$(head -c 100001 /dev/zero | tr '\0' 'a')"
tool_call 12 render_svg "$SEQUENCE"

# Feed requests through a FIFO held open (the server treats stdin EOF as
# session end). Tool calls complete asynchronously and out of order, so
# wait until every request with an id has produced a response, then
# remove the container.
EXPECTED="$(grep -c '"id":' "$REQ")"
FIFO="$WORKDIR/stdin.fifo"
mkfifo "$FIFO"
docker run -i --rm --network none --name "$CNAME" "$IMAGE" \
  < "$FIFO" > "$RESP" 2> "$WORKDIR/stderr.log" &
DOCKER_PID=$!
exec 3> "$FIFO"
cat "$REQ" >&3
for _ in $(seq 1 90); do
  [ "$(grep -c '"id":' "$RESP" 2>/dev/null)" -ge "$EXPECTED" ] && break
  sleep 1
done
exec 3>&-
docker rm -f "$CNAME" >/dev/null 2>&1
wait "$DOCKER_PID" 2>/dev/null

# Troubleshooting: set DEBUG_RESP=/path/to/file to keep the raw responses.
[ -n "${DEBUG_RESP:-}" ] && cp "$RESP" "$DEBUG_RESP"

rq() { # rq <id> <jq-expr over the response with that id>
  # Slurp to a single boolean: jq 1.6's -e is unreliable on multi-document
  # streams (it reports "no output" when the last document yields nothing).
  jq -es --argjson id "$1" \
    "[.[] | select(.id == \$id)] | length == 1 and (.[0] | $2)" \
    "$RESP" >/dev/null 2>&1
}
svg_of() { # decode the SVG blob of response <id>
  jq -r --argjson id "$1" 'select(.id == $id) | .result.content[0].resource.blob' "$RESP" | base64 -d
}

rq 1 '.result.serverInfo.name == "plantuml-mcp"'
report REQ-CAT-005 "initialize succeeds and identifies plantuml-mcp" $?

rq 2 '([.result.tools[].name] | sort) == ["render_png","render_svg"] and (.result.tools | all(.inputSchema.type == "object"))'
report REQ-CAT-006 "tools/list returns render_svg + render_png with schemas, no config needed" $?

rq 2 '.result.tools | all(.description | test("PlantUML [0-9]"))'
report REQ-FUN-005 "tool descriptions advertise the PlantUML version" $?

rq 3 '(.result.isError != true)
      and .result.content[0].type == "resource"
      and .result.content[0].resource.mimeType == "image/svg+xml"
      and (.result.content[1].type == "image")
      and .result.content[1].mimeType == "image/png"
      and (.result.content[2].type == "text")
      and (.result.content[2].text | contains("<svg") | not)
      and (.result.content[2].text | contains("attached") | not)
      and (.result.content[2].text | ascii_downcase
           | contains("do not create or fabricate download links"))' \
  && svg_of 3 | grep -q "<svg"
report REQ-FUN-001 "render_svg returns SVG resource + PNG preview + non-misleading text" $?

png_magic="$(jq -r 'select(.id == 4) | .result.content[0].data' "$RESP" | base64 -d | head -c 4 | od -An -tx1 | tr -d ' \n')"
rq 4 '(.result.isError != true) and .result.content[0].type == "image" and .result.content[0].mimeType == "image/png"' \
  && [ "$png_magic" = "89504e47" ]
report REQ-FUN-002 "render_png returns a valid PNG image content" $?

rq 5 '.result.isError != true' && svg_of 5 | grep -q "<svg"
graphviz_ok=$?
report REQ-FUN-003 "class diagram renders (bundled Graphviz)" $graphviz_ok

# PlantUML writes non-ASCII text as numeric XML entities:
# 利用者 = &#21033;&#29992;&#32773;
rq 6 '.result.isError != true' && svg_of 6 | grep -q '&#21033;&#29992;&#32773;'
cjk_ok=$?
report REQ-FUN-004 "CJK labels render with bundled Noto fonts" $cjk_ok

# All renders above ran inside --network none.
[ "$graphviz_ok" -eq 0 ] && [ "$cjk_ok" -eq 0 ]
report REQ-CAT-008 "rendering works with no outbound network (--network none)" $?

rq 7 '.result.isError == true and (.result.content[0].text | contains("non-empty"))'
report REQ-ERR-001 "blank source is rejected with a tool error" $?

rq 11 '.result.isError == true and (.result.content[0].text | contains("exceeds"))'
report REQ-ERR-002 "oversized source (>100k chars) is rejected" $?

rq 9 '.result.isError == true and (.result.content[0].text | test("syntax error")) and (.result.content[0].text | contains("(line "))'
report REQ-ERR-003 "syntax errors are reported with line numbers" $?

rq 8 '.result.isError == true and (.result.content[0].text | contains("exactly one"))'
report REQ-ERR-004 "multiple @startuml blocks are rejected" $?

# The MIT build answers ditaa with a rendered "unavailable" notice rather
# than a tool error; either way, a response must come back.
rq 10 '(.result.content | length) >= 1'
report REQ-ERR-005 "MIT-build-excluded feature (ditaa) gets a response, no crash" $?

skip REQ-ERR-006 "60s render timeout: verified by design review of PlantUmlRenderer"

jq -es 'length >= 1' "$RESP" >/dev/null 2>&1
report REQ-OPS-001 "stdout contains only parseable JSON-RPC messages" $?

rq 12 '(.result.isError != true) and .result.content[0].type == "resource"'
report REQ-OPS-003 "server keeps serving after error responses" $?

# All requests were submitted in one batch, so the SDK dispatches them
# concurrently; every one must have produced a response.
[ "$(grep -c '"id":' "$RESP" 2>/dev/null)" -ge "$EXPECTED" ]
report REQ-OPS-004 "all $EXPECTED concurrent requests were answered (no deadlock)" $?

# --- SIGTERM shutdown -------------------------------------------------------

# Grace period (15s) is deliberately longer than the requirement (10s):
# a pass must come from graceful SIGTERM shutdown, not the SIGKILL fallback.
cid="$(docker run -d "$IMAGE")"
sleep 2
t0="$(date +%s)"
docker stop -t 15 "$cid" >/dev/null
t1="$(date +%s)"
docker rm -f "$cid" >/dev/null 2>&1 || true
[ $((t1 - t0)) -le 10 ]
report REQ-OPS-002 "container stops within 10s of SIGTERM ($((t1 - t0))s)" $?

skip REQ-CAT-007 "multi-arch digest-pinned release: verified on the tag-driven release workflow"

echo "1..$N"
echo "# passed=$PASS failed=$FAIL skipped=$((N - PASS - FAIL))"

COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
{
  echo "# Acceptance Test Results"
  echo
  echo "> Generated by \`test/acceptance-test.sh\` on every run — do not edit by hand."
  echo "> Requirements: [ACCEPTANCE.md](ACCEPTANCE.md) / [ACCEPTANCE.ja-JP.md](ACCEPTANCE.ja-JP.md)"
  echo
  echo "- Date (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"
  echo "- Image: \`$IMAGE\`"
  echo "- Commit: \`$COMMIT\`"
  echo "- Summary: **passed=$PASS / failed=$FAIL / skipped=$((N - PASS - FAIL))** (total $N)"
  echo
  echo "| # | Requirement | Result | Check |"
  echo "|---:|---|---|---|"
  printf '%s\n' "${ROWS[@]}"
} > "$RESULTS_MD"
echo "# results summary written to $RESULTS_MD"

[ "$FAIL" -eq 0 ]
