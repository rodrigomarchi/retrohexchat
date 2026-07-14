import { Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

// A phone-sized viewport (below the 720px stacking breakpoint).
const PHONE = { width: 375, height: 720 };

async function signedInUser(page: Page, prefix = "mob") {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, nick };
}

test.describe("chat desktop on a phone (stacked single-window)", () => {
  test.use({ viewport: PHONE });

  test("shows one fullscreen window at a time, switched via the taskbar", async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);

    const desktop = page.getByTestId("chat-desktop");
    const workspace = desktop.locator(".desktop__workspace");
    const chatWindow = page.getByTestId("chat-window");
    const timersWindow = page.getByTestId("timers-window");
    const menuBar = page.getByTestId("menu-bar");
    const startButton = page.locator("[data-window-start]");
    const chatTaskbarBtn = page.locator('[data-window-taskbar="chat"]');
    const timersTaskbarBtn = page.locator('[data-window-taskbar="timers"]');

    // The menu bar, Start button and taskbar all remain on mobile.
    await expect(menuBar).toBeVisible();
    await expect(startButton).toBeVisible();
    await expect(chatTaskbarBtn).toBeVisible();

    // The chat window fills the workspace (fullscreen app layout).
    await expect(chatWindow).toBeVisible();
    const wsBox = await workspace.boundingBox();
    const chatBox = await chatWindow.boundingBox();
    expect(chatBox).not.toBeNull();
    expect(wsBox).not.toBeNull();
    expect(chatBox!.width).toBeGreaterThanOrEqual(wsBox!.width - 2);
    expect(chatBox!.height).toBeGreaterThanOrEqual(wsBox!.height - 2);

    // Opening Timers makes it the sole visible window; the chat window hides.
    await chat.openTimersFromToolsMenu();
    await expect(timersWindow).toBeVisible();
    await expect(chatWindow).toBeHidden();
    await expect(timersTaskbarBtn).toBeVisible();

    // Geometry controls are dropped on mobile — only the close button remains.
    await expect(
      timersWindow.locator('[data-window-control="minimize"]'),
    ).toBeHidden();
    await expect(
      timersWindow.locator('[data-window-control="maximize"]'),
    ).toBeHidden();
    await expect(
      timersWindow.locator('[data-window-control="close"]'),
    ).toBeVisible();

    // Tapping the chat taskbar button switches back; Timers hides.
    await chatTaskbarBtn.click();
    await expect(chatWindow).toBeVisible();
    await expect(timersWindow).toBeHidden();
  });
});
