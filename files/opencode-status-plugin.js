// Conductor Sidebar — opencode status reporter
//
// opencode has no shell-hook config like Claude Code / trae; it loads JS
// plugins instead. This one maps opencode's plugin hooks and event stream onto
// the same cmux-status.sh states every other agent here reports:
//
//   chat.message        -> running   (you submitted a prompt)
//   tool.execute.before -> running   (heartbeat — see cmux-status.sh)
//   permission/question asked   -> waiting
//   permission/question replied -> running
//   session.idle (root session) -> ready
//   chat.message (non-root session) -> sub_start  (a subagent began)
//   session.idle (non-root session) -> sub_stop   (that subagent finished)
//   dispose             -> clear
//
// The plugin runs inside the opencode server process, which cmux launched, so
// CMUX_WORKSPACE_ID / CMUX_SURFACE_ID are inherited from the environment and
// the shared script resolves the tab on its own.

import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const HOME = process.env.HOME || "";
const STATUS = [
  join(HOME, ".config/cmux/conductor-sidebar/cmux-status.sh"),
  join(HOME, ".claude/hooks/cmux-status.sh"),
].find(existsSync);

// Fire-and-forget: opencode awaits these hooks, so nothing here may block a
// tool call. Detached + unref'd means the turn never waits on a status push.
function report(state) {
  if (!STATUS || !process.env.CMUX_WORKSPACE_ID) return;
  try {
    const child = spawn("bash", [STATUS, state], {
      stdio: "ignore",
      detached: true,
    });
    child.unref();
    child.on("error", () => {});
  } catch {
    /* status reporting must never break the agent */
  }
}

export default function ConductorSidebarStatus() {
  // Only the session you type into is the tab's session. Subagents get their
  // own sessionIDs and go idle mid-turn, which would otherwise clear the
  // spinner while the main turn is still running. Every other sessionID is a
  // subagent, so the same signal also drives the sidebar's live workflow count.
  let rootSession = null;
  const subSessions = new Set();

  // The turn is over once the root session goes idle, so forget the subagents
  // it spawned; opencode can hand the same sessionID to a later subagent.
  function rootIdleOrSubStop(sessionID) {
    if (!rootSession || sessionID === rootSession) {
      subSessions.clear();
      report("ready");
    } else if (subSessions.delete(sessionID)) {
      report("sub_stop");
    }
  }

  return {
    "chat.message": async ({ sessionID }) => {
      if (sessionID && rootSession && sessionID !== rootSession) {
        if (!subSessions.has(sessionID)) {
          subSessions.add(sessionID);
          report("sub_start");
        }
        return;
      }
      if (sessionID) rootSession = sessionID;
      report("running");
    },

    "tool.execute.before": async () => {
      report("running");
    },

    event: async ({ event }) => {
      const type = event?.type;
      const props = event?.properties || {};

      switch (type) {
        case "permission.asked":
        case "question.asked":
          report("waiting");
          return;

        case "permission.replied":
        case "question.replied":
          report("running");
          return;

        case "session.error":
        case "session.idle":
          rootIdleOrSubStop(props.sessionID);
          return;

        // Older/newer builds emit the same thing as a status update.
        case "session.status":
          if (props.status?.type === "idle") rootIdleOrSubStop(props.sessionID);
          return;
      }
    },

    dispose: async () => {
      report("clear");
    },
  };
}
