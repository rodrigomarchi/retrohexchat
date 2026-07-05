/**
 * LiveView Hook: SpaceCanvasHook
 *
 * Wires the virtual-space canvas to its own Phoenix Channel. Unlike LiveView
 * feature hooks that receive `push_event`, the world runtime bypasses LiveView
 * entirely: the hook opens a raw Phoenix Socket at `/socket`, joins
 * `space:<token>` with the signed `join_token` SpaceLive minted, and pipes the
 * channel's authoritative snapshots/deltas into the engine. That is why the
 * lazy registration declares `serverEvents: []`.
 *
 * @module hooks/space/space_canvas_hook
 */
import { Socket } from "phoenix";

import { SpaceEngine } from "../../lib/space/engine.js";
import { createSpriteAtlas } from "../../lib/space/sprite_atlas.js";
import { normalizeSpaceInit, CLIENT_EVENTS, SERVER_EVENTS } from "../../lib/space/protocol.js";

const TILE_SIZE = 16;
const RENDER_SCALE = 3;

/**
 * Build the hook implementation. Socket/engine construction is injectable so
 * the wiring can be unit-tested without a live server or a real canvas.
 * @param {{socketFactory?: Function, engineFactory?: Function}} [deps]
 * @returns {object} LiveView hook implementation
 */
export function createSpaceCanvasHook(deps = {}) {
  const socketFactory = deps.socketFactory ?? defaultSocketFactory;
  const engineFactory = deps.engineFactory ?? defaultEngineFactory;

  return {
    mounted() {
      this._spaceToken = this.el.dataset.spaceToken;
      this._joinToken = this.el.dataset.joinToken;

      const canvas = this.el.querySelector("canvas");
      const atlas = createSpriteAtlas({ tileSize: TILE_SIZE, scale: RENDER_SCALE });
      this._engine = engineFactory({ canvas, atlas });

      this._socket = socketFactory();
      this._socket.connect();

      this._channel = this._socket.channel(`space:${this._spaceToken}`, {
        join_token: this._joinToken,
      });

      this._wireChannelEvents(this._channel);

      this._channel
        .join()
        .receive("ok", (reply) => this._engine.start(normalizeSpaceInit(reply)))
        .receive("error", (reply) => {
          console.error("[space] channel join rejected", reply);
        })
        .receive("timeout", () => {
          console.error("[space] channel join timed out");
        });
    },

    destroyed() {
      this._engine?.destroy();
      this._channel?.leave();
      this._socket?.disconnect();
      this._engine = null;
      this._channel = null;
      this._socket = null;
    },

    _wireChannelEvents(channel) {
      channel.on(SERVER_EVENTS.SNAPSHOT, (payload) => this._engine?.applySnapshot(payload));
      channel.on(SERVER_EVENTS.DELTA, (payload) => this._engine?.applyDelta(payload));
      channel.on(SERVER_EVENTS.CLOSED, (payload) => {
        console.info("[space] session closed", payload?.reason);
      });
    },

    // Sends a step intent to the server; the engine calls this from input.
    pushInput(payload) {
      this._channel?.push(CLIENT_EVENTS.INPUT, payload);
    },
  };
}

function defaultSocketFactory() {
  return new Socket("/socket", { params: { _csrf_token: csrfToken() } });
}

function defaultEngineFactory(options) {
  return new SpaceEngine(options);
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ?? null;
}

export default createSpaceCanvasHook();
