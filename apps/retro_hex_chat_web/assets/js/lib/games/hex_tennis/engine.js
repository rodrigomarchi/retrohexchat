/**
 * TennisEngine — extends GameEngine with Hex Tennis game loop, physics, and rendering.
 * Host-authoritative: creator runs physics, peer receives state snapshots.
 * @module games/hex_tennis/engine
 */

import { GameEngine } from "../../game_engine.js";
import {
  MSG_TYPE,
  PHASE,
  GAME_MODE,
  INPUT_KEY,
  encodeGameState,
  decodeGameState,
  encodePlayerInput,
  decodePlayerInput,
  encodeGameEnd,
  decodeGameEnd,
  encodeGameReady,
  getMessageType,
} from "./protocol.js";
import {
  createInitialState,
  updatePlayer,
  updateBall,
  checkHitZone,
  checkNetCollision,
  checkOutOfBounds,
  performServe,
  checkServeLanding,
  advanceScore,
  shouldChangeover,
  resetForNextPoint,
  clearEventFlags,
} from "./physics.js";
import { render as renderFrame, getColors } from "./renderer.js";
import { TennisAudio } from "./audio.js";

const MODE_MAP = {
  hex_tennis: GAME_MODE.CLASSIC,
  hex_tennis_quick: GAME_MODE.QUICK,
  hex_tennis_sudden: GAME_MODE.SUDDEN_DEATH,
};

const STATE_SEND_INTERVAL = 2; // broadcast every 2 frames (~30Hz)
const POINT_PAUSE_FRAMES = 120; // 2s at 60fps
const CHANGEOVER_PAUSE_FRAMES = 120; // 2s

export class TennisEngine extends GameEngine {
  constructor(canvas, channel, gameId, isHost, onGameEnd) {
    super(canvas, channel, gameId, isHost);
    this.onGameEnd = onGameEnd || null;
    this.mode = MODE_MAP[gameId] ?? GAME_MODE.CLASSIC;
    this.gameState = createInitialState(this.mode);
    this.localInputs = { up: false, down: false, left: false, right: false, serve: false };
    this.remoteInputs = { up: false, down: false, left: false, right: false, serve: false };
    this._localServePressed = false;
    this._remoteServePressed = false;
    this.frameCount = 0;
    this.phaseTimer = null;
    this.pointPauseCounter = 0;
    this.audio = new TennisAudio();
    this.colors = null;
    this.peerReady = false;
    this._prevPeerFlags = {
      hitEvent: false,
      serveEvent: false,
      faultEvent: false,
      netFault: false,
      outOfBounds: false,
    };
    this._boundGameLoop = this._gameLoop.bind(this);
    this._boundBlur = this._handleBlur.bind(this);
    this._boundChannelClose = this._handleChannelClose.bind(this);
  }

  start() {
    if (this.running) return;
    super.start();
    this.colors = getColors(this.canvas);
    window.addEventListener("blur", this._boundBlur);
    this.channel.addEventListener("close", this._boundChannelClose);

    if (this.isHost) {
      this._renderState();
    } else {
      this._safeSend(encodeGameReady());
      this._renderState();
    }
  }

  stop() {
    super.stop();
    window.removeEventListener("blur", this._boundBlur);
    this.channel.removeEventListener("close", this._boundChannelClose);
    if (this.phaseTimer) {
      clearTimeout(this.phaseTimer);
      this.phaseTimer = null;
    }
    this._localServePressed = false;
    this._remoteServePressed = false;
    this.audio.dispose();
  }

  // ── Input Handling ──

  _mapKey(key) {
    switch (key) {
      case "ArrowUp":
      case "w":
      case "W":
        return INPUT_KEY.UP;
      case "ArrowDown":
      case "s":
      case "S":
        return INPUT_KEY.DOWN;
      case "ArrowLeft":
      case "a":
      case "A":
        return INPUT_KEY.LEFT;
      case "ArrowRight":
      case "d":
      case "D":
        return INPUT_KEY.RIGHT;
      case " ":
      case "Shift":
        return INPUT_KEY.SERVE;
      default:
        return null;
    }
  }

  _handleKeyDown(e) {
    const k = this._mapKey(e.key);
    if (k === null) return;
    e.preventDefault();

    if (this.isHost) {
      if (k === INPUT_KEY.UP) this.localInputs.up = true;
      else if (k === INPUT_KEY.DOWN) this.localInputs.down = true;
      else if (k === INPUT_KEY.LEFT) this.localInputs.left = true;
      else if (k === INPUT_KEY.RIGHT) this.localInputs.right = true;
      else if (k === INPUT_KEY.SERVE) this.localInputs.serve = true;
    } else {
      this._safeSend(encodePlayerInput(k, true));
    }
  }

  _handleKeyUp(e) {
    const k = this._mapKey(e.key);
    if (k === null) return;
    e.preventDefault();

    if (this.isHost) {
      if (k === INPUT_KEY.UP) this.localInputs.up = false;
      else if (k === INPUT_KEY.DOWN) this.localInputs.down = false;
      else if (k === INPUT_KEY.LEFT) this.localInputs.left = false;
      else if (k === INPUT_KEY.RIGHT) this.localInputs.right = false;
      else if (k === INPUT_KEY.SERVE) this.localInputs.serve = false;
    } else {
      this._safeSend(encodePlayerInput(k, false));
    }
  }

  _handleBlur() {
    this.localInputs = { up: false, down: false, left: false, right: false, serve: false };
    if (!this.isHost) {
      this._safeSend(encodePlayerInput(INPUT_KEY.UP, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.DOWN, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.LEFT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.RIGHT, false));
      this._safeSend(encodePlayerInput(INPUT_KEY.SERVE, false));
    }
  }

  // ── Network Messages ──

  _handleMessage(event) {
    const buf = event.data;
    if (!(buf instanceof ArrayBuffer)) return;
    const type = getMessageType(buf);
    if (type === null) return;

    if (this.isHost) {
      if (type === MSG_TYPE.PLAYER_INPUT) {
        const inp = decodePlayerInput(buf);
        if (!inp) return;
        if (inp.keyCode === INPUT_KEY.UP) this.remoteInputs.up = inp.pressed;
        else if (inp.keyCode === INPUT_KEY.DOWN) this.remoteInputs.down = inp.pressed;
        else if (inp.keyCode === INPUT_KEY.LEFT) this.remoteInputs.left = inp.pressed;
        else if (inp.keyCode === INPUT_KEY.RIGHT) this.remoteInputs.right = inp.pressed;
        else if (inp.keyCode === INPUT_KEY.SERVE) this.remoteInputs.serve = inp.pressed;
      } else if (type === MSG_TYPE.GAME_READY) {
        if (!this.peerReady) {
          this.peerReady = true;
          this._startCountdown();
        }
      }
    } else {
      // Peer
      if (type === MSG_TYPE.GAME_STATE) {
        const decoded = decodeGameState(buf);
        if (decoded) {
          const prevPhase = this.gameState.phase;
          // Merge decoded into gameState, reconstruct ball object
          this.gameState = {
            ...this.gameState,
            ...decoded,
            ball: {
              x: decoded.ballX,
              y: decoded.ballY,
              vx: decoded.ballVX,
              vy: decoded.ballVY,
              speed: this.gameState.ball ? this.gameState.ball.speed : 0,
              height: decoded.ballHeight,
              heightVel: this.gameState.ball ? this.gameState.ball.heightVel : 0,
            },
          };
          this._playPeerAudio(prevPhase, decoded.phase);
          this._renderState();
        }
      } else if (type === MSG_TYPE.GAME_END) {
        const result = decodeGameEnd(buf);
        if (result) {
          this.gameState.phase = PHASE.GAME_OVER;
          this.gameState.winner = result.winner;
          this.gameState.p1Games = result.p1Games;
          this.gameState.p2Games = result.p2Games;
          this.audio.playMatchWon();
          this._renderState();
          if (this.onGameEnd) {
            try {
              this.onGameEnd({
                score: { p1: result.p1Games, p2: result.p2Games },
                winner: result.winner,
              });
            } catch {
              // callback error — ignore
            }
          }
        }
      }
    }
  }

  // ── Countdown ──

  _startCountdown() {
    this.gameState.phase = PHASE.COUNTDOWN;
    this.gameState.countdown = 3;
    this._broadcastState();
    this._renderState();

    let count = 3;
    const tick = () => {
      if (!this.running) return;
      this.audio.playCountdown();
      count--;
      if (count <= 0) {
        this.gameState.phase = PHASE.SERVING;
        this.gameState.countdown = 0;
        this._broadcastState();
        this._renderState();
        this._startGameLoop();
      } else {
        this.gameState.countdown = count;
        this._broadcastState();
        this._renderState();
        this.phaseTimer = setTimeout(tick, 1000);
      }
    };

    this.phaseTimer = setTimeout(tick, 1000);
  }

  _startGameLoop() {
    this.frameCount = 0;
    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  // ── Game Loop (Host Only) ──

  _gameLoop() {
    if (!this.running) return;
    let s = this.gameState;

    if (s.phase === PHASE.SERVING) {
      // Update players during serve phase
      s = updatePlayer(s, 1, this.localInputs);
      s = updatePlayer(s, 2, this.remoteInputs);

      // Edge-triggered serve (host local — only when P1 is server)
      if (this.localInputs.serve && !this._localServePressed && s.server === 1) {
        s = performServe(s);
        this.audio.playServe();
      }
      this._localServePressed = this.localInputs.serve;

      // Edge-triggered serve (remote)
      if (this.remoteInputs.serve && !this._remoteServePressed) {
        if (s.server === 2) {
          s = performServe(s);
          this.audio.playServe();
        }
      }
      this._remoteServePressed = this.remoteInputs.serve;

      // Serve timer countdown (only if serve wasn't already triggered)
      if (s.phase === PHASE.SERVING) {
        s = { ...s, serveTimer: s.serveTimer - 1 };
        if (s.serveTimer <= 0) {
          s = performServe(s);
          this.audio.playServe();
        }
      }

      this.gameState = s;
    } else if (s.phase === PHASE.RALLY) {
      s = clearEventFlags(s);

      // Update players
      s = updatePlayer(s, 1, this.localInputs);
      s = updatePlayer(s, 2, this.remoteInputs);

      // Update ball
      s = updateBall(s);

      // Check hit zones
      s = checkHitZone(s, 1);
      s = checkHitZone(s, 2);

      if (s.hitEvent && !this.gameState.hitEvent) {
        this.audio.playHit();
      }

      // Check serve landing (first bounce)
      s = checkServeLanding(s);

      if (s.faultEvent && !this.gameState.faultEvent) {
        this.audio.playFault();
        if (s.phase === PHASE.SERVING) {
          // First serve fault → back to serving
          this.gameState = s;
          this._renderState();
          this.frameCount++;
          if (this.frameCount % STATE_SEND_INTERVAL === 0) {
            this._broadcastState();
          }
          this.animFrame = requestAnimationFrame(this._boundGameLoop);
          return;
        }
      }

      // Check net collision
      s = checkNetCollision(s);
      if (s.netFault && !this.gameState.netFault) {
        this.audio.playNetHit();
      }

      // Check out of bounds
      s = checkOutOfBounds(s);
      if (s.outOfBounds && !this.gameState.outOfBounds) {
        if (s.outType === 3) {
          this.audio.playAce();
        } else {
          this.audio.playOut();
        }
      }

      // Score point if someone won it
      if (s.pointWinner > 0) {
        s = advanceScore(s);
        this.audio.playPoint();

        if (s.phase === PHASE.GAME_OVER) {
          this.gameState = s;
          this._handleGameFinished();
          return;
        }

        // Transition to POINT pause
        s.phase = PHASE.POINT;
        this.pointPauseCounter = POINT_PAUSE_FRAMES;
        this.gameState = s;
        this._renderState();
        this._broadcastState();
        this.animFrame = requestAnimationFrame(this._boundGameLoop);
        return;
      }

      this.gameState = s;
    } else if (s.phase === PHASE.POINT) {
      this.pointPauseCounter--;
      if (this.pointPauseCounter <= 0) {
        // Check changeover
        if (shouldChangeover(s)) {
          s.phase = PHASE.CHANGEOVER;
          this.pointPauseCounter = CHANGEOVER_PAUSE_FRAMES;
          this.gameState = s;
        } else {
          this.gameState = resetForNextPoint(s);
        }
      }
    } else if (s.phase === PHASE.CHANGEOVER) {
      this.pointPauseCounter--;
      if (this.pointPauseCounter <= 0) {
        this.gameState = resetForNextPoint(s);
      }
    }

    // Render
    this._renderState();

    // Broadcast
    this.frameCount++;
    if (this.frameCount % STATE_SEND_INTERVAL === 0) {
      this._broadcastState();
    }

    // Check game over
    if (this.gameState.phase === PHASE.GAME_OVER) {
      this._handleGameFinished();
      return;
    }

    this.animFrame = requestAnimationFrame(this._boundGameLoop);
  }

  // ── Game End ──

  _handleGameFinished() {
    const { p1Games, p2Games, winner, gameMode, isTiebreak } = this.gameState;

    this._broadcastState();
    this._renderState();

    this._safeSend(encodeGameEnd(p1Games, p2Games, winner, gameMode, isTiebreak));

    if (winner > 0) {
      this.audio.playMatchWon();
    }

    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: { p1: p1Games, p2: p2Games },
          winner,
        });
      } catch {
        // callback error — ignore
      }
    }
  }

  // ── Connection Resilience ──

  _handleChannelClose() {
    if (this.gameState.phase === PHASE.GAME_OVER) return;
    this.gameState.phase = PHASE.GAME_OVER;
    this._renderState();
    if (this.onGameEnd) {
      try {
        this.onGameEnd({
          score: { p1: this.gameState.p1Games, p2: this.gameState.p2Games },
          winner: 0,
        });
      } catch {
        // callback error — ignore
      }
    }
  }

  // ── Rendering ──

  _renderState() {
    if (this.colors) {
      renderFrame(this.ctx, this.gameState, this.colors, performance.now());
    }
  }

  // ── State Broadcasting ──

  /** Flatten ball object for protocol encoding. */
  _flattenStateForEncode() {
    const s = this.gameState;
    return {
      ...s,
      ballX: s.ball.x,
      ballY: s.ball.y,
      ballVX: s.ball.vx,
      ballVY: s.ball.vy,
      ballHeight: s.ball.height,
    };
  }

  _broadcastState() {
    this._safeSend(encodeGameState(this._flattenStateForEncode()));
  }

  // ── Peer Audio ──

  _playPeerAudio(prevPhase, newPhase) {
    if (prevPhase !== newPhase) {
      if (newPhase === PHASE.COUNTDOWN) this.audio.playCountdown();
      if (newPhase === PHASE.GAME_OVER) this.audio.playMatchWon();
      if (newPhase === PHASE.POINT) this.audio.playPoint();
    }

    // Gameplay event sounds — edge detection (only on rising edge)
    const s = this.gameState;
    const prev = this._prevPeerFlags;

    if (s.hitEvent && !prev.hitEvent) this.audio.playHit();
    if (s.serveEvent && !prev.serveEvent) this.audio.playServe();
    if (s.faultEvent && !prev.faultEvent) this.audio.playFault();
    if (s.netFault && !prev.netFault) this.audio.playNetHit();
    if (s.outOfBounds && !prev.outOfBounds) {
      if (s.outType === 3) this.audio.playAce();
      else this.audio.playOut();
    }

    this._prevPeerFlags = {
      hitEvent: s.hitEvent,
      serveEvent: s.serveEvent,
      faultEvent: s.faultEvent,
      netFault: s.netFault,
      outOfBounds: s.outOfBounds,
    };
  }
}
