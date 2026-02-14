import { IRC_FORMAT_CODES, SHORTCUT_FORMAT_MAP } from "../../js/lib/irc_format.js";

describe("lib/irc_format", () => {
  it("exports all IRC format codes", () => {
    expect(IRC_FORMAT_CODES.bold).toBe("\x02");
    expect(IRC_FORMAT_CODES.italic).toBe("\x1D");
    expect(IRC_FORMAT_CODES.underline).toBe("\x1F");
    expect(IRC_FORMAT_CODES.color).toBe("\x03");
    expect(IRC_FORMAT_CODES.reverse).toBe("\x16");
    expect(IRC_FORMAT_CODES.reset).toBe("\x0F");
  });

  it("exports shortcut map with correct keys", () => {
    expect(Object.keys(SHORTCUT_FORMAT_MAP)).toEqual(["b", "y", "u", "d", "v", "x"]);
  });

  it("shortcut map values match format codes", () => {
    expect(SHORTCUT_FORMAT_MAP.b).toBe(IRC_FORMAT_CODES.bold);
    expect(SHORTCUT_FORMAT_MAP.u).toBe(IRC_FORMAT_CODES.underline);
    expect(SHORTCUT_FORMAT_MAP.y).toBe(IRC_FORMAT_CODES.italic);
  });
});
