#!/bin/bash
# Notification hook for the conductor sidebar (called via notifications.hooks).
# Intercepts three internal "magic notifications" and swallows them; every other
# notification passes through unchanged:
#   cmux-rename  -> show a macOS input dialog to rename a workspace (body=workspace-id)
#   cmux-seen    -> a tab was opened; clear its "finished, needs review" green dot (body=surface-id)
#   cmux-theme   -> the sidebar's light/dark switcher was clicked; set cmux's own
#                   app.appearance and activate the matching palette variant
#                   (body=light|dark)
# Note: socket authorization is based on the process ancestry chain, so we
# print the policy, close stdout, and stay resident as the authorization
# anchor for our child process.

INPUT=$(cat)
CMUX="${CMUX_BUNDLED_CLI_PATH:-/Applications/cmux.app/Contents/Resources/bin/cmux}"

# Locate cmux-status.sh (package installs it next to this script; also check
# legacy locations)
STATUS="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/cmux-status.sh"
[ -x "$STATUS" ] || STATUS="$HOME/.claude/hooks/cmux-status.sh"
[ -x "$STATUS" ] || STATUS="$HOME/.config/cmux/conductor-sidebar/cmux-status.sh"

swallow() {  # swallow the current notification: turn off all its effects
  printf '%s' "$INPUT" | /usr/bin/python3 -c '
import json,sys
d=json.load(sys.stdin)
for k in d.get("effects",{}): d["effects"][k]=False
print(json.dumps(d))'
}

case "$CMUX_NOTIFICATION_TITLE" in
  cmux-rename)
    WS="$CMUX_NOTIFICATION_BODY"
    (
      CUR=$("$CMUX" workspace list --id-format both 2>/dev/null | grep -F "$WS" | sed -E 's/^[* ]+workspace:[0-9]+ [0-9A-Fa-f-]{36} +//; s/ +\[selected\].*$//' | head -1)
      NAME=$(osascript -e "tell application id \"com.cmuxterm.app\" to activate" \
                       -e "text returned of (display dialog \"New name:\" default answer \"$CUR\" with title \"Rename Workspace\")" 2>/dev/null)
      [ -n "$NAME" ] && "$CMUX" workspace rename --workspace "$WS" --title "$NAME"
    ) &
    CHILD=$!
    swallow; exec 1>&- 2>&-; wait $CHILD
    ;;
  cmux-seen)
    ( bash "$STATUS" seen "$CMUX_NOTIFICATION_BODY" >/dev/null 2>&1 ) &
    CHILD=$!
    swallow; exec 1>&- 2>&-; wait $CHILD
    ;;
  cmux-theme)
    # The body is the appearance to move to: light or dark. Two steps, because
    # the sidebar DSL can only paint its own rows — the bar's ground, the tab
    # bar and the rest of the window come from cmux's own appearance:
    #   1. set app.appearance in cmux.json, then reload-config
    #   2. activate the palette variant that matches
    # Anything other than light/dark passes through as a normal notification.
    case "$CMUX_NOTIFICATION_BODY" in
      light) SIDEBAR=conductor ;;
      dark)  SIDEBAR=conductor-dark ;;
      *)     SIDEBAR="" ;;
    esac
    if [ -n "$SIDEBAR" ]; then
      (
        /usr/bin/python3 - "$HOME/.config/cmux/cmux.json" "$CMUX_NOTIFICATION_BODY" <<'PY'
import json, re, sys
path, mode = sys.argv[1], sys.argv[2]
try:
    raw = open(path).read()
    raw = re.sub(r'^\s*//.*$', '', raw, flags=re.M)     # whole-line comments
    raw = re.sub(r',(\s*[}\]])', r'\1', raw)            # trailing commas
    data = json.loads(raw)
except Exception as e:
    # Never write over a config we could not read: the palette still switches,
    # only the window appearance stays where the user left it.
    sys.exit(f"cmux.json unreadable, appearance left alone: {e}")
data.setdefault("app", {})["appearance"] = mode
json.dump(data, open(path, "w"), indent=2, ensure_ascii=False)
PY
        "$CMUX" reload-config >/dev/null 2>&1
        "$CMUX" sidebar select "$SIDEBAR" >/dev/null 2>&1
      ) >/dev/null 2>&1 &
      CHILD=$!
      swallow; exec 1>&- 2>&-; wait $CHILD
    else
      printf '%s' "$INPUT"
    fi
    ;;
  *)
    printf '%s' "$INPUT"
    ;;
esac
exit 0
