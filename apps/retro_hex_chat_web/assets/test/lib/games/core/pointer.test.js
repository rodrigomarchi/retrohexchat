import { describe, it, expect } from "vitest";
import { createGesture, toCanvasPoint } from "../../../../js/lib/games/core/pointer.js";

const rect = (left, top, width, height) => ({ left, top, width, height });

describe("toCanvasPoint", () => {
  it("scales a point on a canvas drawn at twice its size", () => {
    expect(toCanvasPoint(rect(0, 0, 1280, 960), 640, 480, 640, 480)).toEqual({ x: 320, y: 240 });
  });

  it("subtracts where the element sits on the page", () => {
    expect(toCanvasPoint(rect(100, 50, 640, 480), 640, 480, 110, 60)).toEqual({ x: 10, y: 10 });
  });

  it("leaves out the bands at the sides of a wide element", () => {
    // 1000×480 holds a 640×480 picture with 180 px of band on each side.
    const wide = rect(0, 0, 1000, 480);
    expect(toCanvasPoint(wide, 640, 480, 180, 100)).toEqual({ x: 0, y: 100 });
    expect(toCanvasPoint(wide, 640, 480, 819, 100)).toEqual({ x: 639, y: 100 });
    expect(toCanvasPoint(wide, 640, 480, 179, 100)).toBeNull();
    expect(toCanvasPoint(wide, 640, 480, 821, 100)).toBeNull();
  });

  it("leaves out the bands above and below a tall element", () => {
    // 640×800 holds the picture with 160 px of band above and below.
    const tall = rect(0, 0, 640, 800);
    expect(toCanvasPoint(tall, 640, 480, 10, 160)).toEqual({ x: 10, y: 0 });
    expect(toCanvasPoint(tall, 640, 480, 10, 159)).toBeNull();
    expect(toCanvasPoint(tall, 640, 480, 10, 641)).toBeNull();
  });

  it("can follow a point out of the picture, for a drag that leaves it", () => {
    const wide = rect(0, 0, 1000, 480);
    expect(toCanvasPoint(wide, 640, 480, 100, 100, { clamp: false })).toEqual({ x: -80, y: 100 });
  });

  it("answers nothing for an element with no size yet", () => {
    expect(toCanvasPoint(rect(0, 0, 0, 0), 640, 480, 0, 0)).toBeNull();
  });
});

describe("createGesture", () => {
  const feed = (gesture, events) => events.flatMap((event) => gesture(event));
  const at = (type, x, y) => ({ type, x, y });

  it("reads a press that barely moves as a tap", () => {
    const gesture = createGesture({ slop: 6 });
    expect(feed(gesture, [at("down", 10, 10), at("move", 15, 10), at("up", 15, 10)])).toEqual([
      { type: "tap", x: 10, y: 10 },
    ]);
  });

  it("reads a press that moves past the slop as a drag", () => {
    const gesture = createGesture({ slop: 6 });
    expect(
      feed(gesture, [at("down", 10, 10), at("move", 17, 10), at("move", 30, 12), at("up", 31, 12)]),
    ).toEqual([
      { type: "dragStart", x: 10, y: 10 },
      { type: "dragMove", x: 17, y: 10 },
      { type: "dragMove", x: 30, y: 12 },
      { type: "drop", x: 31, y: 12 },
    ]);
  });

  it("cancels a drag the browser takes away", () => {
    const gesture = createGesture({ slop: 6 });
    expect(feed(gesture, [at("down", 0, 0), at("move", 20, 0), { type: "cancel" }])).toEqual([
      { type: "dragStart", x: 0, y: 0 },
      { type: "dragMove", x: 20, y: 0 },
      { type: "dragCancel" },
    ]);
  });

  it("forgets a press that is cancelled before it moved", () => {
    const gesture = createGesture({ slop: 6 });
    expect(feed(gesture, [at("down", 0, 0), { type: "cancel" }, at("up", 0, 0)])).toEqual([]);
  });

  it("reads a press held still for its ticks as a hold, and its release as nothing", () => {
    const gesture = createGesture({ slop: 6, holdTicks: 3 });
    const ticks = (n) => Array.from({ length: n }, () => gesture.tick()).flat();
    expect(gesture(at("down", 10, 10))).toEqual([]);
    expect(ticks(2)).toEqual([]);
    expect(feed(gesture, [at("move", 12, 11)])).toEqual([]);
    expect(ticks(1)).toEqual([{ type: "hold", x: 10, y: 10 }]);
    expect(ticks(5)).toEqual([]);
    expect(feed(gesture, [at("up", 12, 11)])).toEqual([]);
  });

  it("never holds a press that moved past the slop, nor one released in time", () => {
    const gesture = createGesture({ slop: 6, holdTicks: 3 });
    const ticks = (n) => Array.from({ length: n }, () => gesture.tick()).flat();
    gesture(at("down", 10, 10));
    gesture(at("move", 30, 10));
    expect(ticks(5)).toEqual([]);
    gesture(at("up", 30, 10));
    gesture(at("down", 10, 10));
    ticks(2);
    expect(feed(gesture, [at("up", 10, 10)])).toEqual([{ type: "tap", x: 10, y: 10 }]);
    expect(ticks(5)).toEqual([]);
  });

  it("tells which button made a tap, when the press says", () => {
    const gesture = createGesture({ slop: 6 });
    expect(feed(gesture, [{ ...at("down", 1, 2), button: "secondary" }, at("up", 1, 2)])).toEqual([
      { type: "tap", x: 1, y: 2, button: "secondary" },
    ]);
  });

  it("never holds a press that says it does not", () => {
    const gesture = createGesture({ slop: 6, holdTicks: 3 });
    gesture({ ...at("down", 1, 1), hold: false });
    expect(Array.from({ length: 10 }, () => gesture.tick()).flat()).toEqual([]);
    expect(gesture(at("up", 1, 1))).toEqual([{ type: "tap", x: 1, y: 1 }]);
  });

  it("holds nothing without hold ticks", () => {
    const gesture = createGesture({ slop: 6 });
    gesture(at("down", 0, 0));
    expect(Array.from({ length: 100 }, () => gesture.tick()).flat()).toEqual([]);
  });

  it("ignores moves and releases with no press", () => {
    const gesture = createGesture({ slop: 6 });
    expect(feed(gesture, [at("move", 5, 5), at("up", 5, 5)])).toEqual([]);
  });
});
