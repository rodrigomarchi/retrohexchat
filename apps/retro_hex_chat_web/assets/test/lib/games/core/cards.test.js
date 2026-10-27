import { describe, it, expect, vi } from "vitest";
import {
  CARD_ATLAS_URL,
  DECK,
  MINI_CARD,
  createCardAtlasLoader,
  faceOf,
  spiderDeck,
  drawCard,
  isRed,
  rankOf,
  shuffle,
  suitOf,
} from "../../../../js/lib/games/core/cards.js";
import { createRng } from "../../../../js/lib/games/core/rng.js";
import { recordingCanvas } from "../../../support/games/recording_canvas.js";

/** An atlas description with every card and back where a loader expects it. */
function atlasJson({ faces = 52, backs = 4 } = {}) {
  return {
    image: "cards.webp",
    card: { width: 64, height: 88 },
    faces: Array.from({ length: faces }, (_, id) => ({
      x: (id % 13) * 128,
      y: Math.floor(id / 13) * 176,
      w: 128,
      h: 176,
    })),
    backs: Array.from({ length: backs }, (_, i) => ({ x: i * 128, y: 704, w: 128, h: 176 })),
  };
}

function fakeLoader(json = atlasJson()) {
  const fetchJson = vi.fn(async () => json);
  const loadImage = vi.fn(async (src) => ({ src }));
  return { fetchJson, loadImage, load: createCardAtlasLoader({ fetchJson, loadImage }) };
}

describe("the atlas's address", () => {
  it("carries the version of what it serves, so a new deck is never read from an old cache", () => {
    expect(CARD_ATLAS_URL).toMatch(/^\/images\/games\/cards\/cards\.json\?vsn=[0-9a-f]{12}$/);
  });

  it("keeps the picture's own version when it reads the description", async () => {
    const { loadImage, load } = fakeLoader({ ...atlasJson(), image: "cards.png?vsn=abc" });
    await load("/images/games/cards/cards.json?vsn=123");
    expect(loadImage).toHaveBeenCalledWith("/images/games/cards/cards.png?vsn=abc");
  });
});

describe("the deck", () => {
  it("holds 52 distinct cards, suit by suit from the ace to the king", () => {
    expect(DECK).toHaveLength(52);
    expect(new Set(DECK).size).toBe(52);
    expect([suitOf(0), rankOf(0)]).toEqual([0, 1]);
    expect([suitOf(12), rankOf(12)]).toEqual([0, 13]);
    expect([suitOf(13), rankOf(13)]).toEqual([1, 1]);
    expect([suitOf(51), rankOf(51)]).toEqual([3, 13]);
  });

  it("calls hearts and diamonds red, spades and clubs black", () => {
    expect([0, 13, 26, 39].map(isRed)).toEqual([false, true, true, false]);
  });
});

describe("shuffle", () => {
  it("deals a permutation of the deck", () => {
    const shuffled = shuffle(DECK, createRng(42).next);
    expect(shuffled).toHaveLength(52);
    expect([...shuffled].sort((a, b) => a - b)).toEqual([...DECK]);
    expect(shuffled).not.toEqual([...DECK]);
  });

  it("deals the same order for the same seed, another for another", () => {
    expect(shuffle(DECK, createRng(42).next)).toEqual(shuffle(DECK, createRng(42).next));
    expect(shuffle(DECK, createRng(42).next)).not.toEqual(shuffle(DECK, createRng(43).next));
  });

  it("leaves the deck it was given as it was", () => {
    const deck = [...DECK];
    shuffle(deck, createRng(7).next);
    expect(deck).toEqual([...DECK]);
  });
});

describe("createCardAtlasLoader", () => {
  it("reads the description, then its image beside it", async () => {
    const { load, loadImage } = fakeLoader();
    const atlas = await load("/images/games/hex_solitaire/cards.json");

    expect(loadImage).toHaveBeenCalledWith("/images/games/hex_solitaire/cards.webp");
    expect(atlas.card).toEqual({ width: 64, height: 88 });
    expect(atlas.faces).toHaveLength(52);
    expect(atlas.image).toEqual({ src: "/images/games/hex_solitaire/cards.webp" });
  });

  it("loads an atlas once however many ask for it", async () => {
    const { load, fetchJson } = fakeLoader();
    const [a, b] = await Promise.all([load("/a/cards.json"), load("/a/cards.json")]);

    expect(a).toBe(b);
    expect(fetchJson).toHaveBeenCalledTimes(1);
  });

  it("refuses an atlas that misses a face or a back", async () => {
    await expect(fakeLoader(atlasJson({ faces: 51 })).load("/x.json")).rejects.toThrow(/52 faces/);
    await expect(fakeLoader(atlasJson({ backs: 3 })).load("/x.json")).rejects.toThrow(/4 backs/);
  });
});

describe("two decks for Spider", () => {
  const ranks = (cards) => cards.map((card) => rankOf(faceOf(card)));
  const suits = (cards) => new Set(cards.map((card) => suitOf(faceOf(card))));

  it("deals 104 distinct cards, eight of each rank, in the suits of the variant", () => {
    for (const count of [1, 2, 4]) {
      const cards = spiderDeck(count);
      expect(cards).toHaveLength(104);
      expect(new Set(cards).size).toBe(104);
      for (let rank = 1; rank <= 13; rank++) {
        expect(ranks(cards).filter((r) => r === rank)).toHaveLength(8);
      }
      expect(suits(cards).size).toBe(count);
    }
    expect([...suits(spiderDeck(1))]).toEqual([0]);
    expect([...suits(spiderDeck(2))].sort()).toEqual([0, 1]);
  });

  it("draws each card as its face: two alike look alike", () => {
    const fours = spiderDeck(4).filter((card) => faceOf(card) === 14);
    expect(fours).toHaveLength(2);
    expect(faceOf(14)).toBe(14);
  });
});

describe("drawCard", () => {
  const atlas = { ...atlasJson(), image: { src: "cards.webp" } };
  const drawn = (draw) => {
    const canvas = recordingCanvas(640, 480);
    canvas.clearLog();
    draw(canvas.getContext("2d"));
    return canvas.log.filter(
      ([op]) => op === "drawImage" || op === "fillRect" || op === "strokeRect",
    );
  };

  it("cuts a face out of the atlas and draws it at the card's size", () => {
    const [call] = drawn((ctx) => drawCard(ctx, atlas, 14, 100, 50));
    const face = atlas.faces[14];
    expect(call).toEqual([
      "drawImage",
      atlas.image,
      face.x,
      face.y,
      face.w,
      face.h,
      100,
      50,
      64,
      88,
    ]);
  });

  it("draws the back it is asked for when the card lies face down", () => {
    const [call] = drawn((ctx) => drawCard(ctx, atlas, 14, 0, 0, { faceUp: false, back: 2 }));
    const back = atlas.backs[2];
    expect(call.slice(1, 6)).toEqual([atlas.image, back.x, back.y, back.w, back.h]);
  });

  it("draws a mini card from the atlas's minis, at their size", () => {
    const mini = {
      ...atlas,
      mini: {
        card: { width: 44, height: 62 },
        faces: atlas.faces.map((r) => ({ ...r, y: r.y + 1000 })),
        backs: atlas.backs.map((r) => ({ ...r, y: r.y + 1000 })),
      },
    };
    const [face] = drawn((ctx) => drawCard(ctx, mini, 14, 5, 6, { size: "mini" }));
    expect(face.slice(2, 4)).toEqual([mini.mini.faces[14].x, mini.mini.faces[14].y]);
    expect(face.slice(6)).toEqual([5, 6, 44, 62]);
    const [back] = drawn((ctx) =>
      drawCard(ctx, mini, 14, 0, 0, { size: "mini", faceUp: false, back: 1 }),
    );
    expect(back.slice(3, 4)).toEqual([mini.mini.backs[1].y]);
  });

  it("stands in a plain mini card while the atlas has no minis", () => {
    const [plain] = drawn((ctx) => drawCard(ctx, atlas, 14, 5, 6, { size: "mini" }));
    expect(plain).toEqual(["fillRect", 5, 6, MINI_CARD.width, MINI_CARD.height]);
  });

  it("draws a card that can still be played when the atlas is missing", () => {
    const canvas = recordingCanvas(640, 480);
    canvas.clearLog();
    drawCard(canvas.getContext("2d"), null, 14, 10, 20);
    const face = canvas.log;
    expect(face.find(([op]) => op === "fillRect").slice(1)).toEqual([10, 20, 64, 88]);
    expect(face.filter(([op]) => op === "fillText").map(([, text]) => text)).toEqual(["2♥"]);

    canvas.clearLog();
    drawCard(canvas.getContext("2d"), null, 14, 10, 20, { faceUp: false });
    expect(canvas.log.filter(([op]) => op === "fillText")).toEqual([]);
    expect(canvas.log.filter(([op]) => op === "fillRect")).toHaveLength(2);
  });
});
