import { describe, expect, it } from "vitest";

import { buildNickFlag, drawableFlag, syncNickFlag } from "../../js/lib/nick_flag.js";

const PT = { locale: "pt_BR", language: "Português (Brasil)", href: "/s.svg#icon_flag_pt_br" };
const DE = { locale: "de", language: "Deutsch", href: "/s.svg#icon_flag_de" };

function nameplate() {
  const plate = document.createElement("span");
  const name = document.createElement("span");
  name.dataset.groupCallTileName = "";
  name.textContent = "alice";
  plate.appendChild(name);
  return { plate, name };
}

describe("drawableFlag", () => {
  it("needs a locale, a language and a sprite reference", () => {
    expect(drawableFlag(PT)).toBe(true);
    expect(drawableFlag(null)).toBe(false);
    expect(drawableFlag({ locale: "pt_BR", language: "x", href: "" })).toBe(false);
    expect(drawableFlag({ locale: "pt_BR", href: "/s.svg#a" })).toBe(false);
  });
});

describe("buildNickFlag", () => {
  it("draws the same mark the server component does", () => {
    const flag = buildNickFlag(document, PT);
    expect(flag.className).toBe("rh-nick-flag");
    expect(flag.getAttribute("data-testid")).toBe("nick-flag");
    expect(flag.getAttribute("data-locale")).toBe("pt_BR");
    expect(flag.getAttribute("role")).toBe("img");
    expect(flag.title).toBe("Português (Brasil)");
    expect(flag.getAttribute("aria-label")).toBe("Português (Brasil)");
    const use = flag.querySelector("svg.rh-nick-flag__icon use");
    expect(use.getAttribute("href")).toBe("/s.svg#icon_flag_pt_br");
  });
});

describe("syncNickFlag", () => {
  it("puts the flag before the name, never inside it", () => {
    const { plate, name } = nameplate();
    syncNickFlag(name, PT);
    expect(plate.firstElementChild.getAttribute("data-locale")).toBe("pt_BR");
    expect(plate.lastElementChild).toBe(name);
    expect(name.textContent).toBe("alice");
  });

  it("does not add a second flag on a repeat, and swaps it when the language changes", () => {
    const { plate, name } = nameplate();
    syncNickFlag(name, PT);
    syncNickFlag(name, PT);
    expect(plate.querySelectorAll("[data-nick-flag]")).toHaveLength(1);
    syncNickFlag(name, DE);
    expect(plate.querySelectorAll("[data-nick-flag]")).toHaveLength(1);
    expect(plate.firstElementChild.getAttribute("data-locale")).toBe("de");
  });

  it("takes the flag away when there is none to draw", () => {
    const { plate, name } = nameplate();
    syncNickFlag(name, PT);
    syncNickFlag(name, null);
    expect(plate.querySelector("[data-nick-flag]")).toBe(null);
  });

  it("does nothing without a name element", () => {
    expect(() => syncNickFlag(null, PT)).not.toThrow();
  });
});
