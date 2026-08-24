/**
 * @section MB - Mobile & Touch
 * @flow MB1 [done] The phone desktop shows one fullscreen window at a time, switched via the taskbar
 * @flow MB2 [done] Sidebars are reachable from the toolbar and the composer stays touch-sized
 * @flow MB10 [done] Every tab and control fits the phone's tab strip without clipping
 * @flow MB3 [done] The Start menu drills one level at a time
 * @flow MB4 [done] The mobile taskbar collapses while the virtual keyboard is open
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
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

    // The rail is the menu strip, not a button on it: it spans the width under
    // the window's title bar, so the strip is a touch target rather than dead
    // space beside a lone hamburger.
    const stripBox = await chatWindow
      .locator("[data-window-menu]")
      .boundingBox();
    const railBox = await mobileRail.boundingBox();
    expect(stripBox).not.toBeNull();
    expect(railBox).not.toBeNull();
    expect(railBox!.width).toBeGreaterThan(stripBox!.width * 0.6);
    await shot(page, "mobile-window-menu-rail");

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

  test("reaches the sidebars from the toolbar and keeps composer touch-sized", async ({
    page,
  }) => {
    const { chat } = await signedInUser(page, "mctrl");

    const conversationsToggle = page.getByTestId(
      "conversation-toolbar-conversations",
    );
    const conversationsCollapseButton = page.getByTestId(
      "conversations-collapse-toggle",
    );
    const nicklistToggle = page.getByTestId("conversation-toolbar-nicklist");
    const nicklistCollapseButton = page.getByTestId("nicklist-collapse-toggle");
    const conversationsRail = page.getByTestId("conversations-rail");
    const nicklistRail = page.getByTestId("nicklist-rail");
    const conversations = page.getByTestId("conversations");
    const nicklist = page.getByTestId("nicklist");
    const searchBar = page.getByTestId("search-bar");
    const input = page.getByTestId("chat-input-field");

    await expect(conversationsToggle).toBeVisible();
    await expect(nicklistToggle).toBeVisible();
    // Find is reached from the menu bar on every viewport — the strip carries
    // no button for it.
    await expect(page.getByTestId("conversation-toolbar-search")).toHaveCount(
      0,
    );
    await expect(conversationsCollapseButton).toBeHidden();
    await expect(nicklistCollapseButton).toBeHidden();
    await expect(conversations).toBeHidden();
    await expect(nicklist).toBeHidden();

    // A collapsed sidebar costs the phone nothing: the rails that carry the
    // toggles on a desk are not rendered here, so the conversation and the
    // composer both run the full width of the window.
    await expect(conversationsRail).toBeHidden();
    await expect(nicklistRail).toBeHidden();
    const chatWindowBox = await page
      .locator('[data-window-id="chat"]')
      .boundingBox();
    const messageList = page.getByTestId("chat-message-list");
    const listBox = await messageList.boundingBox();
    const composerBox = await page.getByTestId("chat-input-form").boundingBox();
    expect(chatWindowBox).not.toBeNull();
    expect(listBox).not.toBeNull();
    expect(composerBox).not.toBeNull();
    // Nothing but the window's own border stands beside either of them.
    expect(listBox!.x - chatWindowBox!.x).toBeLessThanOrEqual(8);
    expect(composerBox!.x - chatWindowBox!.x).toBeLessThanOrEqual(8);
    expect(
      chatWindowBox!.x + chatWindowBox!.width - (listBox!.x + listBox!.width),
    ).toBeLessThanOrEqual(8);
    await shot(page, "mobile-conversation-without-rails");

    await conversationsToggle.click();
    await expect(conversations).toBeVisible();
    await expect(conversationsCollapseButton).toBeVisible();

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

    // The strip carries the tabs and the conversation's controls in one row on
    // a screen that barely fits them. The tabs are the navigation and must
    // never be the half that gets squeezed: when the row runs out of width the
    // controls scroll, and the tablist collapsing to zero — which once made
    // every tab vanish on a phone — is the failure this guards.
    const strip = page.getByTestId("tab-bar");
    const tablist = strip.locator('[role="tablist"]');
    await expect(tablist).toBeVisible();
    for (const label of ["Status", "#lobby", "Space"]) {
      await expect(strip.getByRole("tab", { name: label })).toBeVisible();
    }
    const fit = await page.evaluate(() => {
      const el = document.querySelector('[data-testid="tab-bar"]')!;
      const list = el.querySelector('[role="tablist"]')!;
      return {
        stripOverflow: el.scrollWidth - el.clientWidth,
        tablistOverflow: list.scrollWidth - list.clientWidth,
        tablistWidth: list.clientWidth,
      };
    });
    expect(fit.tablistWidth).toBeGreaterThan(0);
    expect(fit.tablistOverflow).toBe(0);
    expect(fit.stripOverflow).toBe(0);

    await conversationsCollapseButton.click();
    await expect(conversations).toBeHidden();
    await expect(conversationsCollapseButton).toBeHidden();
    await expect(conversationsToggle).toHaveAttribute("aria-pressed", "false");

    await nicklistToggle.click();
    await expect(nicklist).toBeVisible();
    await expect(nicklistCollapseButton).toBeVisible();

    await chat.openSearchFromMobileMenu();
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
    // Disconnect is the one entry that sits at the root itself; everything else
    // lives a level down, which is what keeps the menu on screen without a
    // scroll the flyouts could not survive.
    const rootItem = page.getByTestId("start-menu-item-disconnect");

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
