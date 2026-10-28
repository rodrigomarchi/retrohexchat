import { describe, expect, it } from "vitest";
import { banner, ink, wrap } from "../../../js/lib/ascii_art/banner.js";
import { MAX_COLUMNS, MAX_LINES, cell, fits, plainText } from "../../../js/lib/ascii_art/cells.js";
import { encode, encodeLine } from "../../../js/lib/ascii_art/encode.js";
import { glyph, HEIGHT } from "../../../js/lib/ascii_art/font.js";
import { fromDrawing, fromImage, nearest, pair } from "../../../js/lib/ascii_art/image.js";
import { CLEAR, createDrawing, paint } from "../../../js/lib/paint/document.js";

describe("the font", () => {
  it("draws every letter five pixels tall, accents as their plain letter, the unknown as a box", () => {
    for (const ch of "AZ09!?") expect(glyph(ch)).toHaveLength(HEIGHT);
    expect(glyph("ç")).toEqual(glyph("C"));
    expect(glyph("ж")).toEqual(glyph("☃"));
  });
});

describe("a banner", () => {
  it("puts a column of paper between letters", () => {
    const rows = ink("II");
    expect(rows[0]).toHaveLength(3 + 1 + 3);
    expect(rows[0][3]).toBe(false);
  });

  it("wraps words onto banners that fit, and fits one message", () => {
    const lines = wrap("HELLO WORLD THIS IS A BANNER", 60);
    expect(lines.length).toBeGreaterThan(1);
    for (const line of lines) expect(ink(line)[0].length * 2).toBeLessThanOrEqual(60);
    expect(fits(banner("A VERY LONG BANNER THAT GOES ON AND ON AND ON AND ON AND ON"))).toBe(true);
  });

  it("draws its ink in the chosen colour, a shadow in grey, a rainbow across", () => {
    const single = banner("I", { fg: 4 });
    expect(single[0][0]).toEqual(cell("█", 4));
    const shadow = banner("I", { style: "shadow", fg: 4 });
    expect(shadow[0]).toHaveLength(3 * 2 + 1);
    expect(shadow[2][2]).toEqual(cell("█", 4));
    expect(shadow.flat().some((c) => c.ch === "░" && c.fg === 14)).toBe(true);
    const rainbow = banner("MMMM", { scheme: "rainbow" });
    expect(new Set(rainbow[0].filter((c) => c.fg !== null).map((c) => c.fg)).size).toBeGreaterThan(
      2,
    );
  });
});

describe("pictures", () => {
  it("draws two pixels in a character, clear left clear", () => {
    expect(pair(null, null)).toEqual(cell(" "));
    expect(pair(4, 4)).toEqual(cell("█", 4));
    expect(pair(4, null)).toEqual(cell("▀", 4));
    expect(pair(null, 4)).toEqual(cell("▄", 4));
    expect(pair(4, 2)).toEqual(cell("▀", 4, 2));
  });

  it("turns a Hex Paint drawing into a block of its own colours that fits one message", () => {
    const drawing = paint(createDrawing(128), [[0, 0]], 9);
    const rows = fromDrawing(drawing, CLEAR);
    expect(rows.length).toBeLessThanOrEqual(MAX_LINES);
    expect(rows[0].length).toBeLessThanOrEqual(MAX_COLUMNS);
    expect(rows[0][0].fg).toBe(9);
    const small = fromDrawing(createDrawing(32), CLEAR);
    expect(small).toHaveLength(16);
    expect(small[0]).toHaveLength(32);
  });

  it("turns a photo into the nearest colours, or the brightness ramp", () => {
    const palette = [
      [255, 255, 255],
      [0, 0, 0],
    ];
    expect(nearest(palette, [20, 10, 30])).toBe(1);
    const data = new Uint8ClampedArray([
      250, 250, 250, 255, 5, 5, 5, 255, 250, 250, 250, 255, 5, 5, 5, 255,
    ]);
    const image = { data, width: 2, height: 2 };
    expect(fromImage(image, { columns: 2, mode: "colour", palette })[0][0]).toEqual(cell("█", 0));
    expect(plainText(fromImage(image, { columns: 2, mode: "ramp", palette }))).toBe(" @");
  });
});

describe("the message", () => {
  it("writes a colour code only where the colour changes, two digits always", () => {
    const row = [cell("█", 4), cell("█", 4), cell("1", 12), cell(" ")];
    expect(encodeLine(row)).toBe("\x0304██\x03121");
  });

  it("resets before a cell with less colour, keeps a background space, drops the blank end", () => {
    expect(encodeLine([cell("▀", 4, 2), cell("x"), cell(" ", null, 3), cell(" ")])).toBe(
      "\x0304,02▀\x0fx\x0301,03 ",
    );
  });

  it("starts every line afresh and leaves no blank lines at the end", () => {
    expect(encode([[cell("#", 4)], [cell("#", 4)], [cell(" ")]])).toBe("\x0304#\n\x0304#");
  });
});
