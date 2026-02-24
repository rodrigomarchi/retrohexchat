/**
 * Game engine base — pure logic, no DOM or LiveView dependencies.
 * Handles DataChannel message protocol, encoding/decoding, and stub rendering.
 * Each concrete game will extend or replace the render/update methods.
 * @module game_engine
 */

// DataChannel message types for games (0x80+ to avoid collision with file transfer 0x01-0x09)
export const GAME_MSG = {
  GAME_STATE: 0x80, // Host → Peer: full state snapshot
  PLAYER_INPUT: 0x81, // Peer → Host: input event
  GAME_START: 0x82, // Host → Peer: game started signal
  GAME_END: 0x83, // Either → Either: game ended
  GAME_READY: 0x84, // Peer → Host: ready acknowledgment
};

/**
 * Encode a game message for DataChannel transport.
 * Format: [type_byte][json_payload_bytes]
 * @param {number} type - GAME_MSG type constant
 * @param {object} payload - JSON-serializable payload
 * @returns {ArrayBuffer}
 */
export function encodeGameMessage(type, payload) {
  const json = JSON.stringify(payload);
  const encoder = new TextEncoder();
  const data = encoder.encode(json);
  const buffer = new ArrayBuffer(1 + data.byteLength);
  const view = new Uint8Array(buffer);
  view[0] = type;
  view.set(data, 1);
  return buffer;
}

/**
 * Decode a game message from DataChannel.
 * @param {ArrayBuffer} buffer
 * @returns {{ type: number, payload: object } | null}
 */
export function decodeGameMessage(buffer) {
  const view = new Uint8Array(buffer);
  if (view.length < 1) return null;

  const type = view[0];
  if (type < 0x80) return null; // Not a game message

  if (view.length === 1) {
    return { type, payload: {} };
  }

  const decoder = new TextDecoder();
  const json = decoder.decode(view.slice(1));
  try {
    return { type, payload: JSON.parse(json) };
  } catch {
    return null;
  }
}

/**
 * Check if a DataChannel ArrayBuffer is a game message (type >= 0x80).
 * @param {ArrayBuffer} buffer
 * @returns {boolean}
 */
export function isGameMessage(buffer) {
  const view = new Uint8Array(buffer);
  return view.length > 0 && view[0] >= 0x80;
}

/**
 * Base game engine — manages game loop, rendering, and network sync.
 * Creator is authoritative (host). Peer sends only inputs.
 */
export class GameEngine {
  /**
   * @param {HTMLCanvasElement} canvas
   * @param {RTCDataChannel} channel
   * @param {string} gameId
   * @param {boolean} isHost
   */
  constructor(canvas, channel, gameId, isHost) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.channel = channel;
    this.gameId = gameId;
    this.isHost = isHost;
    this.running = false;
    this.animFrame = null;
    this.state = {};
    this.localInputs = {};

    this._boundOnMessage = this._handleMessage.bind(this);
    this._boundOnKeyDown = this._handleKeyDown.bind(this);
    this._boundOnKeyUp = this._handleKeyUp.bind(this);
  }

  start() {
    this.running = true;
    this.channel.addEventListener("message", this._boundOnMessage);
    document.addEventListener("keydown", this._boundOnKeyDown);
    document.addEventListener("keyup", this._boundOnKeyUp);

    this._renderStub();

    if (this.isHost) {
      const msg = encodeGameMessage(GAME_MSG.GAME_START, {
        gameId: this.gameId,
      });
      this.channel.send(msg);
    } else {
      const msg = encodeGameMessage(GAME_MSG.GAME_READY, {});
      this.channel.send(msg);
    }
  }

  stop() {
    this.running = false;
    if (this.animFrame) {
      cancelAnimationFrame(this.animFrame);
      this.animFrame = null;
    }
    this.channel.removeEventListener("message", this._boundOnMessage);
    document.removeEventListener("keydown", this._boundOnKeyDown);
    document.removeEventListener("keyup", this._boundOnKeyUp);
  }

  _handleMessage(event) {
    if (!(event.data instanceof ArrayBuffer)) return;
    const msg = decodeGameMessage(event.data);
    if (!msg) return;

    switch (msg.type) {
      case GAME_MSG.GAME_STATE:
        if (!this.isHost) {
          this.state = msg.payload;
          this._render();
        }
        break;
      case GAME_MSG.PLAYER_INPUT:
        if (this.isHost) {
          // Process peer input — to be implemented per-game
        }
        break;
      case GAME_MSG.GAME_START:
        // Peer received game start signal
        break;
      case GAME_MSG.GAME_READY:
        // Host received peer ready signal
        break;
      case GAME_MSG.GAME_END:
        this.stop();
        break;
    }
  }

  /** @type {string[]} */
  static GAME_KEYS = ["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "w", "a", "s", "d", " "];

  _handleKeyDown(e) {
    const key = e.key;
    if (GameEngine.GAME_KEYS.includes(key)) {
      e.preventDefault();
      this.localInputs[key] = true;
      if (!this.isHost) {
        const msg = encodeGameMessage(GAME_MSG.PLAYER_INPUT, {
          key,
          pressed: true,
        });
        this.channel.send(msg);
      }
    }
  }

  _handleKeyUp(e) {
    const key = e.key;
    if (this.localInputs[key]) {
      delete this.localInputs[key];
      if (!this.isHost) {
        const msg = encodeGameMessage(GAME_MSG.PLAYER_INPUT, {
          key,
          pressed: false,
        });
        this.channel.send(msg);
      }
    }
  }

  _renderStub() {
    const ctx = this.ctx;
    const w = this.canvas.width;
    const h = this.canvas.height;

    // Use CSS custom properties via getComputedStyle for colors
    const styles = getComputedStyle(this.canvas);
    const bgColor = styles.getPropertyValue("--game-bg-color").trim() || "#000033";
    const fgColor = styles.getPropertyValue("--game-fg-color").trim() || "#00ff00";
    const mutedColor = styles.getPropertyValue("--game-muted-color").trim() || "#006600";

    ctx.fillStyle = bgColor;
    ctx.fillRect(0, 0, w, h);

    ctx.fillStyle = fgColor;
    ctx.font = "24px monospace";
    ctx.textAlign = "center";
    const title = this.gameId.replace(/_/g, " ").toUpperCase();
    ctx.fillText(title, w / 2, h / 2 - 30);

    ctx.font = "14px monospace";
    ctx.fillStyle = mutedColor;
    ctx.fillText("Game implementation coming soon!", w / 2, h / 2 + 10);
    ctx.fillText(`Role: ${this.isHost ? "HOST" : "PEER"}`, w / 2, h / 2 + 40);

    // Draw decorative border
    ctx.strokeStyle = fgColor;
    ctx.lineWidth = 2;
    ctx.strokeRect(4, 4, w - 8, h - 8);
  }

  _render() {
    // Stub: will be overridden by specific game implementations
    this._renderStub();
  }
}
