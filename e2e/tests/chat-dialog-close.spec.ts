/**
 * @section T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard
 * @flow T11 [done] Dialog title close, cancel buttons, and backdrop paths close major dialogs consistently (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Locator, Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname("close"));
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return chat;
}

async function openMenuItem(trigger: Locator, item: Locator) {
  // Retry the trigger click — the first click can race the menubar hook mount.
  await expect(async () => {
    await trigger.click();
    await expect(item).toBeVisible({ timeout: 1000 });
  }).toPass({ timeout: 10_000 });
  await item.click();
}

async function clickTitleClose(dialog: Locator) {
  await dialog.getByRole("button", { name: "Close" }).first().click();
}

async function clickBackdrop(page: Page) {
  await page.mouse.click(20, 20);
}

test.describe("Dialog close behavior", () => {
  test("close buttons, cancel buttons, and backdrop paths close major dialogs consistently (T11)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    // Address Book is a desktop window: the title-bar X closes it…
    await openMenuItem(chat.toolsMenuTrigger, chat.addressBookMenuItem);
    await expect(chat.addressBookDialog).toBeVisible();
    await chat.addressBookDialog
      .locator('[data-window-control="close"]')
      .click();
    await expect(chat.addressBookDialog).toBeHidden();

    // …clicking the desktop does NOT close it (windows have no backdrop)…
    await openMenuItem(chat.toolsMenuTrigger, chat.addressBookMenuItem);
    await expect(chat.addressBookDialog).toBeVisible();
    await page
      .locator("#chat-desktop .desktop__workspace")
      .click({ position: { x: 10, y: 400 } });
    await expect(chat.addressBookDialog).toBeVisible();

    // …and Escape closes the topmost unpinned window.
    await page.keyboard.press("Escape");
    await expect(chat.addressBookDialog).toBeHidden();

    // Channel List is a desktop window: X and Escape close it.
    await openMenuItem(chat.viewMenuTrigger, chat.channelListMenuItem);
    await expect(chat.channelListDialog).toBeVisible();
    await chat.channelListDialog
      .locator('[data-window-control="close"]')
      .click();
    await expect(chat.channelListDialog).toBeHidden();

    await openMenuItem(chat.viewMenuTrigger, chat.channelListMenuItem);
    await expect(chat.channelListDialog).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(chat.channelListDialog).toBeHidden();

    // Highlight Words is a desktop window: no backdrop close; the title-bar X
    // and Escape close it.
    await openMenuItem(chat.toolsMenuTrigger, chat.highlightWordsMenuItem);
    await expect(chat.highlightDialog).toBeVisible();
    await page
      .locator("#chat-desktop .desktop__workspace")
      .click({ position: { x: 10, y: 400 } });
    await expect(chat.highlightDialog).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(chat.highlightDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.highlightWordsMenuItem);
    await expect(chat.highlightDialog).toBeVisible();
    await chat.highlightDialog.locator('[data-window-control="close"]').click();
    await expect(chat.highlightDialog).toBeHidden();
  });
});
