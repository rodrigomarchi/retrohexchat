/**
 * @section T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard
 * @flow T3 [done] About dialog opens from the Help menu and from Start, closes cleanly, and restores chat input focus (features P2)
 * @flow T3b [done] The one About, opened from Start and from the About this site folder, is photographed
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Locator, Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname("about"));
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return chat;
}

async function openMenuItem(trigger: Locator, item: Locator) {
  await trigger.click();
  await expect(item).toBeVisible();
  await item.click();
}

test.describe("About dialog", () => {
  test("opens from Help menu and Start, closes cleanly, and restores chat focus (T3)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await chat.chatInput.focus();
    await openMenuItem(chat.helpMenuTrigger, chat.aboutMenuItem);
    await expect(chat.aboutDialog).toBeVisible();
    await expect(chat.aboutDialog).toContainText("Public Chat Platform");
    await chat.aboutOkButton.click();
    await expect(chat.aboutDialog).toBeHidden();
    await expect(chat.chatInput).toBeFocused();

    await chat.openStartGroup(chat.helpSubmenuTrigger, chat.startAboutItem);
    await chat.startAboutItem.click();
    await expect(chat.aboutDialog).toBeVisible();
    await expect(chat.aboutDialog).toContainText("Public Chat Platform");
    await chat.aboutOkButton.click();
    await expect(chat.aboutDialog).toBeHidden();
    await expect(chat.chatInput).toBeFocused();
  });

  // Start ▸ Help ▸ About and the About this site folder open the same window.
  test("the one About, photographed (T3b)", async ({ page }) => {
    const chat = await signedInUser(page);

    await chat.openStartGroup(chat.helpSubmenuTrigger, chat.startAboutItem);
    await chat.startAboutItem.click();
    await expect(chat.aboutDialog).toBeVisible();
    await expect(chat.aboutDialog).toContainText("Version");
    await shot(chat.aboutDialog, "about-from-start");
    // Escape closes it, as it closed the dialog it replaced.
    await page.keyboard.press("Escape");
    await expect(chat.aboutDialog).toBeHidden();

    await page.getByTestId("desktop-icon-site").dblclick();
    await page
      .locator('[data-testid^="desktop-launcher-item-"]', {
        hasText: /^\s*About\s*$/,
      })
      .first()
      .dblclick();
    await expect(chat.aboutDialog).toBeVisible();
    await shot(chat.aboutDialog, "about-from-the-folder");

    await page.setViewportSize({ width: 390, height: 844 });
    await expect(chat.aboutDialog).toBeVisible();
    await shot(page, "about-on-a-phone");
  });
});
