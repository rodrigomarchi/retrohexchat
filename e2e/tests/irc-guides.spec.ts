/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW23 [done] The mIRC commands guide answers a mIRC habit row by row, and its links lead into the matching help topic and the other guides
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { shot } from "../helpers/screenshots";

async function bringForward(page: Page, windowId: string) {
  await page.getByTestId("taskbar-group-site").click();
  await page
    .locator(`[data-taskbar-group-panel] [data-window-taskbar="${windowId}"]`)
    .click();
}

test("the mIRC commands guide leads to the help and to the other guides (PW23)", async ({
  page,
}) => {
  await page.goto("/mirc-commands");
  await expect(page.locator("#mirc-commands-heading")).toBeVisible();

  // Each group of the table is a window of its own; the page's taskbar group
  // brings the channels one forward.
  await bringForward(page, "site-parity-channels");
  const channels = page.getByTestId("parity-parity-channels");
  await expect(channels).toContainText("/join #channel key");
  await shot(page, "mirc-commands-channels");

  // A command that exists here links to the help topic that explains it.
  await channels.getByRole("link", { name: "/join" }).click();
  await expect(page).toHaveURL(/\/chat\/help\/cmd-join$/);

  // Back on the guide, its reading section leads to the other two.
  await page.goto("/mirc-commands");
  await bringForward(page, "site-read-next");
  await page
    .getByTestId("guide-links")
    .getByRole("link", { name: "IRC chat" })
    .click();
  await expect(page).toHaveURL(/\/irc-chat$/);
  await expect(page.locator("#irc-chat-heading")).toBeVisible();
  await shot(page, "irc-chat");
});
