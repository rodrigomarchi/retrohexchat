/**
 * @section T - Desktop Shell, Menus, Toolbars, Dialogs, And Keyboard
 * @flow T25 [done] The desktop's Tools folder lists what Start ▸ Tools lists — Saved Messages and Events included — and each opens its window (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, type Page } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

async function signIn(page: Page): Promise<ChatPage> {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname("tools"));
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();
  return chat;
}

test.describe("the desktop's Tools folder", () => {
  test("lists Saved Messages and Events beside the other tools, and opens them", async ({
    page,
  }) => {
    const chat = await signIn(page);
    const folder = page.getByTestId("desktop-launcher-window-tools");

    await page.getByTestId("desktop-icon-tools").dblclick();
    await expect(folder).toBeVisible();

    for (const testId of [
      "desktop-launcher-item-address-book",
      "desktop-launcher-item-open_saved_dialog",
      "desktop-launcher-item-open_events_dialog",
      "desktop-launcher-item-toggle_channel_list",
      "desktop-launcher-item-flood-protection",
    ]) {
      await expect(folder.getByTestId(testId)).toBeVisible();
    }
    await shot(folder, "tools-folder");

    await folder
      .getByTestId("desktop-launcher-item-open_saved_dialog")
      .dblclick();
    await expect(chat.savedDialog).toBeVisible();
    await shot(chat.savedDialog, "saved-messages-from-folder");

    await page.getByTestId("desktop-icon-tools").dblclick();
    await folder
      .getByTestId("desktop-launcher-item-open_events_dialog")
      .dblclick();
    await expect(chat.eventsDialog).toBeVisible();
    await shot(page, "events-from-folder");
  });
});
