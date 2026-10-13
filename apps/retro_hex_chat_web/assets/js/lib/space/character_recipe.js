/**
 * A Space character recipe, read against the creator's catalog.
 *
 * A character is a short string naming catalog pieces and palette colours
 * (`RetroHexChat.VirtualSpace.CharacterRecipe` is the authority):
 *
 *     c1.b-av.s-2.o-tun-0-3.h-lng-2.w-0.f-0
 *
 * body, skin colour, outfit and its two colours, hairstyle and colour (`h-0`
 * bald), headwear and its two colours (`w-0` none), face item (`f-0` none).
 * Colours are one base-36 digit each. This module only reads and writes the
 * string; the server decides what is valid, and `parseRecipe` here returns null
 * for anything it cannot compose rather than guessing.
 *
 * @module space/character_recipe
 */

const DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz";
const MAX_LENGTH = 64;
const own = (object, key) => typeof key === "string" && Object.hasOwn(object ?? {}, key);

const digit = (n) => DIGITS[n] ?? "0";
const index = (c) => DIGITS.indexOf(c);

/**
 * @param {string} recipe
 * @param {object} catalog the web catalog (`items`, `palettes`)
 * @returns {object|null} {body, skin, outfit, primary, secondary, hair,
 *   hairColour, hat, hatPrimary, hatSecondary, face}
 */
export function parseRecipe(recipe, catalog) {
  if (typeof recipe !== "string" || !catalog || recipe.length > MAX_LENGTH) return null;
  const parsed = readRecipe(recipe, catalog);
  // One character, one spelling, as the server holds it to.
  return parsed && recipeString(parsed, catalog) === recipe ? parsed : null;
}

function readRecipe(recipe, catalog) {
  const parts = recipe.split(".");
  if (parts.length !== 7 || parts[0] !== "c1") return null;
  const [, b, s, o, h, w, f] = parts;
  const items = catalog.items;
  const sizes = { skin: catalog.palettes.skin.length, hair: catalog.palettes.hair.length };
  sizes.fabric = catalog.palettes.fabric.length;
  const colour = (c, palette) => {
    const i = index(c);
    return c?.length === 1 && i >= 0 && i < sizes[palette] ? i : null;
  };

  if (!b.startsWith("b-") || !s.startsWith("s-") || !o.startsWith("o-")) return null;
  const body = b.slice(2);
  const skin = colour(s.slice(2), "skin");
  const outfitParts = o.slice(2).split("-");
  if (outfitParts.length !== 3) return null;
  const [outfit, p, q] = outfitParts;
  if (!items.bases.includes(`${body}/${outfit}`) || skin === null) return null;
  const primary = colour(p, "fabric");
  const secondary = colour(q, "fabric");
  if (primary === null || secondary === null) return null;

  let hair = null;
  let hairColour = 0;
  if (h !== "h-0") {
    const parts = h.startsWith("h-") ? h.slice(2).split("-") : [];
    if (parts.length !== 2) return null;
    const [id, c] = parts;
    hairColour = colour(c, "hair");
    if (!items.hair.includes(id) || hairColour === null) return null;
    hair = id;
  }

  let hat = null;
  let hatPrimary = 0;
  let hatSecondary = 0;
  if (w !== "w-0") {
    const parts = w.startsWith("w-") ? w.slice(2).split("-") : [];
    if (parts.length !== 3) return null;
    const [id, hp, hs] = parts;
    hatPrimary = colour(hp, "fabric");
    hatSecondary = colour(hs, "fabric");
    if (!own(items.headwear, id) || hatPrimary === null || hatSecondary === null) return null;
    hat = id;
  }

  let face = null;
  if (f !== "f-0") {
    const id = f.startsWith("f-") ? f.slice(2) : null;
    if (!own(items.face, id)) return null;
    face = id;
  }

  return {
    body,
    skin,
    outfit,
    primary,
    secondary,
    hair,
    hairColour,
    hat,
    hatPrimary,
    hatSecondary,
    face,
  };
}

/**
 * The canonical string of a parsed recipe: a colour slot the piece cannot be
 * dyed in is spelt 0, so one character has exactly one spelling.
 */
export function recipeString(r, catalog) {
  const outfitChannels = catalog.items.outfits[r.outfit]?.channels.length ?? 0;
  const dye = (n, slot, count) => (slot < count ? digit(n) : "0");
  const hatChannels = r.hat ? (catalog.items.headwear[r.hat]?.channels.length ?? 0) : 0;
  return [
    "c1",
    `b-${r.body}`,
    `s-${digit(r.skin)}`,
    `o-${r.outfit}-${dye(r.primary, 0, outfitChannels)}-${dye(r.secondary, 1, outfitChannels)}`,
    r.hair ? `h-${r.hair}-${digit(r.hairColour)}` : "h-0",
    r.hat
      ? `w-${r.hat}-${dye(r.hatPrimary, 0, hatChannels)}-${dye(r.hatSecondary, 1, hatChannels)}`
      : "w-0",
    r.face ? `f-${r.face}` : "f-0",
  ].join(".");
}

/**
 * The pieces of a character in drawing order, each with the colour chosen for
 * every channel it can be dyed in.
 *
 * @returns {Array<{layer: string, kind: string, colours: object}>|null}
 */
export function planLayers(recipe, catalog) {
  const r = parseRecipe(recipe, catalog);
  if (!r) return null;
  const out = [
    {
      layer: `base-${r.body}-${r.outfit}`,
      kind: "base",
      colours: { skin: r.skin, primary: r.primary, secondary: r.secondary },
    },
  ];
  if (r.face) out.push({ layer: `face-${r.face}`, kind: "face", colours: { primary: 0 } });
  if (r.hair) out.push({ layer: `hair-${r.hair}`, kind: "hair", colours: { hair: r.hairColour } });
  if (r.hat) {
    out.push({
      layer: `hat-${r.hat}`,
      kind: "hat",
      colours: { primary: r.hatPrimary, secondary: r.hatSecondary },
    });
  }
  return out;
}

/**
 * Palette entries for one layer: [index, [r, g, b]] pairs writing each dyed
 * channel's ramp over the shades the layer's PNG keeps for it.
 */
export function paletteEntries(layer, colours, catalog) {
  const entries = [];
  for (const [channel, indices] of Object.entries(layer.channels ?? {})) {
    if (!(channel in colours)) continue;
    const palette = catalog.palettes[catalog.channelPalette[channel]];
    const ramp = palette[colours[channel] % palette.length];
    indices.forEach((paletteIndex, shade) => entries.push([paletteIndex, ramp[shade]]));
  }
  return entries;
}

/** A stable key for a layer's colours, to cache its recoloured image under. */
export function colourKey(layer, colours) {
  return Object.keys(layer.channels ?? {})
    .sort()
    .map((c) => `${c}${colours[c] ?? "-"}`)
    .join(",");
}
