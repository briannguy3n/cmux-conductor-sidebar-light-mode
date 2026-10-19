#!/bin/bash
# cmux-tabname.sh — name the current cmux tab after the Claude Code session.
# Registered on SessionStart, UserPromptSubmit and Stop.
#
# Pairs with `title = " "` in ~/.config/ghostty/config, which locks the Ghostty
# title and makes cmux IGNORE the per-output title-change escapes that an agent
# streams — those floods are what make cmux ~10x slower than the bare engine
# (see cmux #4681). With the flood gone, cmux runs at full speed; this hook
# restores meaningful tab names at a sane cadence (one rename per turn, not
# hundreds per second). rename-tab sets cmux's own custom_title, independent of
# the locked Ghostty title.
#
# Name priority, best first:
#   1. /rename        — an explicit name the user typed. It pins: nothing
#                       overwrites it, and the summarizer stops running.
#   2. auto-summary   — cmux-autotitle.sh re-reads the recent turns every
#                       CONDUCTOR_TITLE_EVERY turns, so the tab follows the
#                       subject instead of freezing on the opening topic.
#   3. session title  — what Claude Code stamps as a "custom-title" record.
#                       Picked once, early, and never revised, hence 2.
#   4. first prompt   — only on UserPromptSubmit, and only until 2 or 3 exist.

[ -n "$CONDUCTOR_NO_TABNAME" ] && exit 0     # inside a summarizer run
[ -n "$CMUX_WORKSPACE_ID" ] || exit 0        # only inside cmux
CMUX="${CMUX_CLAUDE_HOOK_CMUX_BIN:-/Applications/cmux.app/Contents/Resources/bin/cmux}"
[ -x "$CMUX" ] || CMUX="$(command -v cmux)" || exit 0
ROOT="$HOME/.cache/cmux-status"; mkdir -p "$ROOT"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Every one of those events delivers JSON on stdin. The hook payload carries no
# title, so both the pinned name and the session title are read from the
# transcript. Only UserPromptSubmit carries a prompt, so Stop and SessionStart
# never overwrite a real name with the opening message.
OUT="$(cat | ROOT="$ROOT" EVERY="${CONDUCTOR_TITLE_EVERY:-5}" python3 -c '
import sys, json, os, re

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

root, every = os.environ["ROOT"], int(os.environ["EVERY"])
sid = (d.get("session_id") or "").strip()
tp = d.get("transcript_path") or ""

pinned = title = ""
turns = 0
if tp and os.path.exists(tp):
    try:
        with open(tp, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if "custom-title" in line:
                    try:
                        r = json.loads(line)
                    except Exception:
                        continue
                    if r.get("type") == "custom-title" and r.get("customTitle"):
                        title = r["customTitle"].strip()
                    continue
                if "/rename" in line and "local_command" in line:
                    try:
                        r = json.loads(line)
                    except Exception:
                        continue
                    c = r.get("content") or ""
                    if (r.get("type") != "system" or r.get("subtype") != "local_command"
                            or not c.startswith("<command-name>/rename")):
                        continue
                    m = re.search(r"<command-args>(.*?)</command-args>", c, re.S)
                    if m and m.group(1).strip():
                        pinned = m.group(1).strip()
                    continue
                if "\"type\":\"user\"" in line and "tool_result" not in line:
                    turns += 1
    except Exception:
        pass

cached = ""
if sid:
    try:
        cached = open(f"{root}/title-{sid}").read().strip()
    except Exception:
        pass

name = pinned or cached or title
if not name:
    p = d.get("prompt") or d.get("user_prompt") or ""
    name = next((l for l in p.splitlines() if l.strip()), "").strip()

# Refresh the summary every `every` turns — never when a pinned name exists,
# and not on turn 1, where the prompt itself is still the freshest thing known.
spawn = ""
if sid and not pinned and turns >= 2:
    mark = f"{root}/titleturn-{sid}"
    try:
        last = int(open(mark).read().strip())
    except Exception:
        last = 0
    if turns - last >= every:
        open(mark, "w").write(str(turns))
        spawn = "SPAWN"

print(name[:48])
print(spawn)
print(tp)
print(sid)
' 2>/dev/null)"

name="$(printf '%s' "$OUT" | sed -n 1p)"
spawn="$(printf '%s' "$OUT" | sed -n 2p)"
tp="$(printf '%s' "$OUT" | sed -n 3p)"
sid="$(printf '%s' "$OUT" | sed -n 4p)"
[ -n "$sid" ] || sid="$(basename "$tp" .jsonl)"

[ -n "$name" ] && "$CMUX" rename-tab --surface "${CMUX_SURFACE_ID:-}" \
  --workspace "$CMUX_WORKSPACE_ID" "$name" >/dev/null 2>&1

# Detached, because a model call takes seconds and a hook must not hold up the
# turn. It renames the tab itself when it lands.
if [ "$spawn" = "SPAWN" ] && [ -x "$HERE/cmux-autotitle.sh" ]; then
  nohup bash "$HERE/cmux-autotitle.sh" "$tp" "$sid" >/dev/null 2>&1 &
fi
exit 0
