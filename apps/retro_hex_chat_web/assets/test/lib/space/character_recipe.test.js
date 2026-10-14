import { describe, expect, it } from "vitest";

import {
  colourKey,
  paletteEntries,
  parseRecipe,
  planLayers,
  recipeString,
} from "../../../js/lib/space/character_recipe.js";
import { CATALOG } from "./character_fixture.js";

describe("character recipe", () => {
  it("reads every field of a recipe", () => {
    expect(parseRecipe("c1.b-av.s-1.o-tun-2-3.h-lng-2.w-adv-1-0.f-0", CATALOG)).toEqual({
      body: "av",
      skin: 1,
      outfit: "tun",
      primary: 2,
      secondary: 3,
      hair: "lng",
      hairColour: 2,
      hat: "adv",
      hatPrimary: 1,
      hatSecondary: 0,
      face: null,
      faceColour: 0,
    });
  });

  it("reads a face item's colour from the palette its channel names", () => {
    expect(parseRecipe("c1.b-av.s-0.o-bas-0-0.h-0.w-0.f-brd-2", CATALOG)).toMatchObject({
      face: "brd",
      faceColour: 2,
    });
    // a beard takes a hair colour (three of them here), glasses a cloth one (four)
    expect(parseRecipe("c1.b-av.s-0.o-bas-0-0.h-0.w-0.f-brd-3", CATALOG)).toBeNull();
    expect(parseRecipe("c1.b-av.s-0.o-bas-0-0.h-0.w-0.f-gls-3", CATALOG)).toMatchObject({
      face: "gls",
      faceColour: 3,
    });
  });

  it("composes nothing it cannot draw", () => {
    for (const bad of [
      "knight",
      "c1.b-av.s-9.o-tun-0-0.h-0.w-0.f-0",
      "c1.b-av.s-0.o-cape-0-0.h-0.w-0.f-0",
      "c1.b-av.s-0.o-tun-0-0.h-afro-1.w-0.f-0",
      "c1.b-av.s-0.o-tun-0-0.h-0.w-crown-0-0.f-0",
      "c1.b-av.s-0.o-tun-0-0.h-0.w-0.f-mask-0",
      "c1.b-av.s-0.o-tun-0-0.h-0.w-0.f-brd",
      "c1.b-av.s-0.o-tun-0-0.h-0.w-0.f-brd-0-0",
      // what the server refuses too: a second spelling, a prototype key, extra fields
      "c1.b-av.s-0.o-bas-3-0.h-0.w-0.f-0",
      "c1.b-av.s-0.o-tun-0-0.h-0.w-constructor-0-0.f-0",
      "c1.b-av.s-0.o-tun-0-0-1.h-0.w-0.f-0",
      null,
    ]) {
      expect(parseRecipe(bad, CATALOG)).toBeNull();
    }
  });

  it("writes one spelling per character", () => {
    const parsed = parseRecipe("c1.b-av.s-1.o-bas-0-0.h-0.w-0.f-0", CATALOG);
    expect(recipeString({ ...parsed, primary: 3 }, CATALOG)).toBe(
      "c1.b-av.s-1.o-bas-0-0.h-0.w-0.f-0",
    );
  });

  it("plans the pieces base, face, hair, hat with each one's colours", () => {
    expect(planLayers("c1.b-av.s-1.o-tun-2-3.h-lng-2.w-adv-1-0.f-gls-3", CATALOG)).toEqual([
      { layer: "base-av-tun", kind: "base", colours: { skin: 1, primary: 2, secondary: 3 } },
      { layer: "face-gls", kind: "face", colours: { primary: 3 } },
      { layer: "hair-lng", kind: "hair", colours: { hair: 2 } },
      { layer: "hat-adv", kind: "hat", colours: { primary: 1, secondary: 0 } },
    ]);
  });

  it("writes a colour's ramp over the shades the piece keeps for its channel", () => {
    const layer = CATALOG.layers["base-av-tun"];
    expect(paletteEntries(layer, { skin: 1, primary: 3, secondary: 0 }, CATALOG)).toEqual([
      [1, [33, 0, 0]],
      [2, [33, 1, 0]],
      [3, [30, 0, 0]],
      [4, [30, 1, 0]],
      [5, [11, 0, 0]],
      [6, [11, 1, 0]],
    ]);
    expect(colourKey(layer, { skin: 1, primary: 3, secondary: 0 })).toBe(
      "primary3,secondary0,skin1",
    );
  });
});
