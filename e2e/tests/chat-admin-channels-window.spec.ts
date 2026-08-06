/**
 * @section UI Features Browser Regression
 * @flow UI11c [done] Admin Channels window: create, inspect, and delete with typed confirmation (features 12)
 * @flow UI11d [done] Admin Channels window opens from the File > Admin submenu and closes from its title bar (features 12)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import {
  ADMIN_NICK,
  ADMIN_PW,
  closeUsers,
  knownSignedInUser,
  uniqueChannel,
} from "../helpers/chatUsers";

/**
 * Admin Channels window.
 *
 * Migrated from the Admin Console's Channels tab when it was split into its own
 * window: the behaviour asserted here is unchanged, only the surface it runs
 * against.
 */
test.describe.serial("Admin Channels window", () => {
  test("admin creates, inspects and deletes a channel with typed confirmation", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const channel = uniqueChannel("acw");

    try {
      await admin.chat.openAdminChannelsFromMenu();

      // The list loads with the window, rendered as rows rather than a text block.
      await expect(
        admin.page.locator('[data-testid="admin-channels-table"]'),
      ).toBeVisible();

      await admin.page.locator("#admin-channels-create-name").fill(channel);
      await admin.page
        .locator("#admin-channels-create-form")
        .getByRole("button", { name: "Create" })
        .click();
      await expect(admin.chat.adminChannelsInlineResult).toContainText(
        `Channel ${channel} created and registered.`,
      );

      await admin.page.locator("#admin-channels-info-name").fill(channel);
      await admin.page
        .locator("#admin-channels-info-form")
        .getByRole("button", { name: "Info" })
        .click();
      await expect(admin.chat.adminChannelsInlineResult).toContainText(
        `*** Channel: ${channel}`,
      );

      // A wrong confirmation must refuse before anything is destroyed.
      await admin.page
        .locator('#admin-channels-delete-form input[name="channel"]')
        .fill(channel);
      await admin.page
        .locator('#admin-channels-delete-form input[name="confirm"]')
        .fill("wrong");
      await admin.page
        .locator("#admin-channels-delete-form")
        .getByRole("button", { name: "Confirm delete" })
        .click();
      await expect(admin.chat.adminChannelsInlineResult).toContainText(
        "Type the channel name to confirm.",
      );

      await admin.page
        .locator('#admin-channels-delete-form input[name="confirm"]')
        .fill(channel);
      await admin.page
        .locator("#admin-channels-delete-form")
        .getByRole("button", { name: "Confirm delete" })
        .click();
      await expect(admin.chat.adminChannelsInlineResult).toContainText(
        `Channel ${channel} has been deleted.`,
      );
    } finally {
      await closeUsers([admin]);
    }
  });

  test("File > Admin > Channels opens the window and the title-bar X closes it", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await admin.chat.openAdminChannelsFromMenu();
      await expect(admin.chat.adminChannelsPanel).toBeVisible();

      await admin.page
        .locator(
          '[data-window-id="admin-channels"] [data-window-control="close"]',
        )
        .click();
      await expect(admin.chat.adminChannelsPanel).toBeHidden();
    } finally {
      await closeUsers([admin]);
    }
  });
});
