#!/bin/bash
# cmux-autotitle.sh — re-summarize a Claude Code session into a short tab name.
# Spawned in the background by cmux-tabname.sh every CONDUCTOR_TITLE_EVERY turns.
# Usage: cmux-autotitle.sh <transcript-path> <session-id>
#
# Claude Code names a session once, early, from the opening turns and never
# revises it, so a long tab keeps a name the conversation left behind. This
# reads the recent prompts and asks a cheap model for the CURRENT subject.
#
# The summarizer is itself a Claude Code run, so it must not re-enter this
# machinery: --setting-sources "" keeps it from loading the hooks that called
# it, and CONDUCTOR_NO_TABNAME makes this package's hooks no-ops even on the
# fallback path below, where user settings are loaded for their auth.

[ -n "$CONDUCTOR_NO_TABNAME" ] && exit 0      # never summarize a summarizer
export CONDUCTOR_NO_TABNAME=1
[ -n "$CMUX_WORKSPACE_ID" ] || exit 0
TP="$1"; SID="$2"
[ -n "$TP" ] && [ -f "$TP" ] && [ -n "$SID" ] || exit 0

CMUX="${CMUX_CLAUDE_HOOK_CMUX_BIN:-/Applications/cmux.app/Contents/Resources/bin/cmux}"
[ -x "$CMUX" ] || CMUX="$(command -v cmux)" || exit 0
command -v claude >/dev/null 2>&1 || exit 0
ROOT="$HOME/.cache/cmux-status"; mkdir -p "$ROOT"
MODEL="${CONDUCTOR_TITLE_MODEL:-claude-haiku-4-5-20251001}"

# The turns the user actually typed — no tool results, no hook noise, no
# assistant text. Those are what the tab name should describe.
PROMPTS="$(python3 - "$TP" <<'PY'
import json, sys
turns = []
with open(sys.argv[1], encoding="utf-8", errors="replace") as fh:
    for line in fh:
        if '"user"' not in line:
            continue
        try:
            r = json.loads(line)
        except Exception:
            continue
        if r.get("type") != "user" or r.get("isMeta") or r.get("isSidechain"):
            continue
        c = (r.get("message") or {}).get("content")
        if isinstance(c, list):
            # a list content block is a tool result far more often than typed text
            c = " ".join(b.get("text", "") for b in c if b.get("type") == "text")
        if not isinstance(c, str):
            continue
        c = c.strip()
        if not c or c.startswith("<"):        # <command-name>, <local-command-stdout>, ...
            continue
        turns.append(c[:400])
print("\n---\n".join(turns[-12:])[:4000])
PY
)"
[ -n "$PROMPTS" ] || exit 0

# Auth without the user's settings: reuse only the keys that authenticate, so
# the run stays hook-free. With neither key present, fall back to loading user
# settings — CONDUCTOR_NO_TABNAME already neutralizes our own hooks there.
AUTH="$ROOT/autotitle-auth.json"
python3 - "$HOME/.claude/settings.json" "$AUTH" <<'PY'
import json, os, sys
src, out = sys.argv[1:3]
keep = {}
try:
    d = json.load(open(src))
except Exception:
    d = {}
if d.get("apiKeyHelper"):
    keep["apiKeyHelper"] = d["apiKeyHelper"]
env = {k: v for k, v in (d.get("env") or {}).items() if k.startswith("ANTHROPIC_")}
if env:
    keep["env"] = env
if keep:
    json.dump(keep, open(out, "w"))
elif os.path.exists(out):
    os.remove(out)
PY
if [ -s "$AUTH" ]; then
  SETTINGS=(--setting-sources "" --settings "$AUTH")
elif [ -n "$ANTHROPIC_API_KEY" ]; then
  SETTINGS=(--setting-sources "")
else
  SETTINGS=(--setting-sources user)
fi

ASK="Below are the most recent turns a user typed in one coding session, oldest first.
Reply with ONLY the current subject of that session as 2-5 lowercase words.
No punctuation, no quotes, no explanation. Weight the latest turns most.

$PROMPTS"

NAME="$(claude -p --model "$MODEL" "${SETTINGS[@]}" "$ASK" </dev/null 2>/dev/null \
  | tr -d '\r' | grep -v '^$' | tail -1 \
  | sed -e 's/^[^[:alnum:]]*//' -e 's/[^[:alnum:])]*$//' | cut -c1-48)"

case "$NAME" in
  ""|*[Ee]rror*|*"not "*) exit 0 ;;   # a refusal or a failure must not become the name
esac

printf '%s' "$NAME" > "$ROOT/title-$SID"
"$CMUX" rename-tab --surface "${CMUX_SURFACE_ID:-}" --workspace "$CMUX_WORKSPACE_ID" "$NAME" >/dev/null 2>&1
exit 0
