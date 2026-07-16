import { Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

// A phone-sized viewport (below the 768px stacking breakpoint).
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
  test.use({ viewport: PHONE, isMobile: true, hasTouch: true });

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

  test("exposes mobile chat controls for sidebars and keeps composer touch-sized", async ({
    page,
  }) => {
    await signedInUser(page, "mctrl");

    const conversationsButton = page.getByTestId("chat-mobile-conversations");
    const nicklistButton = page.getByTestId("chat-mobile-nicklist");
    const searchButton = page.getByTestId("chat-mobile-search");
    const conversations = page.getByTestId("conversations");
    const nicklist = page.getByTestId("nicklist");
    const searchBar = page.getByTestId("search-bar");
    const input = page.getByTestId("chat-input-field");

    await expect(conversationsButton).toBeVisible();
    await expect(nicklistButton).toBeVisible();
    await expect(searchButton).toBeVisible();
    await expect(conversations).toBeHidden();
    await expect(nicklist).toBeHidden();

    await conversationsButton.click();
    await expect(conversations).toBeVisible();
    await page.getByTestId("conversations-close").click();
    await expect(conversations).toBeHidden();

    await nicklistButton.click();
    await expect(nicklist).toBeVisible();

    await searchButton.click();
    await expect(searchBar).toBeVisible();
    await expect(nicklist).toBeHidden();

    await searchBar.locator('[data-window-control="close"]').click();
    await expect(searchBar).toBeHidden();

    await input.click();
    await page.keyboard.type("/");
    const autocomplete = page.getByTestId("autocomplete-dropdown");
    await expect(autocomplete).toBeVisible();
    const autocompleteBox = await autocomplete.boundingBox();
    expect(autocompleteBox).not.toBeNull();
    expect(autocompleteBox!.height).toBeLessThanOrEqual(230);

    const inputBox = await input.boundingBox();
    expect(inputBox).not.toBeNull();
    expect(inputBox!.height).toBeGreaterThanOrEqual(40);
  });

  test("collapses mobile taskbar while the virtual keyboard is open", async ({
    page,
  }) => {
    await signedInUser(page, "mkey");

    const workspace = page
      .getByTestId("chat-desktop")
      .locator(".desktop__workspace");
    const taskbar = page.locator(".desktop-taskbar");
    const input = page.getByTestId("chat-input-field");

    await input.click();
    await expect(taskbar).toBeVisible();
    const workspaceBefore = await workspace.boundingBox();
    expect(workspaceBefore).not.toBeNull();

    await page.evaluate(() => {
      document.documentElement.classList.add("rhc-keyboard-open");
    });

    await expect(taskbar).toBeHidden();
    const workspaceAfter = await workspace.boundingBox();
    expect(workspaceAfter).not.toBeNull();
    expect(workspaceAfter!.height).toBeGreaterThan(
      workspaceBefore!.height + 20,
    );

    await page.evaluate(() => {
      document.documentElement.classList.remove("rhc-keyboard-open");
    });
    await expect(taskbar).toBeVisible();
  });
});
