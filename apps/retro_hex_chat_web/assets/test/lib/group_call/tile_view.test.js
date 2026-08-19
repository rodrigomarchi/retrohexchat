import { createTileView } from "../../../js/lib/group_call/tile_view.js";

function grid({ withTemplate = false } = {}) {
  const el = document.createElement("div");
  el.innerHTML = `
    <div data-group-call-video-grid>
      ${
        withTemplate
          ? `<template data-group-call-remote-tile-template>
               <div class="group-call-video-tile group-call-video-tile--remote" data-group-call-video-tile data-local="false">
                 <span data-group-call-tile-name>Remote</span>
                 <span data-test-icon="remote-microphone"></span>
               </div>
             </template>`
          : ""
      }
    </div>
  `;
  document.body.appendChild(el);
  return el;
}

describe("createTileView", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  describe("ensure", () => {
    it("creates a bare remote tile with the load-bearing datasets and appends it to the grid", () => {
      const el = grid();
      const view = createTileView(el, {});
      const tile = view.ensure("s1");

      expect(tile.dataset.streamId).toBe("s1");
      expect(tile.dataset.local).toBe("false");
      expect(tile.dataset.qualityLevel).toBe("unknown");
      expect(tile.dataset.trackSource).toBe(undefined); // set later by the hook
      expect(tile.dataset.testid).toBe("group-call-remote-tile-s1");
      expect(tile.classList.contains("group-call-video-tile--remote")).toBe(true);
      expect(el.querySelector("[data-group-call-video-grid]").contains(tile)).toBe(true);
      expect(view.size).toBe(1);
    });

    it("clones the server template when present and adds a nameplate", () => {
      const el = grid({ withTemplate: true });
      const view = createTileView(el, {});
      const tile = view.ensure("s1");
      expect(tile.querySelector('[data-test-icon="remote-microphone"]')).not.toBeNull();
      expect(tile.querySelector("[data-group-call-tile-name]")).not.toBeNull();
    });

    it("returns the existing tile for a known stream instead of a second one", () => {
      const el = grid();
      const view = createTileView(el, {});
      const first = view.ensure("s1");
      const second = view.ensure("s1");
      expect(second).toBe(first);
      expect(view.size).toBe(1);
    });

    it("adopts a tile already in the DOM for that stream id without duplicating", () => {
      const el = grid();
      const existing = document.createElement("div");
      existing.dataset.groupCallVideoTile = "";
      existing.dataset.streamId = "s1";
      el.querySelector("[data-group-call-video-grid]").appendChild(existing);
      const view = createTileView(el, {});
      expect(view.ensure("s1")).toBe(existing);
    });
  });

  it("routes a tile click and Enter/Space keydown to onToggleFocus", () => {
    const el = grid();
    const onToggleFocus = vi.fn();
    const view = createTileView(el, { onToggleFocus });
    const tile = view.ensure("s1");

    tile.dispatchEvent(new MouseEvent("click", { bubbles: true }));
    tile.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
    tile.dispatchEvent(new KeyboardEvent("keydown", { key: "x", bubbles: true }));
    expect(onToggleFocus).toHaveBeenCalledTimes(2);
    expect(onToggleFocus).toHaveBeenCalledWith(tile);
  });

  describe("removeByParticipant", () => {
    it("removes only the participant's tiles from the DOM and map, returning their stream ids", () => {
      const el = grid();
      const view = createTileView(el, {});
      const a = view.ensure("sa");
      a.dataset.participantId = "p1";
      const b = view.ensure("sb");
      b.dataset.participantId = "p2";

      const removed = view.removeByParticipant("p1");
      expect(removed).toEqual(["sa"]);
      expect(a.isConnected).toBe(false);
      expect(view.get("sa")).toBe(null);
      expect(view.get("sb")).toBe(b);
      expect(view.size).toBe(1);
    });
  });

  describe("queries", () => {
    it("tilesForParticipant reads the live DOM including tiles not in the map", () => {
      const el = grid();
      const view = createTileView(el, {});
      const mapped = view.ensure("s1");
      mapped.dataset.participantId = "p1";

      const strayTile = document.createElement("div");
      strayTile.dataset.groupCallVideoTile = "";
      strayTile.dataset.participantId = "p1";
      el.querySelector("[data-group-call-video-grid]").appendChild(strayTile);

      expect(view.tilesForParticipant("p1")).toHaveLength(2);
      expect(view.tilesForParticipant("p2")).toHaveLength(0);
    });

    it("remoteTileElements de-duplicates map and DOM tiles and excludes local tiles", () => {
      const el = grid();
      const view = createTileView(el, {});
      view.ensure("s1");

      const local = document.createElement("div");
      local.dataset.groupCallVideoTile = "";
      local.dataset.local = "true";
      el.querySelector("[data-group-call-video-grid]").appendChild(local);

      const remotes = view.remoteTileElements();
      expect(remotes).toHaveLength(1);
      expect(remotes.every((t) => t.dataset.local !== "true")).toBe(true);
    });
  });

  it("removeAll clears the DOM and the map; clear empties only the map", () => {
    const el = grid();
    const view = createTileView(el, {});
    const a = view.ensure("s1");
    view.removeAll();
    expect(a.isConnected).toBe(false);
    expect(view.size).toBe(0);

    const b = view.ensure("s2");
    view.clear();
    expect(view.size).toBe(0);
    expect(b.isConnected).toBe(true); // clear() does not touch the DOM
  });
});
