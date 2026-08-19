import { t } from "../i18n.js";

/**
 * The remote-tile view for the conference — a controller that owns the DOM.
 *
 * It holds the map of remote video tiles keyed by media-stream id, creates a
 * tile (from the server-rendered template or a bare div) when a new stream
 * arrives, and answers the tile queries the hook needs to apply participant,
 * track, quality, layout and stats state. It knows nothing about the peer
 * connection: the hook attaches the live MediaStream to the tile's `<video>` and
 * decides what a focus click means, delivered through the `onToggleFocus` port.
 *
 * The tile datasets this stamps (`data-stream-id`, `data-track-source`,
 * `data-local`, `data-quality-level`, …) are the contract the group-call E2E
 * suite asserts on, so their names and defaults are load-bearing.
 */
export function createTileView(el, { onToggleFocus } = {}) {
  const remoteTiles = new Map();

  function videoGrid() {
    return el.querySelector("[data-group-call-video-grid]") || el;
  }

  function fromTemplate() {
    const template = el.querySelector("[data-group-call-remote-tile-template]");
    const node = template?.content?.firstElementChild?.cloneNode(true);
    return node instanceof HTMLElement ? node : null;
  }

  function ensureNameplate(tile) {
    if (tile.querySelector("[data-group-call-tile-name]")) return;

    const nameplate = document.createElement("div");
    nameplate.className = "group-call-video-tile__nameplate";

    const name = document.createElement("span");
    name.className = "truncate font-bold";
    name.dataset.groupCallTileName = "";
    name.textContent = t("Remote");

    nameplate.append(name);
    tile.appendChild(nameplate);
  }

  function createTile(streamId) {
    const tile = fromTemplate() || document.createElement("div");
    tile.classList.add("group-call-video-tile", "group-call-video-tile--remote");
    tile.dataset.groupCallVideoTile = "";
    tile.dataset.streamId = streamId;
    tile.dataset.mediaAudio = "true";
    tile.dataset.mediaVideo = "true";
    tile.dataset.local = "false";
    tile.dataset.activeSpeaker = "false";
    tile.dataset.qualityLevel = "unknown";
    tile.dataset.pinned = "false";
    tile.tabIndex = 0;
    tile.role = "button";
    tile.dataset.testid = `group-call-remote-tile-${streamId}`;
    tile.addEventListener("click", () => onToggleFocus?.(tile));
    tile.addEventListener("keydown", (event) => {
      if (event.key !== "Enter" && event.key !== " ") return;
      event.preventDefault();
      onToggleFocus?.(tile);
    });
    ensureNameplate(tile);
    return tile;
  }

  return {
    /** Find-or-create the tile for a stream, appending a new one to the grid. */
    ensure(streamId) {
      const host = videoGrid();
      let tile = remoteTiles.get(streamId) || host.querySelector(`[data-stream-id="${streamId}"]`);
      if (!tile) {
        tile = createTile(streamId);
        host.appendChild(tile);
        remoteTiles.set(streamId, tile);
      }
      return tile;
    },

    get(streamId) {
      return remoteTiles.get(streamId) || null;
    },

    /**
     * Remove every tile bound to a participant from both the DOM and the map.
     * @returns {string[]} the stream ids that were removed
     */
    removeByParticipant(participantId) {
      const removed = [];
      for (const [streamId, tile] of remoteTiles) {
        if (tile.dataset.participantId !== participantId) continue;
        tile.remove();
        remoteTiles.delete(streamId);
        removed.push(streamId);
      }
      return removed;
    },

    /** Every tile currently assigned to a participant, from the live DOM. */
    tilesForParticipant(participantId) {
      return Array.from(el.querySelectorAll("[data-group-call-video-tile]")).filter(
        (tile) => tile.dataset.participantId === String(participantId),
      );
    },

    /** Every remote tile, from the map and the DOM, de-duplicated. */
    remoteTileElements() {
      const mapped = Array.from(remoteTiles.values());
      const dom = Array.from(
        el.querySelectorAll('[data-group-call-video-tile][data-local="false"]'),
      );
      return Array.from(new Set([...mapped, ...dom]));
    },

    /** Remove all tiles from the DOM and empty the map (a rejoin resets tiles). */
    removeAll() {
      for (const tile of remoteTiles.values()) tile.remove();
      remoteTiles.clear();
    },

    get size() {
      return remoteTiles.size;
    },

    /** Empty the map without touching the DOM (teardown, where the DOM is gone). */
    clear() {
      remoteTiles.clear();
    },
  };
}
