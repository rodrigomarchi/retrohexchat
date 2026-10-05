/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW23 [done] The mIRC commands guide answers a mIRC habit row by row, and its links lead into the matching help topic and the other guides
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { shot } from "../helpers/screenshots";

test("the mIRC commands guide leads to the help and to the other guides (PW23)", async ({
  page,
}) => {
  await page.goto("/mirc-commands");
  await expect(page.locator("#mirc-commands-heading")).toBeVisible();

  // The table's windows open cascaded like every landing page's; the taskbar
  // brings the channels group to the front.
  await page.locator('[data-window-taskbar="parity-channels"]').click();
  const channels = page.getByTestId("parity-parity-channels");
  await expect(channels).toContainText("/join #channel key");
  await shot(page, "mirc-commands-channels");

  // A command that exists here links to the help topic that explains it.
  await channels.getByRole("link", { name: "/join" }).click();
  await expect(page).toHaveURL(/\/chat\/help\/cmd-join$/);

  // Back on the guide, the reading window leads to the other two.
  await page.goto("/mirc-commands");
  await page.locator('[data-window-taskbar="read-next"]').click();
  await page
    .getByTestId("guide-links")
    .getByRole("link", { name: "IRC chat" })
    .click();
  await expect(page).toHaveURL(/\/irc-chat$/);
  await expect(page.locator("#irc-chat-heading")).toBeVisible();
  await shot(page, "irc-chat");
});
