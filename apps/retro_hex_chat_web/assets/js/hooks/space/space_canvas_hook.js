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
import { InputController } from "../../lib/space/input.js";
import { ModalController } from "../../lib/space/modal.js";
import { interactTarget } from "../../lib/space/interactions.js";
import { seatTarget } from "../../lib/space/seating.js";
import { createSpriteAtlas } from "../../lib/space/sprite_atlas.js";
import { normalizeSpaceInit, CLIENT_EVENTS, SERVER_EVENTS } from "../../lib/space/protocol.js";

const TILE_SIZE = 16;
const RENDER_SCALE = 3;

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
      this._spaceToken = this.el.dataset.spaceToken;
      this._joinToken = this.el.dataset.joinToken;

      const canvas = this.el.querySelector("canvas");
      this._atlas = createSpriteAtlas({ tileSize: TILE_SIZE, scale: RENDER_SCALE });
      this._engine = engineFactory({ canvas, atlas: this._atlas });

      this._input = inputFactory({
        onIntent: (intent) => this._onIntent(intent),
        onAction: (action) => this._onAction(action),
      });
      this._input.attach();

      this._modal = new ModalController({ onChange: (m) => this._renderModal(m) });
      this._modal.attach();

      this._wireChatInput();

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
          if (reply?.reason === "kicked") this._showKickedScreen();
        })
        .receive("timeout", () => {
          console.error("[space] channel join timed out");
        });
    },

    destroyed() {
      this._input?.detach();
      this._modal?.detach();
      if (this._chatField && this._onChatKey) {
        this._chatField.removeEventListener("keydown", this._onChatKey);
      }
      this._engine?.destroy();
      this._channel?.leave();
      this._socket?.disconnect();
      this._input = null;
      this._modal = null;
      this._chatField = null;
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
      channel.on(SERVER_EVENTS.SNAPSHOT, (payload) => {
        this._engine?.applySnapshot(payload);
        this._afterWorldChange();
      });
      channel.on(SERVER_EVENTS.DELTA, (payload) => {
        this._engine?.applyDelta(payload);
        this._afterWorldChange();
      });
      channel.on(SERVER_EVENTS.MESSAGE, (payload) => this._engine?.receiveMessage(payload));
      channel.on(SERVER_EVENTS.MODAL, (payload) => this._modal?.open(payload));
      channel.on(SERVER_EVENTS.MAP_CHANGED, (payload) => {
        this._engine?.applyMapChanged(payload);
        this._afterWorldChange();
      });
      channel.on(SERVER_EVENTS.KICKED, (payload) => this._onKicked(payload));
      channel.on(SERVER_EVENTS.CLOSED, (payload) => this._onClosed(payload));
    },

    _afterWorldChange() {
      this._updateHud();
      this._renderAdminPanel();
    },

    // A kick of the local participant ends the session locally (terminal
    // screen); a remote kick just drops that avatar.
    _onKicked(payload) {
      if (payload?.key === this._engine?.selfKey) {
        this._showKickedScreen();
      } else {
        this._engine?.removeParticipant(payload?.key);
        this._afterWorldChange();
      }
    },

    _onClosed(payload) {
      console.info("[space] session closed", payload?.reason);
      this._showClosedScreen(payload?.reason);
    },

    _showKickedScreen() {
      this._input?.detach();
      this._channel?.leave();
      const el = this.el.querySelector("[data-space-kicked]");
      if (el) el.hidden = false;
    },

    _showClosedScreen(_reason) {
      const el = this.el.querySelector("[data-space-closed]");
      if (el) el.hidden = false;
    },

    // Reflect the live participant count in the corner HUD (label is in the
    // template so it stays translated).
    _updateHud() {
      const el = this.el.querySelector("[data-space-hud-count]");
      if (el) el.textContent = String(this._engine?.participantCount?.() ?? 1);
    },

    // Creator-only: list other participants with a Kick button. The panel only
    // exists in the DOM for the creator (server-rendered), so non-creators can
    // never drive admin actions from here.
    _renderAdminPanel() {
      const panel = this.el.querySelector("[data-space-admin-list]");
      if (!panel || !this._engine) return;

      const selfKey = this._engine.selfKey;
      const rows = [];
      for (const p of this._engine.participants.values()) {
        if (p.key === selfKey || !p.online) continue;
        const row = document.createElement("div");
        row.className = "flex items-center gap-2";
        const name = document.createElement("span");
        name.textContent = p.nickname;
        const kick = document.createElement("button");
        kick.type = "button";
        kick.textContent = "Kick";
        kick.dataset.kickKey = p.key;
        kick.addEventListener("click", () =>
          this._channel?.push(CLIENT_EVENTS.ADMIN_ACTION, {
            kind: "kick",
            target_key: p.key,
            reason: "removed by host",
          }),
        );
        row.append(name, kick);
        rows.push(row);
      }
      panel.replaceChildren(...rows);
    },

    // A chat input field in the shell sends messages on Enter; the input
    // controller already suppresses movement while it holds focus.
    _wireChatInput() {
      const field = this.el.querySelector("[data-space-chat-input]");
      if (!field) return;

      this._chatField = field;
      this._onChatKey = (event) => {
        if (event.key !== "Enter") return;
        event.preventDefault();
        const text = field.value.trim();
        if (text) this._channel?.push(CLIENT_EVENTS.CHAT_BUBBLE, { text });
        field.value = "";
      };
      field.addEventListener("keydown", this._onChatKey);
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
