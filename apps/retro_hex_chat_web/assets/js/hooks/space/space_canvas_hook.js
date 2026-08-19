/**
 * LiveView Hook: SpaceCanvasHook
 *
 * Wires the virtual-space canvas to its own Phoenix Channel. Unlike LiveView
 * feature hooks that receive `push_event`, the world runtime bypasses LiveView
 * entirely: the hook opens a raw Phoenix Socket at `/socket`, joins
 * `space:<conversation>` with the signed `join_token` the LiveView shell
 * minted, and pipes the channel's authoritative snapshots/deltas into the
 * engine. That is why the lazy registration declares `serverEvents: []`.
 *
 * @module hooks/space/space_canvas_hook
 */
import { log } from "../../lib/logger.js";
import { t } from "../../lib/i18n.js";
import { Socket } from "phoenix";

import { SpaceEngine } from "../../lib/space/engine.js";
import { FullscreenToggleController } from "../../lib/space/fullscreen.js";
import { InputController } from "../../lib/space/input.js";
import { VirtualPadController } from "../../lib/space/virtual_pad.js";
import { ModalController } from "../../lib/space/modal.js";
import { interactTarget } from "../../lib/space/interactions.js";
import { seatTarget } from "../../lib/space/seating.js";
import { createSpriteAtlas } from "../../lib/space/sprite_atlas.js";
import { normalizeSpaceInit, CLIENT_EVENTS, SERVER_EVENTS } from "../../lib/space/protocol.js";
import { canvasPointFromEvent } from "../../lib/space/canvas_point.js";
import {
  cancelNickHoverTimer,
  isContextMenuOpen,
  resetNickHoverTimer,
  startNickHoverTimer,
} from "../../lib/chat/interactive.js";

const TILE_SIZE = 16;
// Integer pixel scale shared by the sprite atlas and the camera step (they must
// match so floor tiles and avatars align). Lower = more map visible per screen.
const RENDER_SCALE = 2;

/**
 * Build the hook implementation. Socket/engine/input construction is injectable
 * so the wiring can be unit-tested without a live server or a real canvas.
 * @param {{socketFactory?: Function, engineFactory?: Function, inputFactory?: Function, padFactory?: Function, fullscreenFactory?: Function}} [deps]
 * @returns {object} LiveView hook implementation
 */
export function createSpaceCanvasHook(deps = {}) {
  const socketFactory = deps.socketFactory ?? defaultSocketFactory;
  const engineFactory = deps.engineFactory ?? defaultEngineFactory;
  const inputFactory = deps.inputFactory ?? defaultInputFactory;
  const padFactory = deps.padFactory ?? defaultPadFactory;
  const fullscreenFactory = deps.fullscreenFactory ?? defaultFullscreenFactory;

  return {
    mounted() {
      this._spaceChannel = this.el.dataset.spaceChannel;
      this._joinToken = this.el.dataset.joinToken;
      // The chosen character (picked on the entry screen). Pushed to the server
      // right after join so the world swaps this participant's avatar.
      this._avatar = this.el.dataset.avatar || "";
      this._assetsReady = false;
      this._frameRenderedAfterAssets = false;
      this._loadingHidden = false;
      this._hoveredNick = null;
      this._setLoadingText(t("Connecting to space..."));

      const canvas = this.el.querySelector("canvas");
      this._canvas = canvas;
      this._atlas = createSpriteAtlas({
        tileSize: TILE_SIZE,
        scale: RENDER_SCALE,
        onReady: () => {
          this._assetsReady = true;
          this._setLoadingText(t("Drawing room..."));
        },
      });
      this._engine = engineFactory({
        canvas,
        atlas: this._atlas,
        onFrameRendered: () => {
          if (this._assetsReady) {
            this._frameRenderedAfterAssets = true;
            this._hideLoading();
          }
        },
        // The engine's render loop polls the held direction and paces repeat
        // steps to the server cadence, so holding a key walks continuously.
        getHeldIntent: () => this._input?.currentIntent() ?? null,
        onStep: (step) => this._channel?.push(CLIENT_EVENTS.INPUT, step),
      });

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

      // The on-screen pad (mobile/mouse) feeds the same InputController, so a
      // held pad button walks exactly like a held key.
      const padRoot = this.el.querySelector("[data-space-pad]");
      this._pad = padRoot ? padFactory({ root: padRoot, input: this._input }) : null;
      this._pad?.attach();

      // Fullscreen presents the whole shell (canvas + overlays); the existing
      // ResizeObserver re-fits the canvas when the shell size jumps.
      const fullscreenButton = this.el.querySelector("[data-space-fullscreen-toggle]");
      this._fullscreen = fullscreenButton
        ? fullscreenFactory({ button: fullscreenButton, target: this.el })
        : null;
      this._fullscreen?.attach();

      this._attachPointerEvents();

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
        .receive("ok", (reply) => {
          this._setLoadingText(t("Loading room..."));
          this._engine.start(normalizeSpaceInit(reply));
          if (this._avatar) {
            this._channel.push(CLIENT_EVENTS.SELECT_AVATAR, { avatar: this._avatar });
          }
        })
        .receive("error", (reply) => {
          log.error("[space] channel join rejected", reply);
          this._setLoadingText(t("Could not open space."));
        })
        .receive("timeout", () => {
          log.error("[space] channel join timed out");
          this._setLoadingText(t("Space connection timed out."));
        });
    },

    destroyed() {
      this._detachPointerEvents();
      this._fullscreen?.detach();
      this._pad?.detach();
      this._input?.detach();
      this._modal?.detach();
      cancelNickHoverTimer();
      this._resizeObserver?.disconnect();
      this._engine?.destroy();
      this._channel?.leave();
      this._socket?.disconnect();
      this._fullscreen = null;
      this._pad = null;
      this._input = null;
      this._modal = null;
      this._resizeObserver = null;
      this._canvas = null;
      this._engine = null;
      this._channel = null;
      this._socket = null;
      this._hoveredNick = null;
    },

    _setLoadingText(text) {
      const host = this.el.querySelector("[data-space-loading]");
      if (!host || this._loadingHidden) return;

      const indicatorText = host.querySelector("[data-space-loading-text]");
      if (indicatorText) indicatorText.textContent = text;

      const panel = host.querySelector("[data-space-loading-panel]");
      const title = panel?.getAttribute("aria-label")?.split(":")[0];
      if (panel && title) panel.setAttribute("aria-label", `${title}: ${text}`);
    },

    _hideLoading() {
      const host = this.el.querySelector("[data-space-loading]");
      if (!host || this._loadingHidden) return;
      this._loadingHidden = true;
      host.hidden = true;
      host.setAttribute("aria-hidden", "true");
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
    // the server is authoritative on whether sit/use succeeds. Attack is
    // visual-only: play locally for responsiveness, then broadcast to peers.
    _onAction(action) {
      if (action === "attack") {
        const result = this._engine?.performAction?.("sword");
        if (result?.acted) {
          this._channel?.push(CLIENT_EVENTS.ACTION, { kind: result.kind, dir: result.dir });
        }
        return;
      }

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
      channel.on(SERVER_EVENTS.SNAPSHOT, (payload) => this._engine?.applySnapshot?.(payload));
      channel.on(SERVER_EVENTS.DELTA, (payload) => this._engine?.applyDelta?.(payload));
      channel.on(SERVER_EVENTS.MESSAGE, (payload) => this._engine?.receiveMessage?.(payload));
      channel.on(SERVER_EVENTS.MODAL, (payload) => this._modal?.open(payload));
      channel.on(SERVER_EVENTS.ACTION, (payload) => this._engine?.receiveAction?.(payload));
    },

    _attachPointerEvents() {
      if (!this._canvas) return;

      this._onCanvasMouseMove = (event) => this._handleCanvasMouseMove(event);
      this._onCanvasMouseLeave = () => this._dismissCanvasHover();
      this._onCanvasContextMenu = (event) => this._handleCanvasContextMenu(event);
      this._onCanvasMouseDown = () => cancelNickHoverTimer();

      this._canvas.addEventListener("mousemove", this._onCanvasMouseMove);
      this._canvas.addEventListener("mouseleave", this._onCanvasMouseLeave);
      this._canvas.addEventListener("contextmenu", this._onCanvasContextMenu);
      this._canvas.addEventListener("mousedown", this._onCanvasMouseDown);
    },

    _detachPointerEvents() {
      if (!this._canvas) return;

      if (this._onCanvasMouseMove) {
        this._canvas.removeEventListener("mousemove", this._onCanvasMouseMove);
      }
      if (this._onCanvasMouseLeave) {
        this._canvas.removeEventListener("mouseleave", this._onCanvasMouseLeave);
      }
      if (this._onCanvasContextMenu) {
        this._canvas.removeEventListener("contextmenu", this._onCanvasContextMenu);
      }
      if (this._onCanvasMouseDown) {
        this._canvas.removeEventListener("mousedown", this._onCanvasMouseDown);
      }

      this._onCanvasMouseMove = null;
      this._onCanvasMouseLeave = null;
      this._onCanvasContextMenu = null;
      this._onCanvasMouseDown = null;
    },

    _handleCanvasMouseMove(event) {
      if (isContextMenuOpen()) return;

      const participant = this._participantAtEvent(event);
      const nick = participant?.nickname;

      if (!nick) {
        this._dismissCanvasHover();
        return;
      }

      const payload = () => ({
        nick,
        x: event.clientX + 8,
        y: event.clientY + 12,
      });

      if (this._hoveredNick !== nick) {
        this._hoveredNick = nick;
        startNickHoverTimer(nick, () => this.pushEvent("nick_hover", payload()));
        return;
      }

      resetNickHoverTimer(() => this.pushEvent("nick_hover", payload()));
    },

    _handleCanvasContextMenu(event) {
      const participant = this._participantAtEvent(event);
      const nick = participant?.nickname;
      if (!nick) return;

      event.preventDefault();
      cancelNickHoverTimer();
      this._hoveredNick = null;
      this.pushEvent("nick_hover_dismiss", {});
      this.pushEvent("nick_right_click", {
        nick,
        x: event.clientX,
        y: event.clientY,
      });
    },

    _dismissCanvasHover() {
      if (this._hoveredNick === null) return;

      this._hoveredNick = null;
      cancelNickHoverTimer();
      this.pushEvent("nick_hover_dismiss", {});
    },

    _participantAtEvent(event) {
      const canvas = this._canvas;
      const engine = this._engine;
      if (!canvas || typeof engine?.participantAtCanvasPoint !== "function") return null;

      const point = canvasPointFromEvent(
        event,
        canvas.getBoundingClientRect(),
        canvas.width,
        canvas.height,
      );
      if (!point) return null;
      return engine.participantAtCanvasPoint(point.x, point.y);
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

function defaultPadFactory(options) {
  return new VirtualPadController(options);
}

function defaultFullscreenFactory(options) {
  return new FullscreenToggleController(options);
}

function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.getAttribute("content") ?? null;
}

export default createSpaceCanvasHook();
