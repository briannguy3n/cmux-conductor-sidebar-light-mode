#!/bin/bash
# cmux-tabname.sh — name the current cmux tab after the Claude Code session,
# once per turn. Registered as a Claude Code UserPromptSubmit hook.
#
# Pairs with `title = " "` in ~/.config/ghostty/config, which locks the Ghostty
# title and makes cmux IGNORE the per-output title-change escapes that an agent
# streams — those floods are what make cmux ~10x slower than the bare engine
# (see cmux #4681). With the flood gone, cmux runs at full speed; this hook
# restores meaningful tab names at a sane cadence (one rename per turn, not
# hundreds per second). rename-tab sets cmux's own custom_title, independent of
# the locked Ghostty title.

[ -n "$CMUX_WORKSPACE_ID" ] || exit 0        # only inside cmux
CMUX="${CMUX_CLAUDE_HOOK_CMUX_BIN:-/Applications/cmux.app/Contents/Resources/bin/cmux}"
[ -x "$CMUX" ] || CMUX="$(command -v cmux)" || exit 0

# UserPromptSubmit delivers JSON on stdin. Prefer the session title — the name
# Claude Code shows for the session, set by /rename or its auto-namer — because
# it stays stable for the whole session. The prompt text is only a fallback: it
# changed the tab name on every turn, so a tab never kept a recognizable name.
# The title is not in the hook payload, so read it from the transcript, where
# Claude Code re-stamps it as a "custom-title" record.
name="$(cat | python3 -c '
import sys, json, os
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

title = ""
tp = d.get("transcript_path") or ""
if tp and os.path.exists(tp):
    try:
        with open(tp, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                # cheap substring test first; only parse the few lines that hit
                if "custom-title" not in line:
                    continue
                try:
                    r = json.loads(line)
                except Exception:
                    continue
                if r.get("type") == "custom-title" and r.get("customTitle"):
                    title = r["customTitle"].strip()
    except Exception:
        pass

if not title:
    p = d.get("prompt") or d.get("user_prompt") or d.get("message") or ""
    title = next((l for l in p.splitlines() if l.strip()), "").strip()

print(title[:48])
' 2>/dev/null)"

[ -n "$name" ] || exit 0
"$CMUX" rename-tab --surface "${CMUX_SURFACE_ID:-}" --workspace "$CMUX_WORKSPACE_ID" "$name" >/dev/null 2>&1
exit 0
