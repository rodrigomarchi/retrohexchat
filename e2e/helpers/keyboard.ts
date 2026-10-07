import type { Page } from "@playwright/test";

// A real keyboard reports the character Shift produces: Ctrl+Shift+/ arrives
// as key "?" on a US layout, Ctrl+Shift+1 as "!". Pressing "/" while Shift is
// held makes Playwright send key "/" with shiftKey — an event no keyboard
// sends, which once hid every shortcut on a shifted key. So digits and
// punctuation are pressed by their physical key, the way a hand presses them.
const PHYSICAL_KEY: Record<string, string> = {
  "/": "Slash",
  "\\": "Backslash",
  "[": "BracketLeft",
  "]": "BracketRight",
  ",": "Comma",
  ".": "Period",
  ";": "Semicolon",
  "'": "Quote",
  "-": "Minus",
  "=": "Equal",
  "`": "Backquote",
};

function physicalKey(key: string): string {
  if (/^[0-9]$/.test(key)) return `Digit${key}`;
  return PHYSICAL_KEY[key] ?? key;
}

/** Ctrl+Shift+`key`, producing the event a real US keyboard produces. */
export async function pressCtrlShift(page: Page, key: string): Promise<void> {
  await page.keyboard.down("Control");
  await page.keyboard.down("Shift");
  await page.keyboard.press(physicalKey(key));
  await page.keyboard.up("Shift");
  await page.keyboard.up("Control");
}
