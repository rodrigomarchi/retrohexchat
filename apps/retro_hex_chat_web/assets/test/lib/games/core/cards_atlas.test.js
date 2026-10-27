import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it, vi } from "vitest";
import { createCardAtlasLoader } from "../../../../js/lib/games/core/cards.js";

// The platform's deck, as `scripts/card_deck.py` writes it.
const DIR = join(
  dirname(fileURLToPath(import.meta.url)),
  "../../../../../priv/static/images/games/cards",
);
const description = JSON.parse(readFileSync(join(DIR, "cards.json"), "utf8"));
// The PNG's own size, from its header: width and height are the IHDR's first two words.
const png = readFileSync(join(DIR, description.image));
const sheet = { width: png.readUInt32BE(16), height: png.readUInt32BE(20) };

describe("the platform's card atlas", () => {
  it("holds every picture a card game needs, at the card's size", () => {
    expect(description.card).toEqual({ width: 64, height: 88 });
    expect(description.faces).toHaveLength(52);
    expect(description.jokers).toHaveLength(2);
    expect(description.backs).toHaveLength(4);
    expect(description.shadows).toHaveLength(2);
    for (const region of [...description.faces, ...description.jokers, ...description.backs]) {
      expect([region.w, region.h]).toEqual([64, 88]);
    }
  });

  it("cuts every region from inside its picture", () => {
    const all = [
      ...description.faces,
      ...description.jokers,
      ...description.backs,
      ...description.shadows,
    ];
    for (const r of all) {
      expect(r.x >= 0 && r.y >= 0).toBe(true);
      expect(r.x + r.w <= sheet.width && r.y + r.h <= sheet.height).toBe(true);
    }
  });

  it("is accepted by the loader every card game uses", async () => {
    const load = createCardAtlasLoader({
      fetchJson: async () => description,
      loadImage: vi.fn(async (src) => ({ src })),
    });
    const atlas = await load("/images/games/cards/cards.json");
    expect(atlas.image).toEqual({ src: "/images/games/cards/cards.png" });
  });
});
