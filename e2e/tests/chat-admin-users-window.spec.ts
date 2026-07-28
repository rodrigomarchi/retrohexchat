import { test, expect } from "@playwright/test";
import {
  ADMIN_NICK,
  ADMIN_PW,
  closeUsers,
  knownSignedInUser,
  newSignedInUser,
} from "../helpers/chatUsers";

/**
 * Admin Users window.
 *
 * Migrated from the Admin Console's Users tab when it was split into its own
 * window: the behaviour asserted here is unchanged, only the surface it runs
 * against. Command-level coverage of the same domain lives in
 * chat-admin-users.spec.ts.
 */
test.describe.serial("Admin Users window", () => {
  test("admin inspects a nick and applies moderation", async ({ browser }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const target = await newSignedInUser(browser, "auw");

    try {
      await admin.chat.openAdminUsersFromMenu();

      // The list loads with the window, rendered as rows rather than a text block.
      await expect(
        admin.page.locator('[data-testid="admin-users-table"]'),
      ).toBeVisible();

      await admin.page.locator("#admin-users-info-nick").fill(target.nick);
      await admin.page
        .locator("#admin-users-info-form")
        .getByRole("button", { name: "Info" })
        .click();
      await expect(admin.chat.adminUsersInlineResult).toContainText(
        `*** User: ${target.nick}`,
      );

      await admin.page
        .locator('#admin-users-mute-form input[name="nick"]')
        .fill(target.nick);
      await admin.page
        .locator('#admin-users-mute-form input[name="duration"]')
        .fill("30s");
      await admin.page
        .locator("#admin-users-mute-form")
        .getByRole("button", { name: "Confirm mute" })
        .click();
      await expect(admin.chat.adminUsersInlineResult).toContainText(
        `${target.nick} has been muted`,
      );

      await admin.page
        .locator('#admin-users-unmute-form input[name="nick"]')
        .fill(target.nick);
      await admin.page
        .locator("#admin-users-unmute-form")
        .getByRole("button", { name: "Confirm unmute" })
        .click();
      await expect(admin.chat.adminUsersInlineResult).toContainText(
        `${target.nick} has been unmuted.`,
      );
    } finally {
      await closeUsers([admin, target]);
    }
  });

  test("File > Admin > Users opens the window and the title-bar X closes it", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    try {
      await admin.chat.openAdminUsersFromMenu();
      await expect(admin.chat.adminUsersPanel).toBeVisible();

      await admin.page
        .locator('[data-window-id="admin-users"] [data-window-control="close"]')
        .click();
      await expect(admin.chat.adminUsersPanel).toBeHidden();
    } finally {
      await closeUsers([admin]);
    }
  });
});
