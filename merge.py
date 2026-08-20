#!/usr/bin/env python3
# Conductor Sidebar package — config merge / removal
# Usage: merge.py <install|uninstall>
# Idempotently edits three configs: Claude settings.json, trae hooks.json, cmux.json.
import json, os, re, sys

HOME = os.path.expanduser("~")
DIR = f"{HOME}/.config/cmux/conductor-sidebar"
STATUS = f"{DIR}/cmux-status.sh"
RENAME = f"{DIR}/cmux-rename-hook.sh"
MARK = "conductor-sidebar/cmux-status.sh"          # idempotency / removal marker
TABNAME = f"{DIR}/cmux-tabname.sh"
STRIP_KEY = "conductor-sidebar/"                    # strips every hook this package added
SPEED = os.environ.get("CONDUCTOR_SPEED", "1") != "0"   # speed mode (env var) on by default; CONDUCTOR_SPEED=0 opts out
TABNAME_ON = os.environ.get("CONDUCTOR_TABNAME") == "1" # per-turn tab naming OFF by default (opt in; it overwrites titles each turn)

MODE = sys.argv[1] if len(sys.argv) > 1 else "install"

# Per-agent hook events -> (status argument, matcher)
CLAUDE_HOOKS = [
    ("UserPromptSubmit", "running", None),
    # All tools, not just Bash|Task: every tool call is the heartbeat that keeps
    # the watchdog from killing a live session and restores `running` after a
    # mid-turn permission prompt. cmux-status.sh has a fast path for it.
    ("PreToolUse",       "running", "*"),
    ("SubagentStart",    "sub_start", None),
    ("SubagentStop",     "sub_stop", None),
    ("Notification",     "waiting", None),
    ("Stop",             "ready",   None),
    ("SessionEnd",       "clear",   None),
]
TRAE_HOOKS = [
    ("UserPromptSubmit", "running", None),
    ("PreToolUse",       "running", "*"),
    ("Stop",             "ready",   None),
    ("Notification",     "waiting", None),
]

# traex — trae's newer CLI — migrated hooks out of ~/.trae/hooks.json into
# traecli.toml and no longer runs the legacy file, so a hooks.json-only mount
# silently reports nothing. Same events, TOML syntax. Both are written: older
# trae builds still read hooks.json.
TRAEX_TOML = f"{HOME}/.trae/traecli.toml"
TOML_BEGIN = "# >>> conductor-sidebar hooks >>>"
TOML_END   = "# <<< conductor-sidebar hooks <<<"
TRAEX_HOOKS = [
    ("UserPromptSubmit", "running", True),
    ("PreToolUse",       "running", True),
    ("SubagentStart",    "sub_start", True),
    ("SubagentStop",     "sub_stop", False),
    ("Notification",     "waiting", False),
    ("Stop",             "ready",   False),
    ("SessionEnd",       "clear",   False),
]

def render_traex_block():
    out = [TOML_BEGIN, "# per-tab agent status for the cmux sidebar"]
    for ev, arg, is_async in TRAEX_HOOKS:
        out += ["", f"[[hooks.{ev}]]", f"[[hooks.{ev}.hooks]]",
                'type = "command"', f'command = "bash \\"{STATUS}\\" {arg}"']
        if is_async:
            out.append("async = true")
    return "\n".join(out + ["", TOML_END])

def strip_traex_block(raw):
    kept, skip = [], False
    for line in raw.splitlines():
        s = line.strip()
        if s == TOML_BEGIN:
            skip = True
            continue
        if s == TOML_END:
            skip = False
            continue
        if not skip:
            kept.append(line)
    return "\n".join(kept).rstrip("\n") + "\n"

def process_traex():
    if not os.path.exists(TRAEX_TOML):
        return "  skip traecli.toml (not found)"
    raw = open(TRAEX_TOML).read()
    new = strip_traex_block(raw)          # install strips first: re-run = safe update
    if MODE == "install":
        new += "\n" + render_traex_block() + "\n"
    if new == raw:
        return "  traecli.toml unchanged"
    try:
        import tomllib
        tomllib.loads(new)                # a broken traecli.toml kills every hook
    except ImportError:
        pass                              # python <3.11: skip the check, not the write
    except Exception as e:
        return f"  ⚠ traecli.toml edit would not parse, left untouched: {e}"
    with open(TRAEX_TOML, "w") as f:
        f.write(new)
    return f"  {'merged' if MODE=='install' else 'removed'} hooks -> {TRAEX_TOML}"

# opencode has no shell-hook config — it loads JS plugins, registered by
# absolute file:// URL in opencode.json. The plugin itself does the same
# state mapping the shell hooks do (see files/opencode-status-plugin.js).
OPENCODE_JSON = f"{HOME}/.config/opencode/opencode.json"
OPENCODE_PLUGIN = f"{DIR}/opencode-status-plugin.js"
OPENCODE_URL = f"file://{OPENCODE_PLUGIN}"

def process_opencode():
    if not os.path.exists(OPENCODE_JSON):
        return "  skip opencode.json (not found)"
    try:
        data = load_jsonc(OPENCODE_JSON)
    except Exception as e:
        return f"  ⚠ Failed to parse opencode.json, skipped: {e}"
    plugins = data.get("plugin")
    if not isinstance(plugins, list):
        plugins = [] if MODE == "install" else None
        if plugins is None:
            return "  opencode.json unchanged"
    # drop any earlier mount (path may have moved) before re-adding
    kept = [p for p in plugins
            if not (isinstance(p, str) and "opencode-status-plugin.js" in p)]
    if MODE == "install":
        kept.append(OPENCODE_URL)
    if kept == plugins and ("plugin" in data or not kept):
        return "  opencode.json unchanged"
    if kept:
        data["plugin"] = kept
    else:
        data.pop("plugin", None)
    with open(OPENCODE_JSON, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    return f"  {'merged' if MODE=='install' else 'removed'} plugin -> {OPENCODE_JSON}"

def load_jsonc(p):
    raw = open(p).read()
    raw = re.sub(r'^\s*//.*$', '', raw, flags=re.M)   # whole-line comments
    raw = re.sub(r',(\s*[}\]])', r'\1', raw)          # trailing commas
    return json.loads(raw)

# These events run synchronously: end-of-turn / low-frequency, must fire reliably.
# (An async Stop often gets dropped before it can spawn, leaving "running"
# never cleared and the spinner stuck.) SubagentStop is here for the same reason
# on a smaller scale: a dropped decrement leaves the subagent count too high for
# the rest of the turn. A dropped SubagentStart only undercounts, so it stays async.
SYNC_EVENTS = {"Stop", "Notification", "SessionEnd", "SubagentStop"}

def hook_cmd(arg, timeout=True, is_async=True):
    # High-frequency events are async (don't block tool calls);
    # end-of-turn / low-frequency events are sync (guaranteed to run).
    e = {"type": "command", "command": f'bash "{STATUS}" {arg}'}
    if timeout: e["timeout"] = 5
    if is_async: e["async"] = True
    return e

def has_hook(hlist, ev, arg):
    for e in hlist.get(ev, []):
        for hk in e.get("hooks", []):
            c = hk.get("command", "")
            if MARK in c and c.strip().endswith(" " + arg):
                return True
    return False

def add_hooks(hlist, spec, timeout):
    for ev, arg, matcher in spec:
        if has_hook(hlist, ev, arg):
            continue
        entry = {"hooks": [hook_cmd(arg, timeout, ev not in SYNC_EVENTS)]}
        if matcher:
            entry["matcher"] = matcher
        hlist.setdefault(ev, []).append(entry)

# Speed mode: name the tab once per turn from the user's prompt (UserPromptSubmit).
# Pairs with a locked Ghostty title, which stops the per-output title-change flood
# that makes cmux slow (see cmux #4681). install.sh sets/unsets the title lock.
def add_tabname(hlist):
    ev = "UserPromptSubmit"
    for e in hlist.get(ev, []):
        for hk in e.get("hooks", []):
            if "cmux-tabname.sh" in hk.get("command", ""):
                return
    hlist.setdefault(ev, []).append(
        {"hooks": [{"type": "command", "command": f'bash "{TABNAME}"', "timeout": 5, "async": True}]})

def strip_hooks(hlist):
    for ev in list(hlist.keys()):
        kept = []
        for e in hlist[ev]:
            e["hooks"] = [hk for hk in e.get("hooks", []) if STRIP_KEY not in hk.get("command", "")]
            if e["hooks"]:
                kept.append(e)
        if kept:
            hlist[ev] = kept
        else:
            del hlist[ev]

SPEED_ENV = "CLAUDE_CODE_DISABLE_TERMINAL_TITLE"   # stops CC's title flood (cmux #4681)

def process_agent(path, spec, timeout, loader, speed=False, tabname=False, manage_env=False):
    if not os.path.exists(path):
        return f"  skip {path} (not found)"
    try:
        data = loader(path)
    except Exception as e:
        # A parse failure must fail the whole run (instead of moving on to the
        # other files) so install.sh can catch it and point at the backup —
        # never leave a half-installed state.
        print(f"✗ Failed to parse {path}: {e}", file=sys.stderr)
        sys.exit(1)
    hlist = data.setdefault("hooks", {})
    # install strips first too: removes mounts left by older versions of this
    # package (e.g. an old Stop->ready) before adding the new ones, so
    # "re-run install" is a safe update with no stale arguments left behind.
    strip_hooks(hlist)
    if MODE == "install":
        add_hooks(hlist, spec, timeout)
        if tabname:
            add_tabname(hlist)
    # Speed mode also disables Claude Code's own terminal-title updates via env,
    # so cmux stops getting flooded (surgical — other programs keep their titles).
    if manage_env:
        if MODE == "install" and speed:
            data.setdefault("env", {})[SPEED_ENV] = "1"
        else:
            env = data.get("env")
            if isinstance(env, dict):
                env.pop(SPEED_ENV, None)
                if not env:
                    data.pop("env", None)
    data.setdefault("version", data.get("version", 1)) if "trae" in path else None
    with open(path, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    return f"  {'merged' if MODE=='install' else 'removed'} hooks -> {path}"

def process_cmux():
    p = f"{HOME}/.config/cmux/cmux.json"
    if not os.path.exists(p):
        if MODE == "uninstall":
            return "  skip cmux.json (not found)"
        data = {"$schema": "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json",
                "schemaVersion": 1}
    else:
        try:
            data = load_jsonc(p)
        except Exception as e:
            return f"  ⚠ Failed to parse cmux.json, skipped (add reorderOnNotification/notifications.hooks manually): {e}"
    if MODE == "install":
        data.setdefault("app", {})["reorderOnNotification"] = False
        nh = data.setdefault("notifications", {}).setdefault("hooks", [])
        if not any(isinstance(x, dict) and x.get("id") == "conductor-rename" for x in nh):
            nh.append({"id": "conductor-rename",
                       "command": f'bash "{RENAME}"',
                       "timeoutSeconds": 180})
        data.setdefault("schemaVersion", 1)
    else:
        if "app" in data:
            data["app"].pop("reorderOnNotification", None)
            if not data["app"]:
                del data["app"]
        nf = data.get("notifications")
        if isinstance(nf, dict) and isinstance(nf.get("hooks"), list):
            nf["hooks"] = [x for x in nf["hooks"]
                           if not (isinstance(x, dict) and x.get("id") == "conductor-rename")]
            if not nf["hooks"]:
                del nf["hooks"]
            if not nf:
                del data["notifications"]
    with open(p, "w") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    return f"  {'merged' if MODE=='install' else 'removed'} config -> {p}"

if __name__ == "__main__":
    if MODE not in ("install", "uninstall"):
        # An unknown argument must never fall through to the uninstall branch
        # (strip without add = silent hook removal).
        print(f"usage: merge.py <install|uninstall> (got: {MODE!r})", file=sys.stderr)
        sys.exit(2)
    # All three configs use JSONC-tolerant parsing (comments / trailing
    # commas): hand-edited configs often contain these, and a strict
    # json.load would blow up mid-install.
    print(process_agent(f"{HOME}/.claude/settings.json", CLAUDE_HOOKS, True, load_jsonc, speed=SPEED, tabname=TABNAME_ON, manage_env=True))
    print(process_agent(f"{HOME}/.trae/hooks.json", TRAE_HOOKS, False, load_jsonc))
    print(process_traex())
    print(process_opencode())
    print(process_cmux())
