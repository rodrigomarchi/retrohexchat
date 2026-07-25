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

      // The list loads with the window — there is no tab to click any more.
      await expect(admin.page.locator("#admin-channels-output")).toContainText(
        "Channel List",
      );

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
