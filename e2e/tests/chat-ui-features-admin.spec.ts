import { test, expect } from "@playwright/test";
import {
  ADMIN_NICK,
  ADMIN_PW,
  closeUsers,
  knownSignedInUser,
  newSignedInUser,
} from "../helpers/chatUsers";

/**
 * Admin journeys across the focused admin windows.
 *
 * Migrated from the Admin Console's tabbed shell when each tab became its own
 * window. The journeys asserted here are unchanged; each one now opens its own
 * window from File > Admin instead of switching a tab.
 */
test.describe.serial("UI feature admin journeys", () => {
  test("safe admin paths across the split windows (Feature 12)", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);
    const observer = await newSignedInUser(browser, "uifao");
    const newDescription = `admin-description-${Date.now()}`;
    const motd = `admin-motd-${Date.now()}`;
    const announcement = `admin-announcement-${Date.now()}`;

    try {
      // ── Server Settings ──────────────────────────────────────────
      await admin.chat.openAdminWindow("open_admin_server_settings");
      const descriptionInput = admin.page.locator(
        "#admin-server-settings-description",
      );
      const originalDescription = await descriptionInput.inputValue();
      await descriptionInput.fill(newDescription);
      await admin.page
        .locator("#admin-server-settings-form")
        .getByRole("button", { name: "Save settings" })
        .click();
      await expect(
        admin.chat.adminWindowResult("admin-server-settings"),
      ).toContainText(newDescription);

      // ── MOTD ─────────────────────────────────────────────────────
      await admin.chat.openAdminWindow("open_admin_motd");
      await admin.page.locator("#admin-motd-input").fill(motd);
      await admin.page
        .locator("#admin-motd-form")
        .getByRole("button", { name: "Set MOTD" })
        .click();
      await expect(admin.page.getByTestId("admin-motd-result")).toContainText(
        "MOTD has been updated.",
      );
      await expect(admin.page.locator("#admin-motd-current")).toContainText(
        motd,
      );

      await observer.chat.openMessageOfTheDayFromHelpMenu();
      await observer.chat.switchToStatusTab();
      await observer.chat.expectStatusMessageVisible(motd);
      await observer.chat.switchToTab("#lobby");

      // ── Broadcast ────────────────────────────────────────────────
      await admin.chat.openAdminWindow("open_admin_broadcast");
      await admin.page
        .locator('#admin-broadcast-form input[value="announce"]')
        .check();
      await admin.page.locator("#admin-broadcast-message").fill(announcement);
      await admin.page
        .locator("#admin-broadcast-form")
        .getByRole("button", { name: "Send broadcast" })
        .click();
      await expect(
        admin.chat.adminWindowResult("admin-broadcast"),
      ).toContainText("Announcement sent to all users.");
      await observer.chat.expectMessageVisible(announcement);

      // ── TURN ─────────────────────────────────────────────────────
      await admin.chat.openAdminWindow("open_admin_turn");
      await expect(admin.page.locator("#admin-turn-stats")).toContainText(
        "TURN",
      );
      await admin.page
        .getByTestId("admin-turn-panel")
        .getByRole("button", { name: "Refresh" })
        .click();
      await expect(admin.page.locator("#admin-turn-allocations")).toContainText(
        /allocation/i,
      );

      // ── Audit Log ────────────────────────────────────────────────
      await admin.chat.openAdminWindow("open_admin_audit_log");
      await admin.page.locator("#admin-audit-log-last").fill("5");
      await admin.page.locator("#admin-audit-log-user").fill(ADMIN_NICK);
      await admin.page
        .locator("#admin-audit-log-form")
        .getByRole("button", { name: "Refresh" })
        .click();
      await expect(admin.page.locator("#admin-audit-log-output")).toContainText(
        ADMIN_NICK,
      );

      // ── Danger Zone: the guard holds ─────────────────────────────
      await admin.chat.openAdminWindow("open_admin_danger_zone");
      await expect(
        admin.page.locator("#admin-danger-zone-preview"),
      ).toContainText(/nuke/i);
      await admin.page.locator("#admin-danger-zone-confirm").fill("wrong");
      await expect(
        admin.page
          .locator("#admin-danger-zone-form")
          .getByRole("button", { name: "NUKE EVERYTHING" }),
      ).toBeDisabled();

      // ── Console ──────────────────────────────────────────────────
      await admin.chat.openAdminWindow("open_admin_console");
      await admin.chat.adminConsoleInput.fill("admin server get registration");
      await admin.page
        .locator("#admin-console-form")
        .getByRole("button", { name: "Run" })
        .click();
      await expect(admin.chat.adminConsoleOutput).toContainText("registration");

      // ── Restore what the run changed ─────────────────────────────
      await admin.chat.openAdminWindow("open_admin_motd");
      await admin.page
        .locator("#admin-motd-form")
        .getByRole("button", { name: "Clear MOTD" })
        .click();
      await expect(admin.page.getByTestId("admin-motd-result")).toContainText(
        "MOTD has been cleared.",
      );

      await admin.chat.openAdminWindow("open_admin_server_settings");
      await admin.page
        .locator("#admin-server-settings-description")
        .fill(originalDescription);
      await admin.page
        .locator("#admin-server-settings-form")
        .getByRole("button", { name: "Save settings" })
        .click();
    } finally {
      await closeUsers([admin, observer]);
    }
  });

  test("every admin window opens from File > Admin and closes from its title bar", async ({
    browser,
  }) => {
    const admin = await knownSignedInUser(browser, ADMIN_NICK, ADMIN_PW);

    const actions = [
      "open_admin_users",
      "open_admin_channels",
      "open_admin_server_settings",
      "open_admin_audit_log",
      "open_admin_motd",
      "open_admin_turn",
      "open_admin_broadcast",
      "open_admin_danger_zone",
      "open_admin_console",
    ];

    try {
      for (const action of actions) {
        const windowId = action.replace(/^open_/, "").replaceAll("_", "-");
        const panel = await admin.chat.openAdminWindow(action);
        await expect(panel).toBeVisible();

        await admin.chat.closeAdminWindow(windowId);
        await expect(panel).toBeHidden();
      }
    } finally {
      await closeUsers([admin]);
    }
  });
});
