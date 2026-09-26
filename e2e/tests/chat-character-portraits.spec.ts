/**
 * @section T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard
 * @flow T24 [done] The character chosen in a space stands beside the nickname in the chat, in the nicklist and on the hover card, and View ▸ Character Portraits turns them off (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

test.describe("Character portraits", () => {
  test("a chosen character stands beside the nickname, and can be switched off (T24)", async ({
    browser,
  }) => {
    const ctxHost = await browser.newContext();
    const ctxGuest = await browser.newContext();
    const pageHost = await ctxHost.newPage();
    const pageGuest = await ctxGuest.newPage();

    const channel = `#ava${Math.random().toString(36).slice(2, 8)}`;
    const hostNick = uniqueNickname("hos");
    const guestNick = uniqueNickname("gue");

    try {
      const hostConnect = new ConnectPage(pageHost);
      const host = new ChatPage(pageHost);
      await hostConnect.open();
      await hostConnect.enterNickname(hostNick);
      await hostConnect.registerWithPassword("pass12345");
      await host.waitUntilConnected();
      await host.sendMessage(`/join ${channel}`);
      await host.expectTabVisible(channel);

      const guestConnect = new ConnectPage(pageGuest);
      const guest = new ChatPage(pageGuest);
      await guestConnect.open();
      await guestConnect.enterNickname(guestNick);
      await guestConnect.registerWithPassword("pass12345");
      await guest.waitUntilConnected();
      await guest.sendMessage(`/join ${channel}`);
      await guest.expectTabVisible(channel);

      // Nobody has chosen, so nobody has a face.
      await guest.sendMessage("no portrait yet");
      await expect(pageHost.locator(".rh-portrait")).toHaveCount(0);
      await shot(pageHost, "portraits-none-chosen");

      // The guest walks into the channel's space and picks a character.
      const space = await guest.openSpace();
      await space.getByTestId("space-avatar-knight").click();
      await expect(space.getByTestId("space-loading")).toBeHidden({
        timeout: 15_000,
      });
      await space.close();

      // Back in the chat, the choice is theirs — and the host's screen has it
      // beside every line they write.
      await guest.sendMessage("now I have a face");
      await expect(
        pageHost.locator(".rh-portrait--knight").first(),
      ).toBeVisible();
      await expect(
        pageHost.locator(
          '[data-testid^="nicklist-item-"] .rh-portrait--knight',
        ),
      ).toHaveCount(1);

      await shot(pageHost, "portraits-in-conversation");

      // View ▸ Character Portraits switches them off everywhere at once.
      await host.openStartGroup(
        pageHost.getByTestId("start-menu-view-submenu"),
        pageHost.getByTestId("start-menu-item-toggle_show_avatars"),
      );
      await pageHost.getByTestId("start-menu-item-toggle_show_avatars").click();

      await expect(pageHost.locator(".rh-portrait")).toHaveCount(0);
      await shot(pageHost, "portraits-switched-off");
    } finally {
      await ctxHost.close();
      await ctxGuest.close();
    }
  });
});
