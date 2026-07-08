/**
 * LiveView Hook: SpaceCanvasHook
 *
 * Wires the virtual-space canvas to its own Phoenix Channel. Unlike LiveView
 * feature hooks that receive `push_event`, the world runtime bypasses LiveView
 * entirely: the hook opens a raw Phoenix Socket at `/socket`, joins
 * `space:#channel` with the signed `join_token` the LiveView shell minted, and
 * pipes the channel's authoritative snapshots/deltas into the engine. That is why the
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
      this._spaceToken = this.el.dataset.spaceToken;
      this._joinToken = this.el.dataset.joinToken;

      const canvas = this.el.querySelector("canvas");
      this._canvas = canvas;
      // Redraw the roster thumbnails once the tileset sheets finish loading, so
      // avatar icons appear even though the canvas render loop drives the world.
      this._atlas = createSpriteAtlas({
        tileSize: TILE_SIZE,
        scale: RENDER_SCALE,
        onReady: () => this._afterWorldChange(),
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
      this._resizeObserver?.disconnect();
      if (this._chatField && this._onChatKey) {
        this._chatField.removeEventListener("keydown", this._onChatKey);
      }
      this._engine?.destroy();
      this._channel?.leave();
      this._socket?.disconnect();
      this._input = null;
      this._modal = null;
      this._chatField = null;
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

    _afterWorldChange() {
      this._updateHud();
      this._renderAdminPanel();
      this._renderPeoplePanel();
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
      // The count lives in the status bar / people window, outside the hook's
      // canvas root, so it is addressed on the document.
      const el = document.querySelector("[data-space-hud-count]");
      if (el) el.textContent = String(this._engine?.participantCount?.() ?? 1);
    },

    // A small canvas thumbnail of a participant's actual avatar sprite, used as
    // the row "icon" in the people/host lists. Draws a fresh copy so the cached
    // atlas canvas is never moved into the DOM.
    _avatarThumb(avatarId) {
      const thumb = document.createElement("canvas");
      thumb.width = 24;
      thumb.height = 24;
      thumb.className = "space-roster__avatar";
      const ctx = thumb.getContext("2d");
      const src = this._atlas?.avatar?.(avatarId, "down");
      const img = src?.img;
      if (ctx && img && img.complete && img.naturalWidth) {
        ctx.imageSmoothingEnabled = false;
        // Frame the head+torso (top tile of the 16×32 sprite) in the square.
        ctx.drawImage(img, src.sx, src.sy, src.sw, src.sw, 0, 0, thumb.width, thumb.height);
      }
      return thumb;
    },

    // Clones a real Icons glyph rendered into a hidden <template> by the shell,
    // so JS-built buttons carry proper icons without inlining SVG here.
    _icon(name) {
      const tpl = document.querySelector(`[data-space-tpl="${name}"]`);
      return tpl?.content ? tpl.content.cloneNode(true) : null;
    },

    _iconButton(label, iconName, onClick) {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "space-roster__btn";
      const icon = this._icon(iconName);
      if (icon) btn.appendChild(icon);
      const span = document.createElement("span");
      span.textContent = label;
      btn.appendChild(span);
      btn.addEventListener("click", onClick);
      return btn;
    },

    _emptyRow(text) {
      const row = document.createElement("div");
      row.className = "space-roster__empty";
      row.textContent = text;
      return row;
    },

    _participantRow(p, selfKey) {
      const row = document.createElement("div");
      row.className = "space-roster__row";
      row.appendChild(this._avatarThumb(p.avatar));
      const name = document.createElement("span");
      name.className = "space-roster__name";
      name.title = p.nickname;
      name.textContent = p.key === selfKey ? `${p.nickname} (you)` : p.nickname;
      row.appendChild(name);
      return row;
    },

    // Fills the "Who's here" window with every online participant (self marked,
    // muted ones flagged). The window body is server-rendered but JS-populated,
    // so it is queried on the document and guarded by phx-update="ignore".
    _renderPeoplePanel() {
      const panel = document.querySelector("[data-space-people-list]");
      if (!panel || !this._engine) return;

      const selfKey = this._engine.selfKey;
      const rows = [];
      for (const p of this._engine.participants.values()) {
        if (!p.online) continue;
        const row = this._participantRow(p, selfKey);
        if (p.muted) {
          const badge = document.createElement("span");
          badge.className = "space-roster__badge";
          badge.title = "Muted";
          const icon = this._icon("mute");
          if (icon) badge.appendChild(icon);
          row.appendChild(badge);
        }
        rows.push(row);
      }
      if (!rows.length) rows.push(this._emptyRow("No one here yet"));
      panel.replaceChildren(...rows);
    },

    // Creator-only: list other participants with Mute/Unmute and Kick actions.
    // The panel lives in the Host controls window (outside the hook root, only
    // rendered for the creator), so it is addressed on the document.
    _renderAdminPanel() {
      const panel = document.querySelector("[data-space-admin-list]");
      if (!panel || !this._engine) return;

      const selfKey = this._engine.selfKey;
      const rows = [];
      for (const p of this._engine.participants.values()) {
        if (p.key === selfKey || !p.online) continue;
        const row = this._participantRow(p, selfKey);

        const mute = this._iconButton(p.muted ? "Unmute" : "Mute", "mute", () =>
          this._channel?.push(CLIENT_EVENTS.ADMIN_ACTION, {
            kind: "mute",
            target_key: p.key,
            muted: !p.muted,
          }),
        );
        row.appendChild(mute);

        const kick = this._iconButton("Kick", "ban", () =>
          this._channel?.push(CLIENT_EVENTS.ADMIN_ACTION, {
            kind: "kick",
            target_key: p.key,
            reason: "removed by host",
          }),
        );
        kick.dataset.kickKey = p.key;
        row.appendChild(kick);

        rows.push(row);
      }
      if (!rows.length) rows.push(this._emptyRow("No one else is here to manage"));
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
