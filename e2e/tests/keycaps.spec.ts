/**
 * @section T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard
 * @flow T10b [done] A key is drawn the same way wherever it is named — the cheatsheet, a game's page, the help — and each is photographed
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { pressCtrlShift } from "../helpers/keyboard";
import { shot } from "../helpers/screenshots";

const PHONE = { width: 390, height: 844 };

// The table or list the first key on the page sits in: the keys and what they
// do, which is what has to read alike everywhere.
function firstKeyTable(page: Page) {
  return page.locator("kbd").first().locator("xpath=ancestor::table[1]");
}

test.describe("Keycaps (T10b)", () => {
  test("the cheatsheet's keys", async ({ page }) => {
    const connect = new ConnectPage(page);
    const chat = new ChatPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname("caps"));
    await connect.registerWithPassword("pass12345");
    await chat.waitUntilConnected();

    await pressCtrlShift(page, "/");
    await expect(chat.cheatsheetDialog).toContainText("Ctrl+Shift+A");
    await shot(chat.cheatsheetDialog, "cheatsheet");

    await page.setViewportSize(PHONE);
    await expect(chat.cheatsheetDialog).toBeVisible();
    await shot(page, "cheatsheet-phone");
  });

  test("a game's keys", async ({ page }) => {
    await page.goto("/games/freedoom1");
    const controls = page.getByTestId("game-controls");
    await expect(controls.locator("kbd").first()).toBeVisible();
    await shot(controls, "game-sheet-keys");
  });

  test("the help's keys", async ({ page }) => {
    await page.goto("/chat/help/feature-key-bindings");
    await expect(page.locator("kbd").first()).toBeVisible();
    await shot(firstKeyTable(page), "help-key-bindings");

    await page.setViewportSize(PHONE);
    await page.goto("/chat/help/feature-smart-input");
    await expect(page.locator("kbd").first()).toBeVisible();
    await shot(
      page.locator("kbd").first().locator("xpath=.."),
      "help-smart-input-phone",
    );
  });
});
