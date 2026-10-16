/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW24 [done] Without an account /chat opens read-only: a visitor watches a channel live under a Guest name, members see them under Visitors, and any action opens the Connect window
 * @flow PW25 [done] A visitor who registers from the chat's Connect window comes back to the channel they were watching, now as a member
 * @flow PW26 [done] No link leaves a visitor's chat: a message URL (plain, Ctrl or middle click) and a game in the desktop Games folder open the Connect window naming the feature, and no tab opens
 * @flow PW27 [done] A game, the arcade or a call opened by address without an account lands in the chat with the Connect window naming it, and registering there returns to that address
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import {
  closeUsers,
  newSignedInUser,
  uniqueChannel,
} from "../helpers/chatUsers";
import { shot } from "../helpers/screenshots";

async function openAsVisitor(page: Page, path: string) {
  await page.addInitScript(() => {
    try {
      window.localStorage.setItem("retro_hex_chat_tips_suppressed", "true");
    } catch {
      /* localStorage unavailable — the tips only overlay, they do not block */
    }
  });
  await page.goto(path);
  await page.waitForFunction(
    () =>
      !!document
        .querySelector("[data-phx-main]")
        ?.classList.contains("phx-connected"),
    { timeout: 10_000 },
  );
  await expect(page.getByTestId("visitor-composer")).toBeVisible();
}

test("a visitor watches a channel live and any action asks them to sign in (PW24, PW25)", async ({
  browser,
}) => {
  const member = await newSignedInUser(browser, "host");
  const channel = uniqueChannel("pub");

  await member.chat.sendMessage(`/join ${channel}`);
  await member.chat.expectTabVisible(channel);
  await member.chat.sendMessage("said before anybody was watching");

  const visitorCtx = await browser.newContext();
  const visitor = await visitorCtx.newPage();

  try {
    await openAsVisitor(visitor, `/chat?join=${encodeURIComponent(channel)}`);

    // The channel the link named, with its history, and no message box.
    await expect(visitor.getByTestId("chat-message-list")).toContainText(
      "said before anybody was watching",
    );
    // The same message box a member has — it just cannot be typed into.
    await expect(visitor.getByTestId("chat-input-field")).toBeVisible();
    await visitor.keyboard.type("hello");
    await expect(visitor.getByTestId("chat-input-field")).toHaveValue("");
    const guestName = (
      await visitor
        .locator('[data-testid^="nicklist-guest-"][data-current="true"]')
        .innerText()
    ).trim();
    expect(guestName).toMatch(/^Guest\d+$/);
    await shot(visitor, "visitor-watching");

    // Live, as it is said.
    await member.chat.sendMessage("hello to whoever is reading");
    await expect(visitor.getByTestId("chat-message-list")).toContainText(
      "hello to whoever is reading",
    );

    // The member sees the visitor, apart from the members.
    const guests = member.page.getByTestId("nicklist-section-guest");
    await expect(guests).toBeVisible();
    await expect(
      member.page.getByTestId(`nicklist-guest-${guestName}`),
    ).toBeVisible();
    await shot(member.page.getByTestId("nicklist"), "member-sees-visitor");

    // Right-clicking a nick is an action: it opens the Connect window, not a menu.
    await visitor
      .getByTestId(`nicklist-item-${member.nick}`)
      .click({ button: "right" });
    const connectWindow = visitor.getByTestId("visitor-connect-window");
    await expect(connectWindow).toBeVisible();
    await expect(
      visitor.getByTestId("context-menu-nicklist-context-menu"),
    ).toBeHidden();
    await shot(visitor, "visitor-asked-to-sign-in");

    // Registering there returns them to the channel they were reading.
    const newNick = uniqueNickname("was");
    const connect = new ConnectPage(visitor);
    await connectWindow.locator("#nickname").fill(newNick);
    await connectWindow.getByTestId("connect-btn").click();
    await connect.registerWithPassword("pass12345");

    const chat = new ChatPage(visitor);
    await chat.waitUntilConnected();
    await expect(visitor).toHaveURL(/\/chat(\?.*)?$/);
    await chat.expectTabVisible(channel);
    await expect(visitor.getByTestId("visitor-composer")).toHaveCount(0);
    await shot(visitor, "visitor-signed-in");

    // On the member's side the guest is gone and the new member is in.
    await expect(
      member.page.getByTestId(`nicklist-guest-${guestName}`),
    ).toHaveCount(0);
    await expect(
      member.page.getByTestId(`nicklist-item-${newNick}`),
    ).toBeVisible();
  } finally {
    await visitorCtx.close();
    await closeUsers([member]);
  }
});

test("the visitor's chat on a phone (PW24)", async ({ browser }) => {
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 },
  });
  const page = await ctx.newPage();

  try {
    // The lobby opens even with nobody in it: it is where every visitor lands.
    await openAsVisitor(page, "/chat");
    await expect(page.getByTestId("tab-bar")).toContainText("#lobby");
    await shot(page, "visitor-phone");

    await page.getByTestId("visitor-composer").click();
    await expect(page.getByTestId("visitor-connect-window")).toBeVisible();
    await shot(page, "visitor-phone-sign-in");
  } finally {
    await ctx.close();
  }
});

test("no link leaves a visitor's chat (PW26)", async ({ browser }) => {
  const member = await newSignedInUser(browser, "lnk");
  const channel = uniqueChannel("lnk");
  await member.chat.sendMessage(`/join ${channel}`);
  await member.chat.expectTabVisible(channel);
  await member.chat.sendMessage("look at https://example.com/page please");

  const ctx = await browser.newContext();
  const visitor = await ctx.newPage();
  const reason = visitor.getByTestId("visitor-connect-reason");
  const connectWindow = visitor.getByTestId("visitor-connect-window");

  try {
    await openAsVisitor(visitor, `/chat?join=${encodeURIComponent(channel)}`);
    const messageLink = visitor
      .getByTestId("chat-message-list")
      .locator("a.chat-link")
      .first();
    await expect(messageLink).toBeVisible();

    // However it is clicked, a pasted site opens the window, never a tab.
    for (const click of [
      () => messageLink.click(),
      () => messageLink.click({ modifiers: ["ControlOrMeta"] }),
      () => messageLink.click({ button: "middle" }),
    ]) {
      const popups: Page[] = [];
      ctx.on("page", (page) => popups.push(page));
      await click();
      await expect(connectWindow).toBeVisible();
      await expect(reason).toContainText("open links");
      expect(popups).toHaveLength(0);
      await visitor.keyboard.press("Escape");
      await expect(connectWindow).toBeHidden();
    }
    await messageLink.click();
    await shot(visitor, "visitor-link-held");
    await visitor.keyboard.press("Escape");

    // A game in the desktop's Games folder is a game, and says so.
    const chat = new ChatPage(visitor);
    await chat.openGamesFolder();
    await chat.gamesFolderGrid.locator('a[href^="/play"]').first().click();
    await expect(connectWindow).toBeVisible();
    await expect(reason).toContainText("Games are for registered players.");
    await expect(visitor).toHaveURL(/\/chat/);
    await shot(visitor, "visitor-game-held");
  } finally {
    await ctx.close();
    await closeUsers([member]);
  }
});

test("a game, the arcade or a call opened by address asks to sign in and comes back (PW27)", async ({
  browser,
}) => {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  const reason = page.getByTestId("visitor-connect-reason");

  try {
    for (const [path, sentence] of [
      ["/play/arcade/doom_shareware", "Games are for registered players."],
      ["/call/sometoken", "Calls are for registered members."],
    ]) {
      await openAsVisitor(page, path);
      await expect(page).toHaveURL(/\/chat\?/);
      await expect(page.getByTestId("visitor-connect-window")).toBeVisible();
      await expect(reason).toContainText(sentence);
    }
    await shot(page, "visitor-call-by-address");

    // From a game's address: registering there ends on that address.
    await openAsVisitor(page, "/play");
    await expect(reason).toContainText("Games are for registered players.");
    await shot(page, "visitor-play-by-address");

    const connectWindow = page.getByTestId("visitor-connect-window");
    await connectWindow.locator("#nickname").fill(uniqueNickname("ply"));
    await connectWindow.getByTestId("connect-btn").click();
    await new ConnectPage(page).registerWithPassword("pass12345");

    await expect(page).toHaveURL(/\/play$/);
    await shot(page, "visitor-back-on-play");
  } finally {
    await ctx.close();
  }
});
