/**
 * Characters for specs to wear, and the way a spec makes one in the Space's
 * creator.
 *
 * A character is a creator recipe (`RetroHexChat.VirtualSpace.CharacterRecipe`):
 * body, skin, outfit and its two colours, hair and its colour, headwear and its
 * two colours, face item and its colour. The looks below are named so a spec reads as a story
 * ("ana walks in as the ranger") rather than as a string of digits, and they
 * are all different from one another, so two people in a room never wear the
 * same figure by accident.
 */
import { expect, Page } from "@playwright/test";

export const LOOKS = {
  // The tunic in crimson and gold, long brown hair: the catalog's default.
  wanderer: "c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0",
  // Navy tunic, the adventurer hat in leather and teal, bald under it.
  ranger: "c1.b-av.s-4.o-tun-8-6.h-0.w-adv-d-6.f-0",
  // The undershirt, no hair, the darkest skin.
  monk: "c1.b-av.s-7.o-bas-0-0.h-0.w-0.f-0",
  // Forest tunic with ivory trim, long blonde hair under a crimson hat.
  bard: "c1.b-av.s-1.o-tun-5-f.h-lng-5.w-adv-0-3.f-0",
  // A violet robe with gold trim, a wizard hat, long white hair and glasses.
  mage: "c1.b-av.s-0.o-rob-a-3.h-lng-8.w-wiz-a-3.f-gls-3",
  // A charcoal jacket over scarlet trousers, a mohawk and an eyepatch.
  rogue: "c1.b-av.s-5.o-jkt-e-1.h-mhk-1.w-0.f-eye-e",
  // Sky dress with a gold sash, an afro.
  scout: "c1.b-av.s-3.o-drs-7-3.h-afr-4.w-0.f-0",
  // The undershirt and the hat in gold and navy, long black hair, a beard.
  sailor: "c1.b-av.s-6.o-bas-0-0.h-lng-0.w-adv-3-8.f-brd-0",
} as const;

export type Look = keyof typeof LOOKS;

/** The recipe of a named look, or the recipe itself when given one. */
export function recipeOf(look: Look | string): string {
  return (LOOKS as Record<string, string>)[look] ?? look;
}

type Fields = {
  body: string;
  skin: number;
  outfit: string;
  primary: number;
  secondary: number;
  hair: string;
  hairColour: number;
  hat: string;
  hatPrimary: number;
  hatSecondary: number;
  face: string;
  faceColour: number;
};

function fields(recipe: string): Fields {
  const [, b, s, o, h, w, f] = recipe.split(".");
  const [outfit, primary, secondary] = o.slice(2).split("-");
  const [hair, hairColour = "0"] = h.slice(2).split("-");
  const [hat, hatPrimary = "0", hatSecondary = "0"] = w.slice(2).split("-");
  const [face, faceColour = "0"] = f.slice(2).split("-");
  const n = (c: string) => parseInt(c, 36);
  return {
    body: b.slice(2),
    skin: n(s.slice(2)),
    outfit,
    primary: n(primary),
    secondary: n(secondary),
    hair,
    hairColour: n(hairColour),
    hat,
    hatPrimary: n(hatPrimary),
    hatSecondary: n(hatSecondary),
    face,
    faceColour: n(faceColour),
  };
}

/**
 * Makes `look` in the creator on screen, the way a person does: a tab at a
 * time, a piece and its colours on each, and waits for the preview to carry
 * it. Does not enter.
 */
export async function buildCharacter(space: Page, look: Look | string) {
  const recipe = recipeOf(look);
  const f = fields(recipe);
  const tab = async (name: string) => {
    const key = space.getByTestId(`space-creator-tab-${name}`);
    await key.click();
    await expect(key).toHaveAttribute("aria-selected", "true");
  };
  // A choice is made once the server says so: the piece shows pressed, and
  // the colours it can be dyed in are on screen.
  const choose = async (field: string, value: string | number) => {
    const option = space.getByTestId(`space-creator-option-${field}-${value}`);
    await option.click();
    await expect(option).toHaveAttribute("aria-pressed", "true");
  };
  const swatch = async (field: string, value: number) => {
    const key = space.getByTestId(`space-creator-swatch-${field}-${value}`);
    await key.click();
    await expect(key).toHaveAttribute("aria-pressed", "true");
  };

  await tab("body");
  await choose("body", f.body);
  await tab("skin");
  await swatch("skin", f.skin);
  await tab("outfit");
  await choose("outfit", f.outfit);
  if (await space.getByTestId("space-creator-swatch-primary-0").count()) {
    await swatch("primary", f.primary);
  }
  if (await space.getByTestId("space-creator-swatch-secondary-0").count()) {
    await swatch("secondary", f.secondary);
  }
  await tab("hair");
  await choose("hair", f.hair);
  if (f.hair !== "0") await swatch("hair_colour", f.hairColour);
  await tab("hat");
  await choose("hat", f.hat);
  if (f.hat !== "0") {
    await swatch("hat_primary", f.hatPrimary);
    await swatch("hat_secondary", f.hatSecondary);
  }
  await tab("face");
  await choose("face", f.face);
  if (f.face !== "0") await swatch("face_colour", f.faceColour);
  await expect(space.getByTestId("space-creator-preview")).toHaveAttribute(
    "data-recipe",
    recipe,
  );
}

/** Makes `look` and walks in with it. */
export async function enterAs(space: Page, look: Look | string) {
  await buildCharacter(space, look);
  await space.getByTestId("space-creator-enter").click();
}
