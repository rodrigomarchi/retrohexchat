import { describe, it, expect } from "vitest";
import {
  createInitialState,
  changeLane,
  updateLaneTransition,
  getEffectiveMaxSpeed,
  updateSpeed,
  activateTurbo,
  updateAICars,
  checkCollisions,
  checkOvertakes,
  checkPlayerOvertake,
  updateFuel,
  updateFuelStations,
  updateSlipstream,
  updateWeather,
  updateZOffsets,
  tickTimers,
  stepTick,
  checkGameOver,
  determineWinner,
  clearEvents,
  packState,
  unpackState,
  SPEED_MAX,
  SPEED_TURBO_MAX,
  FUEL_BURN_PER_UNIT,
  FUEL_MAX,
  FUEL_STATION_REFILL,
  TURBO_DURATION,
  TURBO_COOLDOWN,
  TURBO_FUEL_COST,
  SLIPSTREAM_SPEED_BONUS,
  SCORE_AI_OVERTAKE,
  SCORE_PLAYER_OVERTAKE,
  SCORE_FUEL_PICKUP,
  COLLISION_TIMER_FRAMES,
  MAX_DAYS,
} from "../../../../js/lib/games/hex_enduro/physics.js";
import { PHASE, GAME_MODE, WEATHER, EVENT } from "../../../../js/lib/games/hex_enduro/protocol.js";

/** A fresh race with the drivers and the road set as given. */
function race({ p1 = {}, p2 = {}, mode = GAME_MODE.CLASSIC_DUEL, ...road } = {}) {
  const state = createInitialState(mode, 1);
  return { ...state, ...road, p1: { ...state.p1, ...p1 }, p2: { ...state.p2, ...p2 } };
}

describe("Hex Enduro Physics", () => {
  describe("createInitialState", () => {
    it("creates valid state for Classic Duel", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 12345);
      expect(state.phase).toBe(PHASE.WAITING);
      expect(state.mode).toBe(GAME_MODE.CLASSIC_DUEL);
      expect(state.weather).toBe(WEATHER.DAY);
      expect(state.dayNumber).toBe(1);
      expect(state.countdown).toBe(3);
      expect(state.seed).toBe(12345);
      expect(state.gameTimer).toBe(0);
      expect(state.p1.speed).toBe(0);
      expect(state.p1.fuel).toBe(FUEL_MAX);
      expect(state.p2.fuel).toBe(FUEL_MAX);
      expect(state.aiCars).toHaveLength(0);
    });

    it("creates Night Race with permanent night", () => {
      const state = createInitialState(GAME_MODE.NIGHT_RACE, 12345);
      expect(state.weather).toBe(WEATHER.NIGHT);
      expect(state.gameTimer).toBe(10800);
    });

    it("creates Sprint with permanent day", () => {
      const state = createInitialState(GAME_MODE.SPRINT, 12345);
      expect(state.weather).toBe(WEATHER.DAY);
      expect(state.gameTimer).toBe(5400);
    });

    it("players start in different lanes", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 12345);
      expect(state.p1.lane).toBe(1);
      expect(state.p2.lane).toBe(0);
    });
  });

  describe("changeLane", () => {
    it("changes lane left", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const s = changeLane(state, "p1", -1);
      expect(s.p1.targetLane).toBe(0);
      expect(s.p1.laneTransition).toBe(0);
    });

    it("changes lane right", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const s = changeLane(state, "p1", 1);
      expect(s.p1.targetLane).toBe(2);
    });

    it("clamps to minimum lane (0)", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      // P2 starts at lane 0
      const s = changeLane(state, "p2", -1);
      expect(s.p2.targetLane).toBe(0);
      expect(s.p2.lane).toBe(0);
    });

    it("clamps to maximum lane (2)", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const s1 = changeLane(state, "p1", 1);
      // Complete the transition
      const s2 = { ...s1, p1: { ...s1.p1, lane: 2, targetLane: 2, laneTransition: 0 } };
      const s3 = changeLane(s2, "p1", 1);
      expect(s3.p1.targetLane).toBe(2);
    });

    it("rejects change while transitioning", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const s1 = changeLane(state, "p1", 1);
      // Still transitioning (lane != targetLane)
      const s2 = changeLane(s1, "p1", -1);
      expect(s2.p1.targetLane).toBe(2); // unchanged
    });
  });

  describe("updateLaneTransition", () => {
    it("progresses transition toward target", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const s1 = changeLane(state, "p1", 1);
      const s2 = updateLaneTransition(s1, "p1");
      expect(s2.p1.laneTransition).toBeGreaterThan(0);
    });

    it("completes transition when max reached", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const s1 = changeLane(state, "p1", 1);
      // Force transition near completion
      const s2 = { ...s1, p1: { ...s1.p1, laneTransition: 250 } };
      const s3 = updateLaneTransition(s2, "p1");
      expect(s3.p1.lane).toBe(2);
      expect(s3.p1.laneTransition).toBe(0);
    });

    it("does nothing when already at target lane", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const s = updateLaneTransition(state, "p1");
      expect(s.p1.lane).toBe(1);
      expect(s.p1.laneTransition).toBe(0);
    });

    it("transitions slower in snow", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const dayState = changeLane({ ...state, weather: WEATHER.DAY }, "p1", 1);
      const snowState = changeLane({ ...state, weather: WEATHER.SNOW }, "p1", 1);

      const dayAfter = updateLaneTransition(dayState, "p1");
      const snowAfter = updateLaneTransition(snowState, "p1");

      expect(snowAfter.p1.laneTransition).toBeLessThan(dayAfter.p1.laneTransition);
    });
  });

  describe("getEffectiveMaxSpeed", () => {
    it("returns base max speed normally", () => {
      const p = { fuel: 500, boost: 0, collisionTimer: 0, slipstream: 0 };
      expect(getEffectiveMaxSpeed(p, WEATHER.DAY)).toBe(SPEED_MAX);
    });

    it("returns turbo max when boosting", () => {
      const p = { fuel: 500, boost: 100, collisionTimer: 0, slipstream: 0 };
      expect(getEffectiveMaxSpeed(p, WEATHER.DAY)).toBe(SPEED_TURBO_MAX);
    });

    it("returns collision max when collided", () => {
      const p = { fuel: 500, boost: 0, collisionTimer: 30, slipstream: 0 };
      expect(getEffectiveMaxSpeed(p, WEATHER.DAY)).toBe(300);
    });

    it("returns empty fuel max when out of fuel", () => {
      const p = { fuel: 0, boost: 0, collisionTimer: 0, slipstream: 0 };
      expect(getEffectiveMaxSpeed(p, WEATHER.DAY)).toBe(150);
    });

    it("applies weather modifier in snow", () => {
      const p = { fuel: 500, boost: 0, collisionTimer: 0, slipstream: 0 };
      const snowMax = getEffectiveMaxSpeed(p, WEATHER.SNOW);
      expect(snowMax).toBeLessThan(SPEED_MAX);
      expect(snowMax).toBe(Math.round(SPEED_MAX * 0.85));
    });

    it("adds slipstream bonus when above threshold", () => {
      const p = { fuel: 500, boost: 0, collisionTimer: 0, slipstream: 80 };
      const max = getEffectiveMaxSpeed(p, WEATHER.DAY);
      expect(max).toBe(SPEED_MAX + SLIPSTREAM_SPEED_BONUS);
    });

    it("no slipstream bonus below threshold", () => {
      const p = { fuel: 500, boost: 0, collisionTimer: 0, slipstream: 30 };
      expect(getEffectiveMaxSpeed(p, WEATHER.DAY)).toBe(SPEED_MAX);
    });
  });

  describe("updateSpeed", () => {
    it("accelerates when accel pressed", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const s = updateSpeed({ ...state, phase: PHASE.RACING }, "p1", { accel: true, brake: false });
      expect(s.p1.speed).toBeGreaterThan(0);
    });

    it("decelerates when brake pressed", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 500;
      const s = updateSpeed(state, "p1", { accel: false, brake: true });
      expect(s.p1.speed).toBeLessThan(500);
    });

    it("naturally decelerates with no input", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 100;
      const s = updateSpeed(state, "p1", { accel: false, brake: false });
      expect(s.p1.speed).toBeLessThan(100);
    });

    it("clamps to max speed", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = SPEED_MAX;
      const s = updateSpeed(state, "p1", { accel: true, brake: false });
      expect(s.p1.speed).toBe(SPEED_MAX);
    });

    it("does not go below zero", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 0;
      const s = updateSpeed(state, "p1", { accel: false, brake: true });
      expect(s.p1.speed).toBe(0);
    });
  });

  describe("activateTurbo", () => {
    it("activates when conditions met", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const s = activateTurbo(state, "p1");
      expect(s.p1.boost).toBe(TURBO_DURATION);
      expect(s.p1.fuel).toBe(FUEL_MAX - TURBO_FUEL_COST);
      expect(s.p1.turboCooldown).toBe(TURBO_COOLDOWN);
      expect(s.events & EVENT.TURBO_ACTIVATE).toBeTruthy();
    });

    it("rejects if already boosting", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.boost = 50;
      const s = activateTurbo(state, "p1");
      expect(s.p1.boost).toBe(50);
    });

    it("rejects if on cooldown", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.turboCooldown = 100;
      const s = activateTurbo(state, "p1");
      expect(s.p1.boost).toBe(0);
    });

    it("rejects if insufficient fuel", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.fuel = TURBO_FUEL_COST - 1;
      const s = activateTurbo(state, "p1");
      expect(s.p1.boost).toBe(0);
    });

    it("no fuel cost in Sprint mode", () => {
      const state = createInitialState(GAME_MODE.SPRINT, 1);
      const s = activateTurbo(state, "p1");
      expect(s.p1.boost).toBe(TURBO_DURATION);
      expect(s.p1.fuel).toBe(FUEL_MAX);
    });
  });

  describe("updateAICars", () => {
    it("spawns AI cars over time", () => {
      let state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.phase = PHASE.RACING;
      state.p1.speed = 400;
      state.p2.speed = 400;
      // Run enough frames to trigger spawn
      for (let i = 0; i < 100; i++) {
        state = updateAICars(state);
      }
      expect(state.aiCars.length).toBeGreaterThan(0);
    });

    it("moves AI cars toward player based on speed difference", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.p1.speed = 600;
      state.p2.speed = 600;
      state.aiCars = [{ lane: 1, zPos: 1000, speed: 30, type: 0 }];
      const s = updateAICars(state);
      expect(s.aiCars[0].zPos).toBeLessThan(1000);
    });

    it("removes AI cars that go behind the player", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.p1.speed = 600;
      state.p2.speed = 600;
      state.aiCars = [{ lane: 1, zPos: -250, speed: 30, type: 0 }];
      const s = updateAICars(state);
      expect(s.aiCars).toHaveLength(0);
    });

    it("deterministic spawning with same seed", () => {
      const s1 = createInitialState(GAME_MODE.CLASSIC_DUEL, 777);
      const s2 = createInitialState(GAME_MODE.CLASSIC_DUEL, 777);
      s1.p1.speed = 400;
      s1.p2.speed = 400;
      s2.p1.speed = 400;
      s2.p2.speed = 400;

      let a = s1,
        b = s2;
      for (let i = 0; i < 50; i++) {
        a = updateAICars(a);
        b = updateAICars(b);
      }
      expect(a.aiCars.length).toBe(b.aiCars.length);
    });
  });

  describe("checkCollisions", () => {
    const carAhead = (lane) => [{ lane, zPos: 10, speed: 30, type: 0 }];

    it("penalizes player colliding with AI car", () => {
      const s = checkCollisions(race({ p1: { speed: 600, lane: 1 }, aiCars: carAhead(1) }));
      expect(s.p1.speed).toBeLessThan(600);
      expect(s.p1.collisionTimer).toBe(COLLISION_TIMER_FRAMES);
      expect(s.events & EVENT.COLLISION).toBeTruthy();
    });

    it("no collision on different lanes", () => {
      // P2 on another lane and far away, so the drivers do not touch either
      const state = race({
        p1: { speed: 600, lane: 0, zOffset: 0 },
        p2: { lane: 2, zOffset: 5000 },
        aiCars: carAhead(2),
      });
      expect(checkCollisions(state).p1.speed).toBe(600);
    });

    it("ignores collision during cooldown", () => {
      const state = race({ p1: { speed: 600, lane: 1, collisionTimer: 30 }, aiCars: carAhead(1) });
      expect(checkCollisions(state).p1.speed).toBe(600);
    });

    /** Both drivers on the middle lane, 10 apart. */
    const bumping = (p1Speed, p2Speed) =>
      race({
        p1: { speed: p1Speed, lane: 1, zOffset: 100 },
        p2: { speed: p2Speed, lane: 1, zOffset: 110 },
        aiCars: [],
      });

    it("handles player-vs-player collision", () => {
      const s = checkCollisions(bumping(600, 400));
      expect(s.p1.collisionTimer).toBe(COLLISION_TIMER_FRAMES);
      expect(s.p2.collisionTimer).toBe(COLLISION_TIMER_FRAMES);
    });

    it("faster player loses more speed in P2P collision", () => {
      const s = checkCollisions(bumping(700, 300));
      const p1Loss = 700 - s.p1.speed;
      const p2Loss = 300 - s.p2.speed;
      expect(p1Loss).toBeGreaterThan(p2Loss);
    });
  });

  describe("checkOvertakes", () => {
    it("awards point when AI car passes behind", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 600;
      state.p2.speed = 600;
      const prevAiCars = [{ lane: 1, zPos: 20, speed: 30, type: 0 }];
      state.aiCars = [{ lane: 1, zPos: -10, speed: 30, type: 0 }];
      const s = checkOvertakes(state, prevAiCars);
      expect(s.p1.overtakes).toBe(1);
      expect(s.p1.score).toBe(SCORE_AI_OVERTAKE);
      expect(s.events & EVENT.OVERTAKE_AI).toBeTruthy();
    });
  });

  describe("checkPlayerOvertake", () => {
    it("awards points when P1 overtakes P2", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.zOffset = 200;
      state.p2.zOffset = 100;
      const s = checkPlayerOvertake(state, 90, 100); // P1 was behind, now ahead
      expect(s.p1.score).toBe(SCORE_PLAYER_OVERTAKE);
      expect(s.events & EVENT.OVERTAKE_PLAYER).toBeTruthy();
    });

    it("awards points when P2 overtakes P1", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.zOffset = 100;
      state.p2.zOffset = 200;
      const s = checkPlayerOvertake(state, 110, 100); // P2 was behind, now ahead
      expect(s.p2.score).toBe(SCORE_PLAYER_OVERTAKE);
    });

    it("no overtake if positions unchanged", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.zOffset = 200;
      state.p2.zOffset = 100;
      const s = checkPlayerOvertake(state, 190, 100);
      expect(s.p1.score).toBe(0);
      expect(s.p2.score).toBe(0);
    });
  });

  describe("updateFuel", () => {
    function driveFrames(state, frames) {
      let s = state;
      for (let i = 0; i < frames; i++) s = updateFuel(s, "p1");
      return s;
    }

    it("drains fuel as the car drives", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 400;
      const s = driveFrames(state, FUEL_BURN_PER_UNIT);
      expect(s.p1.fuel).toBeLessThan(FUEL_MAX);
    });

    it("burns a quarter unit a frame at top speed: a full tank lasts 4000 frames", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = SPEED_MAX;
      expect(driveFrames(state, 400).p1.fuel).toBe(FUEL_MAX - 100);
      expect(driveFrames(state, 3999).p1.fuel).toBe(1);
      expect(driveFrames(state, 4000).p1.fuel).toBe(0);
    });

    it("keeps the part of a unit still burning between frames", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = SPEED_MAX;
      const s = driveFrames(state, 3);
      expect(s.p1.fuel).toBe(FUEL_MAX);
      expect(s.p1.fuelBurn).toBe(12);
      expect(updateFuel(s, "p1").p1).toMatchObject({ fuel: FUEL_MAX - 1, fuelBurn: 0 });
    });

    it("drains more fuel during turbo", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 400;
      state.p1.boost = 100;
      const turboState = driveFrames(state, 80);

      const normalState = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      normalState.p1.speed = 400;
      const normalAfter = driveFrames(normalState, 80);

      expect(turboState.p1.fuel).toBeLessThan(normalAfter.p1.fuel);
    });

    it("does not drain below zero", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.fuel = 1;
      state.p1.speed = 400;
      const s = driveFrames(state, FUEL_BURN_PER_UNIT * 2);
      expect(s.p1.fuel).toBe(0);
    });

    it("skips fuel drain in Sprint mode", () => {
      const state = createInitialState(GAME_MODE.SPRINT, 1);
      state.p1.speed = 800;
      const s = updateFuel(state, "p1");
      expect(s.p1.fuel).toBe(FUEL_MAX);
    });
  });

  describe("updateFuelStations", () => {
    it("moves fuel stations toward player", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 400;
      state.p2.speed = 400;
      state.fuelStations = [{ lane: 1, zPos: 500 }];
      const s = updateFuelStations(state);
      expect(s.fuelStations[0].zPos).toBeLessThan(500);
    });

    /** A station about to be reached on the middle lane, both drivers at 400. */
    const atStation = (p1, p2 = {}) =>
      race({
        p1: { lane: 1, speed: 400, ...p1 },
        p2: { speed: 400, ...p2 },
        fuelStations: [{ lane: 1, zPos: 10 }],
      });

    it("refuels player who reaches station in same lane", () => {
      const s = updateFuelStations(atStation({ fuel: 500 }));
      expect(s.p1.fuel).toBe(500 + FUEL_STATION_REFILL);
      expect(s.p1.score).toBe(SCORE_FUEL_PICKUP);
      expect(s.fuelStations).toHaveLength(0); // consumed
    });

    it("caps fuel at max", () => {
      expect(updateFuelStations(atStation({ fuel: FUEL_MAX - 10 })).p1.fuel).toBe(FUEL_MAX);
    });

    it("first player captures, second doesn't", () => {
      const s = updateFuelStations(atStation({ fuel: 500 }, { fuel: 500, lane: 1 }));
      // P1 captures first
      expect(s.p1.fuel).toBe(500 + FUEL_STATION_REFILL);
      expect(s.p2.fuel).toBe(500); // doesn't get it
    });
  });

  describe("updateSlipstream", () => {
    /** P1 100 behind P2, each on the lane given. */
    const trailing = (p1Lane, p2Lane) =>
      race({ p1: { lane: p1Lane, zOffset: 50 }, p2: { lane: p2Lane, zOffset: 150 } });

    it("builds slipstream when behind opponent in same lane", () => {
      const s = updateSlipstream(trailing(1, 1));
      expect(s.p1.slipstream).toBeGreaterThan(0);
      expect(s.p2.slipstream).toBe(0);
    });

    it("no slipstream on different lanes", () => {
      expect(updateSlipstream(trailing(0, 2)).p1.slipstream).toBe(0);
    });

    it("decays when not drafting", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.slipstream = 100;
      state.p1.lane = 0;
      state.p2.lane = 2;
      const s = updateSlipstream(state);
      expect(s.p1.slipstream).toBeLessThan(100);
    });

    it("sets event flag", () => {
      expect(updateSlipstream(trailing(1, 1)).events & EVENT.SLIPSTREAM).toBeTruthy();
    });
  });

  describe("updateWeather", () => {
    it("transitions to next weather when timer expires", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.weatherTimer = 1;
      const s = updateWeather(state);
      expect(s.weather).toBe(WEATHER.SNOW);
      expect(s.weatherTimer).toBeGreaterThan(0);
      expect(s.events & EVENT.WEATHER_CHANGE).toBeTruthy();
    });

    it("follows correct weather sequence", () => {
      let state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      const sequence = [WEATHER.SNOW, WEATHER.FOG, WEATHER.NIGHT, WEATHER.DAWN, WEATHER.DAY];
      for (const expected of sequence) {
        state.weatherTimer = 1;
        state = updateWeather(state);
        expect(state.weather).toBe(expected);
      }
    });

    it("increments day number when DAWN completes", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.weather = WEATHER.DAWN;
      state.weatherTimer = 1;
      const s = updateWeather(state);
      expect(s.weather).toBe(WEATHER.DAY);
      expect(s.dayNumber).toBe(2);
    });

    it("does not change weather in Night Race mode", () => {
      const state = createInitialState(GAME_MODE.NIGHT_RACE, 1);
      state.weatherTimer = 1;
      const s = updateWeather(state);
      expect(s.weather).toBe(WEATHER.NIGHT);
    });

    it("does not change weather in Sprint mode", () => {
      const state = createInitialState(GAME_MODE.SPRINT, 1);
      state.weatherTimer = 1;
      const s = updateWeather(state);
      expect(s.weather).toBe(WEATHER.DAY);
    });

    it("decrements timer when not expired", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.weatherTimer = 100;
      const s = updateWeather(state);
      expect(s.weatherTimer).toBe(99);
    });
  });

  describe("updateZOffsets", () => {
    it("advances z-offset based on speed", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 500;
      state.p2.speed = 300;
      const s = updateZOffsets(state);
      expect(s.p1.zOffset).toBeGreaterThan(0);
      expect(s.p1.zOffset).toBeGreaterThan(s.p2.zOffset);
    });

    it("grows unbounded (no wrapping)", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 500;
      state.p1.zOffset = 65530;
      const s = updateZOffsets(state);
      expect(s.p1.zOffset).toBe(65530 + Math.round(500 / 50));
      expect(s.p1.zOffset).toBeGreaterThan(65536);
    });
  });

  describe("tickTimers", () => {
    it("decrements boost timer", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.boost = 10;
      const s = tickTimers(state);
      expect(s.p1.boost).toBe(9);
    });

    it("decrements cooldown timer", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.turboCooldown = 10;
      const s = tickTimers(state);
      expect(s.p1.turboCooldown).toBe(9);
    });

    it("decrements collision timer", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.collisionTimer = 10;
      const s = tickTimers(state);
      expect(s.p1.collisionTimer).toBe(9);
    });

    it("decrements game timer in timed modes", () => {
      const state = createInitialState(GAME_MODE.NIGHT_RACE, 1);
      state.phase = PHASE.RACING;
      const s = tickTimers(state);
      expect(s.gameTimer).toBe(10799);
    });

    it("does not decrement game timer in Classic mode", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.phase = PHASE.RACING;
      const s = tickTimers(state);
      expect(s.gameTimer).toBe(0);
    });

    it("does not go below zero", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.boost = 0;
      state.p1.turboCooldown = 0;
      state.p1.collisionTimer = 0;
      const s = tickTimers(state);
      expect(s.p1.boost).toBe(0);
      expect(s.p1.turboCooldown).toBe(0);
      expect(s.p1.collisionTimer).toBe(0);
    });
  });

  describe("checkGameOver", () => {
    it("finishes Classic after 3 days", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.phase = PHASE.RACING;
      state.dayNumber = MAX_DAYS + 1;
      const s = checkGameOver(state);
      expect(s.phase).toBe(PHASE.FINISHED);
    });

    it("does not finish Classic before 3 days", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.phase = PHASE.RACING;
      state.dayNumber = 2;
      const s = checkGameOver(state);
      expect(s.phase).toBe(PHASE.RACING);
    });

    it.each([
      ["Night Race", GAME_MODE.NIGHT_RACE],
      ["Sprint", GAME_MODE.SPRINT],
    ])("finishes %s when timer expires", (_name, mode) => {
      const s = checkGameOver(race({ mode, phase: PHASE.RACING, gameTimer: 0 }));
      expect(s.phase).toBe(PHASE.FINISHED);
    });

    it("does nothing if not in RACING phase", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.phase = PHASE.COUNTDOWN;
      state.dayNumber = 5;
      const s = checkGameOver(state);
      expect(s.phase).toBe(PHASE.COUNTDOWN);
    });
  });

  describe("determineWinner", () => {
    it.each([
      ["P1 wins with higher score", { score: 100 }, { score: 80 }, 1],
      ["P2 wins with higher score", { score: 50 }, { score: 75 }, 2],
      [
        "uses overtakes as tiebreaker",
        { score: 100, overtakes: 200 },
        { score: 100, overtakes: 180 },
        1,
      ],
      ["returns 0 for draw", { score: 100, overtakes: 200 }, { score: 100, overtakes: 200 }, 0],
    ])("%s", (_name, p1, p2, winner) => {
      expect(determineWinner(race({ p1, p2 }))).toBe(winner);
    });
  });

  describe("clearEvents", () => {
    it("resets events to 0", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.events = EVENT.COLLISION | EVENT.OVERTAKE_AI;
      const s = clearEvents(state);
      expect(s.events).toBe(0);
    });
  });

  describe("updateFuel — stationary no drain", () => {
    it("does not drain fuel at speed 0", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 0;
      const s = updateFuel(state, "p1");
      expect(s.p1.fuel).toBe(FUEL_MAX);
    });
  });

  describe("updateSlipstream — collision zone exclusion", () => {
    /** Both drivers on the middle lane, P1 `gap` behind P2. */
    const drafting = (gap) =>
      updateSlipstream(
        race({ p1: { lane: 1, zOffset: 100 }, p2: { lane: 1, zOffset: 100 + gap } }),
      );

    it("no slipstream when within collision zone", () => {
      // 20 apart, within collision zone (40)
      expect(drafting(20).p1.slipstream).toBe(0);
    });

    it("slipstream activates outside collision zone", () => {
      // 100 apart, outside collision zone
      expect(drafting(100).p1.slipstream).toBeGreaterThan(0);
    });
  });

  describe("updateFuelStations — fair capture", () => {
    it("player ahead captures fuel station when both in same lane", () => {
      const state = race({
        p1: { fuel: 500, lane: 1, speed: 400, zOffset: 50 }, // P1 behind
        p2: { fuel: 500, lane: 1, speed: 400, zOffset: 200 }, // P2 ahead
        fuelStations: [{ lane: 1, zPos: 10 }],
      });
      const s = updateFuelStations(state);
      expect(s.p2.fuel).toBe(500 + FUEL_STATION_REFILL); // P2 gets it (ahead)
      expect(s.p1.fuel).toBe(500); // P1 doesn't
    });
  });

  describe("checkOvertakes — fair credit", () => {
    it("only faster player gets AI overtake credit when both eligible", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 1);
      state.p1.speed = 600;
      state.p2.speed = 600;
      state.p1.zOffset = 200; // P1 ahead
      state.p2.zOffset = 100;
      const prevAiCars = [{ lane: 1, zPos: 20, speed: 30, type: 0 }];
      state.aiCars = [{ lane: 1, zPos: -10, speed: 30, type: 0 }];
      const s = checkOvertakes(state, prevAiCars);
      // Only one player should get credit (P1 is ahead)
      const totalOvertakes = s.p1.overtakes + s.p2.overtakes;
      expect(totalOvertakes).toBe(1);
      expect(s.p1.overtakes).toBe(1); // P1 ahead gets credit
    });
  });

  describe("packState — negative zPos clamping", () => {
    it("clamps negative AI car zPos to 0", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.aiCars = [{ lane: 0, zPos: -150, speed: 30, type: 1 }];
      const packed = packState(state);
      expect(packed.aiCars[0].zPos).toBe(0);
    });

    it("clamps negative fuel station zPos to 0", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.fuelStations = [{ lane: 1, zPos: -50 }];
      const packed = packState(state);
      expect(packed.fuelStations[0].zPos).toBe(0);
    });

    it("rounds fractional zPos values", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.aiCars = [{ lane: 0, zPos: 123.7, speed: 30, type: 1 }];
      const packed = packState(state);
      expect(packed.aiCars[0].zPos).toBe(124);
    });
  });

  describe("packState / unpackState", () => {
    it("round-trips player state", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.p1.speed = 500;
      state.p1.fuel = 750;
      state.p1.score = 42;
      const packed = packState(state);
      const unpacked = unpackState(packed);
      expect(unpacked.p1.speed).toBe(500);
      expect(unpacked.p1.fuel).toBe(750);
      expect(unpacked.p1.score).toBe(42);
    });

    it("round-trips AI cars", () => {
      const state = createInitialState(GAME_MODE.CLASSIC_DUEL, 42);
      state.aiCars = [
        { lane: 0, zPos: 500, speed: 30, type: 1 },
        { lane: 2, zPos: 1000, speed: 50, type: 2 },
      ];
      const packed = packState(state);
      expect(packed.aiCarCount).toBe(2);
      expect(packed.aiCars).toHaveLength(2);
    });
  });

  describe("stepTick", () => {
    const idle = { left: false, right: false, accel: false, brake: false, turbo: false };

    function racing() {
      return { ...createInitialState(GAME_MODE.CLASSIC_DUEL, 7), phase: PHASE.RACING };
    }

    it("clears last step's events and moves both drivers on their own keys", () => {
      const state = { ...racing(), events: EVENT.COLLISION };
      const { state: next } = stepTick(state, { ...idle, accel: true, right: true }, idle);

      expect(next.events & EVENT.COLLISION).toBe(0);
      expect(next.p1).toMatchObject({ speed: 3, targetLane: 2 });
      expect(next.p2).toMatchObject({ speed: 0, targetLane: 0 });
    });

    it("fires turbo on the press and not while the key stays down", () => {
      const state = racing();
      const turbo = { ...idle, turbo: true };

      const pressed = stepTick(state, turbo, idle);
      const held = stepTick(state, turbo, idle, pressed.turboHeld);

      expect(pressed.state.p1.boost).toBe(TURBO_DURATION - 1);
      expect(pressed.turboHeld).toEqual({ p1: true, p2: false });
      expect(held.state.p1.boost).toBe(0);
      expect(stepTick(state, idle, idle, pressed.turboHeld).turboHeld.p1).toBe(false);
    });
  });
});
