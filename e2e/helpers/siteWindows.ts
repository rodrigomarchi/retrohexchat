import { expect, Locator, Page } from "@playwright/test";

/**
 * The windows of a page of the site, as a reader meets them: a group over the
 * chat, one window in front of the rest.
 */

const GROUP_WINDOW = '[data-window-group="site"]';

/**
 * The window in front of the whole desk is the one the window manager does not
 * draw blurred — the same mark a reader sees as the active title bar.
 */
export async function expectInFront(window: Locator) {
  await expect(window).toBeVisible();
  await expect(window).not.toHaveClass(/desktop-window--blurred/);
}

/**
 * Closes every window of the page on screen the way a reader would: the one in
 * front first, since one behind it has its close button covered. Each close has
 * to take a window away, so a close that does nothing fails here rather than
 * looping.
 */
export async function closePage(page: Page) {
  const open = page.locator(`${GROUP_WINDOW}:visible`);
  const front = page.locator(
    `${GROUP_WINDOW}:visible:not(.desktop-window--blurred)`,
  );

  for (let left = await open.count(); left > 0; left -= 1) {
    await front.locator('[data-window-control="close"]').click();
    await expect(open).toHaveCount(left - 1);
  }
}

/**
 * Brings one of the page's windows forward from the page's taskbar group, the
 * way a reader reaches a window covered by the others.
 */
export async function bringForward(page: Page, windowId: string) {
  await page.getByTestId("taskbar-group-site").click();
  await page
    .locator(`[data-taskbar-group-panel] [data-window-taskbar="${windowId}"]`)
    .click();
  await expectInFront(page.locator(`[data-window-id="${windowId}"]`));
}
