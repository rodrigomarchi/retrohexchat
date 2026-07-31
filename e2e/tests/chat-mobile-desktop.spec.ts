import { Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

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
    await signedInUser(page);

    const desktop = page.getByTestId("chat-desktop");
    const workspace = desktop.locator(".desktop__workspace");
    const chatWindow = page.getByTestId("chat-window");
    const timersWindow = page.getByTestId("timers-window");
    const menuBar = page.getByTestId("menu-bar");
    const startButton = page.locator("[data-window-start]");
    const desktopToolsMenu = menuBar
      .locator(".app-menu-bar__desktop-menu button[data-menubar-trigger]")
      .filter({ hasText: "Tools" });
    const mobileMenuTrigger = page.getByTestId("app-mobile-menu-trigger");
    const desktopChatTaskbarBtn = page.locator(
      '.desktop-taskbar__window-button[data-window-taskbar="chat"]',
    );
    const desktopTimersTaskbarBtn = page.locator(
      '.desktop-taskbar__window-button[data-window-taskbar="timers"]',
    );
    const mobileTaskSwitcherTrigger = page.getByTestId(
      "mobile-task-switcher-trigger",
    );
    const mobileTaskSwitcherPanel = page.locator("[data-mobile-task-switcher]");

    // The shell remains complete on mobile, but dense horizontal controls
    // collapse behind semantic launchers.
    await expect(menuBar).toBeVisible();
    await expect(startButton).toBeVisible();
    await expect(desktopToolsMenu).toBeHidden();
    await expect(mobileMenuTrigger).toBeVisible();
    await expect(desktopChatTaskbarBtn).toBeHidden();
    await expect(mobileTaskSwitcherTrigger).toBeVisible();

    // The chat window fills the workspace (fullscreen app layout).
    await expect(chatWindow).toBeVisible();
    const wsBox = await workspace.boundingBox();
    const chatBox = await chatWindow.boundingBox();
    expect(chatBox).not.toBeNull();
    expect(wsBox).not.toBeNull();
    expect(chatBox!.width).toBeGreaterThanOrEqual(wsBox!.width - 2);
    expect(chatBox!.height).toBeGreaterThanOrEqual(wsBox!.height - 2);

    // Opening Timers makes it the sole visible window; the chat window hides.
    await mobileMenuTrigger.click();
    const mobileMenuDropdown = menuBar.locator(
      "[data-menubar-dropdown]:not(.u-hidden)",
    );
    const fileCategory = mobileMenuDropdown.getByTestId(
      "app-mobile-menu-category-file",
    );
    const toolsCategory = mobileMenuDropdown.getByTestId(
      "app-mobile-menu-category-tools",
    );
    const fileSection = mobileMenuDropdown.getByTestId(
      "app-mobile-menu-section-file",
    );
    const toolsSection = mobileMenuDropdown.getByTestId(
      "app-mobile-menu-section-tools",
    );
    const timersMenuItem = mobileMenuDropdown.getByTestId(
      "context-menu-item-open_timers_dialog",
    );
    await expect(mobileMenuDropdown).toBeVisible();
    await expect(fileCategory).toBeVisible();
    await expect(toolsCategory).toBeVisible();
    await expect(fileCategory).toHaveAttribute("aria-selected", "true");
    await expect(fileSection).toBeVisible();
    await expect(toolsSection).toBeHidden();
    await expect(timersMenuItem).toBeHidden();

    await toolsCategory.click();
    await expect(fileCategory).toHaveAttribute("aria-selected", "false");
    await expect(toolsCategory).toHaveAttribute("aria-selected", "true");
    await expect(fileSection).toBeHidden();
    await expect(toolsSection).toBeVisible();
    await expect(timersMenuItem).toBeVisible();
    await timersMenuItem.click();
    await expect(timersWindow).toBeVisible();
    await expect(chatWindow).toBeHidden();
    await expect(desktopTimersTaskbarBtn).toBeHidden();

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

    // Tapping the mobile task switcher exposes a vertical list; choosing Chat
    // switches back without horizontal taskbar scrolling.
    await mobileTaskSwitcherTrigger.click();
    await expect(mobileTaskSwitcherPanel).toBeVisible();
    await mobileTaskSwitcherPanel
      .locator('[data-mobile-task-switcher-item][data-window-taskbar="chat"]')
      .click();
    await expect(chatWindow).toBeVisible();
    await expect(timersWindow).toBeHidden();
  });

  test("exposes chat toolbar controls for sidebars and keeps composer touch-sized", async ({
    page,
  }) => {
    await signedInUser(page, "mctrl");

    const conversationsButton = page.getByTestId(
      "conversation-toolbar-conversations",
    );
    const nicklistButton = page.getByTestId("conversation-toolbar-nicklist");
    const searchButton = page.getByTestId("conversation-toolbar-search");
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

    // The tab strip is bottom-anchored chrome the sidebar overlay reaches over,
    // so what matters is stacking, not geometry: the topmost element at the
    // strip's centre must still be the tab strip, or tabs are untappable.
    const tabBar = page.getByTestId("tab-bar");
    await expect(tabBar).toBeVisible();
    const tabBarBox = await tabBar.boundingBox();
    expect(tabBarBox).not.toBeNull();
    const hitsTabBar = await page.evaluate(
      ({ x, y }) =>
        document.elementFromPoint(x, y)?.closest('[data-testid="tab-bar"]') !==
        null,
      {
        x: tabBarBox!.x + tabBarBox!.width / 2,
        y: tabBarBox!.y + tabBarBox!.height / 2,
      },
    );
    expect(hitsTabBar).toBe(true);
    await shot(page, "mobile-sidebar-over-tab-strip");

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
