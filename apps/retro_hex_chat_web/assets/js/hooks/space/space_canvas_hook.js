/**
 * LiveView Hook: SpaceCanvasHook
 *
 * Wires the virtual-space canvas to its own Phoenix Channel. Unlike LiveView
 * feature hooks that receive `push_event`, the world runtime bypasses LiveView
 * entirely: the hook opens a raw Phoenix Socket at `/socket`, joins
 * `space:#channel` with the signed `join_token` the LiveView shell minted, and
 * pipes the channel's authoritative snapshots/deltas into the engine. That is
 * why the lazy registration declares `serverEvents: []`.
 *
 * @module hooks/space/space_canvas_hook
 */
import { Socket } from "phoenix";

import { SpaceEngine } from "../../lib/space/engine.js";
import { InputController } from "../../lib/space/input.js";
import { ModalController } from "../../lib/space/modal.js";
import { interactTarget } from "../../lib/space/interactions.js";
import { seatTarget } from "../../lib/space/seating.js";
import { createSpriteAtlas } from "../../lib/space/sprite_atlas.js";
import { normalizeSpaceInit, CLIENT_EVENTS, SERVER_EVENTS } from "../../lib/space/protocol.js";

const TILE_SIZE = 16;
// Integer pixel scale shared by the sprite atlas and the camera step (they must
// match so floor tiles and avatars align). Lower = more map visible per screen.
const RENDER_SCALE = 2;

/**
 * Build the hook implementation. Socket/engine/input construction is injectable
 * so the wiring can be unit-tested without a live server or a real canvas.
 * @param {{socketFactory?: Function, engineFactory?: Function, inputFactory?: Function}} [deps]
 * @returns {object} LiveView hook implementation
 */
export function createSpaceCanvasHook(deps = {}) {
  const socketFactory = deps.socketFactory ?? defaultSocketFactory;
  const engineFactory = deps.engineFactory ?? defaultEngineFactory;
  const inputFactory = deps.inputFactory ?? defaultInputFactory;

  return {
    mounted() {
      this._spaceChannel = this.el.dataset.spaceChannel;
      this._joinToken = this.el.dataset.joinToken;

      const canvas = this.el.querySelector("canvas");
      this._canvas = canvas;
      this._atlas = createSpriteAtlas({
        tileSize: TILE_SIZE,
        scale: RENDER_SCALE,
      });
      this._engine = engineFactory({ canvas, atlas: this._atlas });

      // Size the canvas backing store to its laid-out box and keep it in sync,
      // so a bigger window (maximize) reveals more map. ResizeObserver catches
      // window-manager resizes that never fire a browser "resize" event.
      this._resizeCanvas();
      if (typeof ResizeObserver !== "undefined") {
        this._resizeObserver = new ResizeObserver(() => this._resizeCanvas());
        this._resizeObserver.observe(this.el);
      }

      this._input = inputFactory({
        onIntent: (intent) => this._onIntent(intent),
        onAction: (action) => this._onAction(action),
      });
      this._input.attach();

      this._modal = new ModalController({ onChange: (m) => this._renderModal(m) });
      this._modal.attach();

      this._socket = socketFactory();
      this._socket.connect();

      this._channel = this._socket.channel(`space:${this._spaceChannel}`, {
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
      this._input?.detach();
      this._modal?.detach();
      this._resizeObserver?.disconnect();
      this._engine?.destroy();
      this._channel?.leave();
      this._socket?.disconnect();
      this._input = null;
      this._modal = null;
      this._resizeObserver = null;
      this._canvas = null;
      this._engine = null;
      this._channel = null;
      this._socket = null;
    },

    // A key intent predicts locally; only an accepted (locally-free) step is
    // sent to the server, carrying its prediction seq for reconciliation.
    _onIntent(intent) {
      const result = this._engine?.predict(intent);
      if (result?.moved) {
        this._channel?.push(CLIENT_EVENTS.INPUT, {
          seq: result.seq,
          dx: result.dx,
          dy: result.dy,
        });
      }
    },

    // Action keys resolve a target from the avatar's facing and ask the server;
    // the server is authoritative on whether the sit/use succeeds.
    _onAction(action) {
      const self = this._engine?.self();
      const map = this._engine?.map;
      if (!self || !map) return;

      if (action === "interact") {
        const target = interactTarget(map, self);
        if (target) {
          this._channel?.push(CLIENT_EVENTS.INTERACT, { kind: "use", target_id: target.id });
        }
        return;
      }

      if (action === "sit") {
        const target = seatTarget(map, self);
        if (target) {
          this._channel?.push(CLIENT_EVENTS.INTERACT, {
            kind: target.action,
            target_id: target.id,
          });
        }
      }
    },

    _wireChannelEvents(channel) {
      channel.on(SERVER_EVENTS.SNAPSHOT, (payload) => this._engine?.applySnapshot(payload));
      channel.on(SERVER_EVENTS.DELTA, (payload) => this._engine?.applyDelta(payload));
      channel.on(SERVER_EVENTS.MESSAGE, (payload) => this._engine?.receiveMessage(payload));
      channel.on(SERVER_EVENTS.MODAL, (payload) => this._modal?.open(payload));
    },

    // Match the canvas backing store to its CSS box, then let the engine
    // re-fit the camera viewport. No-op until the element has a real size.
    _resizeCanvas() {
      const canvas = this._canvas;
      if (!canvas) return;
      const width = canvas.clientWidth || this.el.clientWidth;
      const height = canvas.clientHeight || this.el.clientHeight;
      if (width > 0 && height > 0 && (canvas.width !== width || canvas.height !== height)) {
        canvas.width = width;
        canvas.height = height;
      }
      this._engine?.resize?.();
    },

    // Renders the board modal by drawing the atlas asset into a canvas overlay.
    _renderModal(modal) {
      const host = this.el.querySelector("[data-space-modal]");
      if (!host) return;

      if (!modal) {
        host.hidden = true;
        host.replaceChildren();
        return;
      }

      host.hidden = false;
      const title = document.createElement("div");
      title.className = "font-bold";
      title.textContent = modal.title ?? "";
      const board = this._atlas?.board?.(modal.asset);
      host.replaceChildren(title);
      if (board?.canvas) host.appendChild(board.canvas);
    },
  };
}

function defaultSocketFactory() {
  return new Socket("/socket", { params: { _csrf_token: csrfToken() } });
}

function defaultEngineFactory(options) {
  return new SpaceEngine(options);
}

function defaultInputFactory(options) {
  return new InputController(options);
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ?? null;
}

export default createSpaceCanvasHook();
