/**
 * @section T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard
 * @flow T1 [done] File/View/Tools/Help menu items open the same shell surfaces as keyboard equivalents where both exist (features P1)
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
  await connect.enterNickname(uniqueNickname("menu"));
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return chat;
}

async function pressCtrlShift(page: Page, key: string) {
  await page.keyboard.down("Control");
  await page.keyboard.down("Shift");
  await page.keyboard.press(key);
  await page.keyboard.up("Shift");
  await page.keyboard.up("Control");
}

async function openMenuItem(trigger: Locator, item: Locator) {
  // Retry the trigger click — the first click can race the menubar hook mount.
  await expect(async () => {
    await trigger.click();
    await expect(item).toBeVisible({ timeout: 1000 });
  }).toPass({ timeout: 10_000 });
  await item.click();
}

test.describe("Menu action parity", () => {
  test("menu items open the same shell surfaces as keyboard equivalents where both exist (T1)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    // Find lives in the Edit menu (moved there in the Edit-menu reorg).
    await openMenuItem(chat.editMenuTrigger, chat.findMenuItem);
    await expect(chat.searchBar).toBeVisible();
    await chat.searchBar.getByRole("button", { name: "Close" }).click();
    await expect(chat.searchBar).toBeHidden();

    await pressCtrlShift(page, "F");
    await expect(chat.searchBar).toBeVisible();
    await chat.searchBar.getByRole("button", { name: "Close" }).click();
    await expect(chat.searchBar).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.addressBookMenuItem);
    await expect(chat.addressBookDialog).toBeVisible();
    await chat.addressBookDialog
      .locator('[data-window-control="close"]')
      .click();
    await expect(chat.addressBookDialog).toBeHidden();

    await pressCtrlShift(page, "A");
    await expect(chat.addressBookDialog).toBeVisible();
    await chat.addressBookDialog
      .locator('[data-window-control="close"]')
      .click();
    await expect(chat.addressBookDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.highlightWordsMenuItem);
    await expect(chat.highlightDialog).toBeVisible();
    await chat.highlightDialog.locator('[data-window-control="close"]').click();
    await expect(chat.highlightDialog).toBeHidden();

    await pressCtrlShift(page, "H");
    await expect(chat.highlightDialog).toBeVisible();
    await chat.highlightDialog.locator('[data-window-control="close"]').click();
    await expect(chat.highlightDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.urlCatcherMenuItem);
    await expect(chat.urlCatcherDialog).toBeVisible();
    await chat.urlCatcherDialog
      .locator('[data-window-control="close"]')
      .click();
    await expect(chat.urlCatcherDialog).toBeHidden();

    await pressCtrlShift(page, "S");
    await expect(chat.urlCatcherDialog).toBeVisible();
    await chat.urlCatcherDialog
      .locator('[data-window-control="close"]')
      .click();
    await expect(chat.urlCatcherDialog).toBeHidden();

    await openMenuItem(chat.toolsMenuTrigger, chat.performMenuItem);
    await expect(chat.performDialog).toBeVisible();
    await chat.performDialog.locator('[data-window-control="close"]').click();
    await expect(chat.performDialog).toBeHidden();

    await pressCtrlShift(page, "E");
    await expect(chat.performDialog).toBeVisible();
    await chat.performDialog.locator('[data-window-control="close"]').click();
    await expect(chat.performDialog).toBeHidden();

    await openMenuItem(chat.helpMenuTrigger, chat.cheatsheetMenuItem);
    await expect(chat.cheatsheetDialog).toBeVisible();
    await chat.cheatsheetCloseButton.click();
    await expect(chat.cheatsheetDialog).toBeHidden();

    await pressCtrlShift(page, "/");
    await expect(chat.cheatsheetDialog).toBeVisible();
  });
});
