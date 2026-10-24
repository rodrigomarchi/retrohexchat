import { describe, it, expect } from "vitest";
import { recordingCanvas } from "./recording_canvas.js";

describe("recording canvas", () => {
  it("records calls and assignments in order", () => {
    const canvas = recordingCanvas(320, 200);
    const ctx = canvas.getContext("2d");

    ctx.fillStyle = "#000";
    ctx.fillRect(0, 0, 320, 200);
    ctx.save();
    ctx.font = "bold 18px monospace";
    ctx.fillText("GO", 160, 100);
    ctx.restore();

    expect(canvas.log).toEqual([
      ["fillStyle", "=", "#000"],
      ["fillRect", 0, 0, 320, 200],
      ["save"],
      ["font", "=", "bold 18px monospace"],
      ["fillText", "GO", 160, 100],
      ["restore"],
    ]);
  });

  it("reads back what was assigned", () => {
    const ctx = recordingCanvas(10, 10).getContext("2d");
    ctx.globalAlpha = 0.5;
    expect(ctx.globalAlpha).toBe(0.5);
  });

  it("records gradients as objects with their own stops", () => {
    const canvas = recordingCanvas(10, 10);
    const ctx = canvas.getContext("2d");
    const gradient = ctx.createRadialGradient(5, 5, 0, 5, 5, 5);
    gradient.addColorStop(0, "red");
    ctx.fillStyle = gradient;

    expect(canvas.log).toEqual([
      ["createRadialGradient", 5, 5, 0, 5, 5, 5],
      ["g1.addColorStop", 0, "red"],
      ["fillStyle", "=", "g1"],
    ]);
  });

  it("measures text by its length, so layouts that depend on it are stable", () => {
    const ctx = recordingCanvas(10, 10).getContext("2d");
    expect(ctx.measureText("ABCD").width).toBe(32);
  });

  it("can start a fresh log, keeping the context's state", () => {
    const canvas = recordingCanvas(10, 10);
    const ctx = canvas.getContext("2d");
    ctx.fillStyle = "red";
    canvas.clearLog();
    ctx.fillRect(1, 2, 3, 4);

    expect(canvas.log).toEqual([["fillRect", 1, 2, 3, 4]]);
    expect(ctx.fillStyle).toBe("red");
  });

  it("stops logging while switched off, keeping the context's state", () => {
    const canvas = recordingCanvas(10, 10);
    const ctx = canvas.getContext("2d");
    canvas.recording = false;
    ctx.fillStyle = "blue";
    ctx.fillRect(0, 0, 1, 1);
    canvas.recording = true;
    ctx.fillRect(2, 2, 1, 1);

    expect(canvas.log).toEqual([["fillRect", 2, 2, 1, 1]]);
    expect(ctx.fillStyle).toBe("blue");
  });
});
