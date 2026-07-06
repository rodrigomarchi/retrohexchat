import { test, expect } from "@playwright/test";
import { newP2PUser, closeP2PUsers } from "../helpers/p2pFlows";

// Phase 5 acceptance: the creator can kick another participant. The kicked
// user sees a terminal "removed" screen and cannot re-enter the space.
test.describe("Virtual space admin", () => {
  test("the creator kicks a member, who is removed and cannot re-enter", async ({
    browser,
  }) => {
    const host = await newP2PUser(browser, "adh");
    const guest = await newP2PUser(browser, "adg");
    const channel = `#adm-${Date.now().toString(36)}`;

    try {
      await host.chat.sendMessage(`/join ${channel}`);
      await host.chat.expectTabVisible(channel);
      await host.chat.sendMessage("/space Admin Test");

      const link = host.page.locator('a[href*="/space/"]').first();
      await expect(link).toBeVisible({ timeout: 10_000 });
      const href = (await link.getAttribute("href")) as string;

      await host.page.goto(href);
      await expect(host.page.getByTestId("space-shell")).toBeVisible({
        timeout: 15_000,
      });

      // Guest joins the same space.
      await guest.page.goto(href);
      await expect(guest.page.getByTestId("space-shell")).toBeVisible({
        timeout: 15_000,
      });

      // The host's control panel lists the guest with a Kick button.
      const kickButton = host.page
        .locator("[data-space-admin-list] [data-kick-key]")
        .first();
      await expect(kickButton).toBeVisible({ timeout: 10_000 });
      await kickButton.click();

      // The guest sees the removed screen.
      await expect(guest.page.locator("[data-space-kicked]")).toBeVisible({
        timeout: 10_000,
      });

      // And cannot re-enter: reloading the space is rejected (kicked screen again).
      await guest.page.goto(href);
      await expect(guest.page.locator("[data-space-kicked]")).toBeVisible({
        timeout: 15_000,
      });
    } finally {
      await closeP2PUsers([host, guest]);
    }
  });
});
