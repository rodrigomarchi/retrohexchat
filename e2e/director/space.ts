import { BrowserContext, expect, Page } from "@playwright/test";
import { enterThroughNewCard } from "../helpers/surfaceEntry";

/**
 * Spaces on film: entering one, and keeping its avatars alive.
 *
 * The map is a canvas — there is no DOM for positions — so these wait on the
 * picker and the loading veil, and move people with the keys a player holds.
 */

/** Opens the channel's Space from the chat (card → new tab) and returns the tab. */
export async function openSpace(
  page: Page,
  ctx: BrowserContext,
): Promise<Page> {
  const space = await enterThroughNewCard(page, ctx, "space-open");
  await expect(space.getByTestId("space-character-select")).toBeVisible({
    timeout: 15_000,
  });
  return space;
}

/** Picks a character and waits until the map has drawn. */
export async function pickAvatar(space: Page, avatar: string) {
  await space.getByTestId(`space-avatar-${avatar}`).click();
  await expect(space.getByTestId("space-loading")).toBeHidden({
    timeout: 20_000,
  });
}

/** Holds a direction key long enough to walk `steps` tiles (one per 150 ms). */
export async function walk(space: Page, key: string, steps: number) {
  await space.keyboard.down(key);
  await space.waitForTimeout(steps * 150 + 60);
  await space.keyboard.up(key);
}

const PACES: [string, string][] = [
  ["ArrowLeft", "ArrowRight"],
  ["ArrowUp", "ArrowDown"],
  ["ArrowRight", "ArrowLeft"],
  ["ArrowDown", "ArrowUp"],
];

/**
 * Keeps an avatar pacing near where it stands — out and back — until `stop`
 * resolves, so a crowd looks alive without drifting apart. `offset` staggers
 * people so they do not move in step.
 */
export async function wander(
  space: Page,
  offset: number,
  stopped: () => boolean,
) {
  await space.waitForTimeout(offset);
  for (let i = offset; !stopped(); i++) {
    const [out, back] = PACES[i % PACES.length];
    const steps = 1 + (i % 2);
    await walk(space, out, steps);
    await space.waitForTimeout(700 + (i % 3) * 400);
    if (stopped()) break;
    await walk(space, back, steps);
    await space.waitForTimeout(900 + (i % 2) * 500);
  }
}
