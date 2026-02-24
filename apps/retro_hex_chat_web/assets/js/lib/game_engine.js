/**
 * Game engine base — pure scaffolding for lifecycle, event wiring, and canvas setup.
 * Each concrete game provides its own binary DataView protocol via protocol.js.
 * Subclasses MUST override: _handleMessage, _handleKeyDown, _handleKeyUp.
 * @module game_engine
 */

/**
 * Base game engine — manages lifecycle, event listeners, and safe channel sends.
 * Creator is authoritative (host). Peer sends only inputs.
 *
 * Subclass contract:
 * - Override _handleMessage(event) to decode your binary protocol
 * - Override _handleKeyDown(event) / _handleKeyUp(event) for input handling
 * - Call super.start() to wire listeners, then do your own init
 * - Call super.stop() for cleanup (removes listeners, cancels animFrame)
 * - Use _safeSend(data) for all DataChannel writes
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

    this._boundOnMessage = this._handleMessage.bind(this);
    this._boundOnKeyDown = this._handleKeyDown.bind(this);
    this._boundOnKeyUp = this._handleKeyUp.bind(this);
  }

  start() {
    this.running = true;
    this.channel.addEventListener("message", this._boundOnMessage);
    document.addEventListener("keydown", this._boundOnKeyDown);
    document.addEventListener("keyup", this._boundOnKeyUp);
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

  /** Override in subclass to handle binary protocol messages. */
  _handleMessage(_event) {}

  /** Override in subclass to handle key presses with game-specific input mapping. */
  _handleKeyDown(_event) {}

  /** Override in subclass to handle key releases with game-specific input mapping. */
  _handleKeyUp(_event) {}

  /** Safely send data over DataChannel, ignoring errors on closed channels. */
  _safeSend(data) {
    if (this.channel.readyState === "open") {
      try {
        this.channel.send(data);
      } catch {
        // Channel closed between readyState check and send — ignore
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
