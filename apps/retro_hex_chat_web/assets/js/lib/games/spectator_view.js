/**
 * A match drawn for somebody watching it.
 *
 * The page names the session and the game; this opens the watching end of the
 * spectate wire, builds the game's engine as a spectator — a guest that never
 * speaks and never takes the keyboard — and hands it every frame the host
 * relays. How many frames arrived is written on the element, which is what
 * says, to a test or to anybody looking, that the match is live.
 */
import { log } from "../logger.js";
import { createGameEngine } from "./engine_loader.js";
import { createSpectateWire } from "./spectate_wire.js";
import { createSpectatorTransport } from "./transport.js";

/**
 * @param {HTMLElement} el — carries `data-token` and `data-game-id`, holds the canvas
 * @param {{engineFactory?: Function, wireFactory?: Function}} [deps]
 * @returns {{mount: () => Promise<void>, destroy: () => void}}
 */
export function createSpectatorView(
  el,
  { engineFactory = createGameEngine, wireFactory = createSpectateWire } = {},
) {
  const transport = createSpectatorTransport();
  let engine = null;
  let alive = true;
  let frames = 0;

  const wire = wireFactory({
    token: el.dataset.token || null,
    onFrame: (data) => {
      frames += 1;
      el.dataset.frames = String(frames);
      transport.deliver(data);
    },
  });

  return {
    async mount() {
      wire.connect();
      const canvas = el.querySelector("canvas");
      const gameId = el.dataset.gameId;
      if (!canvas || !gameId) return;

      try {
        const loaded = await engineFactory({
          canvas,
          gameId,
          mode: "spectator",
          isHost: false,
          transport,
          onGameEnd: () => {},
        });

        if (!alive) {
          loaded.stop();
          return;
        }

        engine = loaded;
        engine.start();
        el.querySelector(".game-canvas__stub")?.classList.add("u-hidden");
      } catch (error) {
        log.error("[spectator] failed to load game engine", error);
      }
    },

    destroy() {
      alive = false;
      engine?.stop();
      engine = null;
      wire.destroy();
    },
  };
}
