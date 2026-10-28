/**
 * The sixteen colours as the page draws them, shared by Hex Paint and ASCII
 * Art: the swatches are the chat's colour picker (`data-irc-colour`, each its
 * `irc-bg-N`), so the colours are read from them and never written down a
 * second time.
 *
 * @module paint/palette
 */
import { CLEAR } from "./document.js";
import { parseRgb } from "./export.js";

/** Each swatch's colour, by its index, as red, green and blue. */
export function readPalette(el) {
  const view = el.ownerDocument.defaultView;
  const colours = [];
  for (const swatch of el.querySelectorAll("[data-irc-colour]")) {
    const index = Number(swatch.dataset.ircColour);
    colours[index] ??= parseRgb(view?.getComputedStyle(swatch).backgroundColor) ?? [0, 0, 0];
  }
  return colours;
}

/** Paints the two chosen colours (`ColorPicker.colour_pair/1`); a clear one shows nothing. */
export function showCurrent(el, colours) {
  for (const [which, colour] of Object.entries(colours)) {
    for (const square of el.querySelectorAll(`[data-irc-current='${which}']`)) {
      square.className = square.className.replace(/\birc-bg-\d+\b/g, "").trim();
      if (colour !== CLEAR) square.classList.add(`irc-bg-${colour}`);
    }
  }
}

/**
 * The colour a press on a swatch chooses, as `{ which, colour }` — the left
 * button the foreground, the right the background — or null off the swatches.
 */
export function swatchChoice(event) {
  const holder = event.target.closest?.("label, button, [data-irc-colour]");
  const swatch = holder?.matches("[data-irc-colour]")
    ? holder
    : holder?.querySelector("[data-irc-colour]");
  if (!swatch) return null;
  return {
    which: event.type === "contextmenu" ? "bg" : "fg",
    colour: Number(swatch.dataset.ircColour),
  };
}

/**
 * The two colours after a press on a swatch, or null off the swatches. A
 * right-button press is only ours, so the page's own menu does not open on it;
 * the left button's is the picker's own choice and goes ahead.
 */
export function chooseSwatch(event, colours) {
  const choice = swatchChoice(event);
  if (!choice) return null;
  if (event.type === "contextmenu") event.preventDefault();
  return { ...colours, [choice.which]: choice.colour };
}
