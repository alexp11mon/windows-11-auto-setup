// gk-managed:{"events":["permission.asked","permission.replied","session.compacted","session.created","session.deleted","session.error","session.execution.failed","session.idle","session.status","session.updated","tool.execute.after","tool.execute.before"],"executable":"C:/Users/alexp/AppData/Local/GitKrakenCLI/gk.exe","version":3}
import { spawn } from "node:child_process";

const EVENTS = new Set(["permission.asked","permission.replied","session.compacted","session.created","session.deleted","session.error","session.execution.failed","session.idle","session.status","session.updated","tool.execute.after","tool.execute.before"]);
const EXECUTABLE = "C:/Users/alexp/AppData/Local/GitKrakenCLI/gk.exe";
const HOST = "opencode";
const MAX_HOOK_INPUT_BYTES = 1048576;

function getString(value) {
  return typeof value === "string" && value.length > 0 ? value : "";
}

// extractToolName is the one piece of the relay every host must supply: only
// the host knows where its payloads carry a tool name. The default below
// returns null so a host that forgets it still forwards events with
// tool_name: null, instead of throwing inside runHook's catch-all and
// silently forwarding nothing at all. Hosts override it with
// {{define "extractToolName"}} — see hook_pi.js.tmpl and
// hook_opencode.js.tmpl.
function extractToolName(payload) {
  return (
    getString(payload?.input?.tool) ||
    getString(payload?.event?.properties?.part?.tool) ||
    getString(payload?.event?.properties?.tool) ||
    // v2's tool.hook("execute.before"/"execute.after") callbacks pass { event },
    // where event.tool is the tool name directly (e.g. "read").
    getString(payload?.event?.tool) ||
    ""
  );
}

function buildHookInput(eventName, sessionID, cwd, payload) {
  const toolName = extractToolName(payload);
  const hookInput = {
    hook_event_name: eventName,
    session_id: sessionID || "",
    cwd,
    tool_name: toolName || null,
    source: null,
    model: null,
    reason: null,
    agent_id: null,
    agent_type: null,
    hook_payload: payload || null,
  };

  const serializedInput = JSON.stringify(hookInput);
  const payloadBytes = Buffer.byteLength(serializedInput, "utf8");
  if (payloadBytes <= MAX_HOOK_INPUT_BYTES) {
    return serializedInput;
  }

  return JSON.stringify({
    ...hookInput,
    hook_payload: { truncated: true, originalBytes: payloadBytes },
  });
}

function runHook(eventName, sessionID, cwd, payload, aliases = []) {
  if (!EVENTS.has(eventName) && !aliases.some((alias) => EVENTS.has(alias))) return;
  try {
    const input = buildHookInput(eventName, sessionID, cwd, payload);
    const child = spawn(EXECUTABLE, ["ai", "hook", "run", "--host", HOST], {
      stdio: ["pipe", "ignore", "ignore"],
      windowsHide: true,
    });
    child.on("error", () => {});
    child.stdin.on("error", () => {});
    child.stdin.end(input);
    child.unref();
  } catch (_) {
    // Hooks must never block the host
  }
}

const V1_ONLY_EVENTS = new Set(["session.updated","session.error","session.compacted"]);
const V2_EVENT_ALIASES = new Map(Object.entries({"session.execution.failed":["session.error"],"session.status":["session.updated"]}));

function extractSessionID(event) {
  return (
    getString(event?.properties?.info?.id) ||
    getString(event?.properties?.sessionID) ||
    getString(event?.properties?.sessionId) ||
    getString(event?.properties?.session_id) ||
    getString(event?.properties?.id) ||
    getString(event?.sessionID) ||
    getString(event?.sessionId) ||
    getString(event?.session_id) ||
    // v2's event bus nests the id under `data` instead of `properties`.
    getString(event?.data?.sessionID) ||
    getString(event?.id)
  );
}



// server is the OpenCode v1 plugin entrypoint (returns a Hooks object). v1
// calls this directly off the default export below.
const server = async (ctx) => {
  // No process.cwd() fallback: that is the host's launch directory, which the
  // relay cannot tell apart from a real per-session cwd and would use to
  // attribute the session to the wrong repo. Each hook below drops its event
  // instead when cwd is empty, so the spawn is skipped entirely rather than
  // paid for and discarded by the relay's own missing-cwd guard.
  const cwd = getString(ctx.directory) || getString(ctx.worktree);
  const hooks = {};

  // General event hook — forwards native dot names as-is.
  hooks.event = async ({ event }) => {
    if (!cwd) return;
    const type = event?.type ?? "";
    if (type === "tool.execute.before" || type === "tool.execute.after") return;
    const sessionID = extractSessionID(event);
    runHook(type, sessionID, cwd, { event });
  };

  // Dedicated tool hooks — provide structured sessionID and tool name.
  if (EVENTS.has("tool.execute.before")) {
    hooks["tool.execute.before"] = async (input, output) => {
      if (!cwd) return;
      runHook(
        "tool.execute.before",
        getString(input?.sessionID) || getString(input?.sessionId) || getString(input?.session_id),
        cwd,
        { input, output }
      );
    };
  }
  if (EVENTS.has("tool.execute.after")) {
    hooks["tool.execute.after"] = async (input, output) => {
      if (!cwd) return;
      runHook(
        "tool.execute.after",
        getString(input?.sessionID) || getString(input?.sessionId) || getString(input?.session_id),
        cwd,
        { input, output }
      );
    };
  }

  return hooks;
};

// setup is the OpenCode v2 plugin entrypoint. v2 replaced the returned-Hooks
// shape with named registration APIs (ctx.tool.hook, ctx.event.subscribe). It
// dropped the v1 names ctx.directory/ctx.worktree, but the directory itself is
// still on the context as ctx.location.directory, so that is the base cwd.
const setup = async (ctx) => {
  // Per-session directories arrive only on the subset of events that carry a
  // location, and the subscription only yields from plugin load onward, so a
  // session predating this plugin instance (server restart, resumed session)
  // never populates the cache. Treat the cache as an override on top of the
  // context directory rather than the only source, and never guess: with no
  // directory at all, send "" so the relay drops the event instead of
  // attributing the session to the host's launch directory.
  const baseCwd =
    getString(ctx?.location?.directory) || getString(ctx?.directory) || getString(ctx?.worktree);
  // session.deleted is an explicit, rare user action, so eviction on it alone
  // would let a host left running for days accumulate one entry per session it
  // ever saw. Cap the map the way runner.go caps its cwd timeline and drop the
  // oldest entry first (Map iterates in insertion order); a session evicted
  // this way falls back to baseCwd, same as one that never carried a location.
  const MAX_TRACKED_SESSIONS = 50;
  const cwdBySession = new Map();
  const rememberCwd = (sessionID, directory) => {
    // Re-insert so a session still in use is treated as the newest entry.
    cwdBySession.delete(sessionID);
    cwdBySession.set(sessionID, directory);
    while (cwdBySession.size > MAX_TRACKED_SESSIONS) {
      cwdBySession.delete(cwdBySession.keys().next().value);
    }
  };
  const resolveCwd = (sessionID) => (sessionID && cwdBySession.get(sessionID)) || baseCwd;

  if (EVENTS.has("tool.execute.before")) {
    await ctx.tool.hook("execute.before", (event) => {
      const sessionID = getString(event?.sessionID);
      runHook("tool.execute.before", sessionID, resolveCwd(sessionID), { event });
    });
  }
  if (EVENTS.has("tool.execute.after")) {
    await ctx.tool.hook("execute.after", (event) => {
      const sessionID = getString(event?.sessionID);
      runHook("tool.execute.after", sessionID, resolveCwd(sessionID), { event });
    });
  }

  const controller = new AbortController();
  (async () => {
    try {
      for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
        const sessionID = extractSessionID(event);
        const directory =
          getString(event?.location?.directory) || getString(event?.data?.location?.directory);
        if (sessionID && directory) rememberCwd(sessionID, directory);

        const type = event?.type ?? "";
        if (type === "tool.execute.before" || type === "tool.execute.after") continue;
        if (V1_ONLY_EVENTS.has(type)) continue;
        runHook(type, sessionID, resolveCwd(sessionID), { event }, V2_EVENT_ALIASES.get(type));
        // Evict regardless of whether session.deleted is in the installed
        // EVENTS set, so an explicitly deleted session is released immediately
        // rather than waiting to age out of the cap above.
        if (type === "session.deleted" && sessionID) cwdBySession.delete(sessionID);
      }
    } catch (_) {
      // Subscription tears down when the plugin is disposed; must never throw.
    }
  })();

  return () => controller.abort();
};

// OpenCode v2 validates the default export as an object before reading setup;
// callable objects fail that schema. v1.4+ reads server from this same shape.
// Older v1 hosts cannot share one module shape with v2 and are unsupported by
// this v2-capable template.
export default { id: "gk-hooks", server, setup };
