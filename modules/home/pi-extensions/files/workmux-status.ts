/**
 * Workmux status tracking extension for pi.
 *
 * Updates the current workmux/tmux window status based on agent state:
 * - working: agent is processing a turn
 * - waiting: permission/slow-mode gate is waiting for user input
 * - done: agent is idle
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

type EventBus = { on: (event: string, cb: () => void) => void };

export default function (pi: ExtensionAPI) {
  const setStatus = async (status: "working" | "waiting" | "done") => {
    try {
      await pi.exec("workmux", ["set-window-status", status], {
        timeout: 5000,
      });
    } catch {
      // Ignore errors: pi may be running outside a workmux-managed window, or
      // workmux may not be available yet.
    }
  };

  pi.on("session_start", async () => {
    await setStatus("done");
  });

  pi.on("session_shutdown", async () => {
    await setStatus("done");
  });

  pi.on("agent_start", async () => {
    await setStatus("working");
  });

  pi.on("agent_end", async () => {
    await setStatus("done");
  });

  const events = (pi as ExtensionAPI & { events?: EventBus }).events;
  events?.on("permission-gate:waiting", () => setStatus("waiting"));
  events?.on("slow-mode:waiting", () => setStatus("waiting"));
  events?.on("permission-gate:resolved", () => setStatus("working"));
  events?.on("slow-mode:resolved", () => setStatus("working"));
}
