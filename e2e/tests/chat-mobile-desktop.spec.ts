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
    const mobileRail = page.getByTestId("app-mobile-menu-rail");
    const railToolsButton = page.getByTestId("app-mobile-menu-rail-tools");
    const railFileButton = page.getByTestId("app-mobile-menu-rail-file");
    const desktopChatTaskbarBtn = page.locator(
      '.desktop-taskbar__window-button[data-window-taskbar="chat"]',
    );
    const desktopTimersTaskbarBtn = page.locator(
      '.desktop-taskbar__window-button[data-window-taskbar="timers"]',
    );

    // The shell remains complete on mobile: the menu bar collapses to a rail of
    // icons, while the taskbar keeps the desktop's own window buttons.
    await expect(menuBar).toBeVisible();
    await expect(startButton).toBeVisible();
    await expect(desktopToolsMenu).toBeHidden();
    await expect(mobileMenuTrigger).toBeHidden();
    await expect(mobileRail).toBeVisible();
    await expect(railToolsButton).toBeVisible();
    await expect(desktopChatTaskbarBtn).toBeVisible();

    // The rail is the header, not a button in it: it spans what the logo and
    // the status zone leave, so the strip beside them is a touch target rather
    // than dead space.
    const headerBox = await page.getByTestId("app-header").boundingBox();
    const railBox = await mobileRail.boundingBox();
    expect(headerBox).not.toBeNull();
    expect(railBox).not.toBeNull();
    expect(railBox!.width).toBeGreaterThan(headerBox!.width * 0.6);
    await shot(page, "mobile-header-menu-rail");

    // The chat window fills the workspace (fullscreen app layout).
    await expect(chatWindow).toBeVisible();
    const wsBox = await workspace.boundingBox();
    const chatBox = await chatWindow.boundingBox();
    expect(chatBox).not.toBeNull();
    expect(wsBox).not.toBeNull();
    expect(chatBox!.width).toBeGreaterThanOrEqual(wsBox!.width - 2);
    expect(chatBox!.height).toBeGreaterThanOrEqual(wsBox!.height - 2);

    // Opening Timers makes it the sole visible window; the chat window hides.
    // The rail opens the drawer already on the tapped menu — no second tap on a
    // category to get there.
    await railToolsButton.click();
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
    await expect(toolsCategory).toHaveAttribute("aria-selected", "true");
    await expect(fileCategory).toHaveAttribute("aria-selected", "false");
    await expect(toolsSection).toBeVisible();
    await expect(fileSection).toBeHidden();
    await expect(timersMenuItem).toBeVisible();
    await expect(railToolsButton).toHaveAttribute("aria-expanded", "true");
    await shot(page, "mobile-menu-rail-opened-on-tools");

    // Another rail button swaps the section under the open drawer; the same one
    // puts it away.
    await railFileButton.click();
    await expect(mobileMenuDropdown).toBeVisible();
    await expect(fileSection).toBeVisible();
    await expect(toolsSection).toBeHidden();
    await expect(railToolsButton).toHaveAttribute("aria-expanded", "false");
    await railFileButton.click();
    await expect(mobileMenuDropdown).toBeHidden();

    await railToolsButton.click();
    await expect(toolsSection).toBeVisible();
    await expect(timersMenuItem).toBeVisible();
    await timersMenuItem.click();
    await expect(timersWindow).toBeVisible();
    await expect(chatWindow).toBeHidden();
    await expect(desktopTimersTaskbarBtn).toBeVisible();

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

    // Two open windows, two buttons: the strip squeezes them side by side
    // rather than hiding both behind a launcher, and tapping one switches to it
    // exactly as on the desktop.
    const chatBtnBox = await desktopChatTaskbarBtn.boundingBox();
    const timersBtnBox = await desktopTimersTaskbarBtn.boundingBox();
    expect(chatBtnBox).not.toBeNull();
    expect(timersBtnBox).not.toBeNull();
    expect(chatBtnBox!.y).toBeCloseTo(timersBtnBox!.y, 0);
    await shot(page, "mobile-taskbar-squeezed-window-buttons");

    await desktopChatTaskbarBtn.click();
    await expect(chatWindow).toBeVisible();
    await expect(timersWindow).toBeHidden();
  });

  test("exposes sidebar rails and keeps composer touch-sized", async ({
    page,
  }) => {
    await signedInUser(page, "mctrl");

    const conversationsRailButton = page.getByTestId(
      "conversations-rail-toggle",
    );
    const conversationsCollapseButton = page.getByTestId(
      "conversations-collapse-toggle",
    );
    const nicklistRailButton = page.getByTestId("nicklist-rail-toggle");
    const nicklistCollapseButton = page.getByTestId("nicklist-collapse-toggle");
    const searchButton = page.getByTestId("conversation-toolbar-search");
    const conversationsRail = page.getByTestId("conversations-rail");
    const nicklistRail = page.getByTestId("nicklist-rail");
    const conversations = page.getByTestId("conversations");
    const nicklist = page.getByTestId("nicklist");
    const searchBar = page.getByTestId("search-bar");
    const input = page.getByTestId("chat-input-field");

    await expect(conversationsRailButton).toBeVisible();
    await expect(nicklistRailButton).toBeVisible();
    await expect(conversationsCollapseButton).toBeHidden();
    await expect(nicklistCollapseButton).toBeHidden();
    await expect(conversationsRail).toBeVisible();
    await expect(nicklistRail).toBeVisible();
    await expect(searchButton).toBeVisible();
    await expect(
      page.getByTestId("conversation-toolbar-conversations"),
    ).toHaveCount(0);
    await expect(page.getByTestId("conversation-toolbar-nicklist")).toHaveCount(
      0,
    );
    await expect(conversations).toBeHidden();
    await expect(nicklist).toBeHidden();

    // A collapsed rail is chrome in the row, not an overlay: the conversation
    // starts where the left rail ends and stops where the right one begins, so
    // no message is written underneath either of them.
    const messageList = page.getByTestId("chat-message-list");
    const leftRailBox = await conversationsRail.boundingBox();
    const rightRailBox = await nicklistRail.boundingBox();
    const listBox = await messageList.boundingBox();
    expect(leftRailBox).not.toBeNull();
    expect(rightRailBox).not.toBeNull();
    expect(listBox).not.toBeNull();
    expect(listBox!.x).toBeGreaterThanOrEqual(
      leftRailBox!.x + leftRailBox!.width - 1,
    );
    expect(listBox!.x + listBox!.width).toBeLessThanOrEqual(
      rightRailBox!.x + 1,
    );
    await shot(page, "mobile-collapsed-rails-beside-conversation");

    await conversationsRailButton.click();
    await expect(conversations).toBeVisible();
    await expect(conversationsCollapseButton).toBeVisible();
    await expect(conversationsRail).toHaveCount(0);

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

    await conversationsCollapseButton.click();
    await expect(conversations).toBeHidden();
    await expect(conversationsCollapseButton).toBeHidden();
    await expect(conversationsRail).toBeVisible();

    await nicklistRailButton.click();
    await expect(nicklist).toBeVisible();
    await expect(nicklistCollapseButton).toBeVisible();
    await expect(nicklistRail).toHaveCount(0);

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

  test("drills the Start menu one level at a time", async ({ page }) => {
    await signedInUser(page, "mmenu");

    const startButton = page.locator("[data-window-start]");
    const menu = page.locator("[data-window-start-menu]");
    const accountGroup = page.getByTestId("start-menu-account-submenu");
    const accountItem = page.getByTestId("start-menu-item-open_account_dialog");
    const rootItem = page.getByTestId("start-menu-item-timers");

    await startButton.click();
    await expect(menu).toBeVisible();
    await expect(rootItem).toBeVisible();
    await expect(accountItem).toBeHidden();

    // Opening the group replaces the list instead of expanding inside it.
    await accountGroup.click();
    await expect(menu).toHaveAttribute("data-start-level", "submenu");
    await expect(accountItem).toBeVisible();
    await expect(rootItem).toBeHidden();
    await expect(accountGroup).toHaveAttribute("aria-expanded", "true");
    await shot(page, "mobile-start-menu-submenu-level");

    // The group's own row is the way back to the level above.
    await accountGroup.click();
    await expect(menu).toHaveAttribute("data-start-level", "root");
    await expect(rootItem).toBeVisible();
    await expect(accountItem).toBeHidden();
    await shot(page, "mobile-start-menu-root-level");
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
