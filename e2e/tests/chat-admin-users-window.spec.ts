/**
 * @section UI Features Browser Regression
 * @flow UI11a [done] Admin Users window: info lookup and mute/unmute from File > Admin > Users (features 12)
 * @flow UI11b [done] Admin Users window opens from the File > Admin submenu and closes from its title bar (features 12)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { shot } from "../helpers/screenshots";
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
 *
 * Carries a `shot()` at the loaded listing, which is the same RetroTable the
 * runtime windows use but with unbounded cells — regenerate it with:
 *
 *     make e2e.shots FILE=tests/chat-admin-users-window.spec.ts
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
      await shot(admin.page.getByTestId("admin-users-window"), "users-listing");

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
