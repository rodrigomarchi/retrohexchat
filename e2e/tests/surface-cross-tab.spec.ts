/**
 * @section Auth And Lifecycle
 * @flow K5 [done] A surface open beside the chat offers to go back to the tab that exists instead of opening a second chat, and says so when no tab answers
 * @flow K6 [done] Copy on a surface's share bar puts the address on the clipboard with no chat tab involved
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { shot } from "../helpers/screenshots";

/**
 * The two halves of cross-tab coordination, in the only place both are real.
 *
 * The server knows what is open — it monitors the process behind every surface
 * — and that is what decides which of the two shapes the link takes. Whether
 * the existing tab can actually be brought forward is the browser's answer, and
 * it needs two tabs in one profile to ask: `BroadcastChannel` is per origin per
 * profile, so two Playwright *contexts* would be two people.
 */
const PASSWORD = "testpass123";

test("a surface goes back to the chat tab instead of opening a second one (K5)", async ({
  browser,
}) => {
  const ctx = await browser.newContext();
  const chatTab = await ctx.newPage();

  try {
    const nick = uniqueNickname();
    const connect = new ConnectPage(chatTab);
    await connect.open();
    await connect.enterNickname(nick);
    await connect.registerWithPassword(PASSWORD);
    await new ChatPage(chatTab).waitUntilConnected();

    // A second tab of the same person, on a surface of its own.
    const playTab = await ctx.newPage();
    await playTab.goto("/play/hex_pong");
    await expect(playTab.getByTestId("retro-games-window")).toBeVisible();

    // The server already knows the chat is open, so the way back is the tab
    // that exists rather than a fresh one.
    const back = playTab.getByTestId("play-back-to-chat");
    await expect(back).toHaveAttribute("data-surface-path", "/chat");
    await shot(playTab, "surface-back-to-existing-chat");

    // Clicking it asks that tab to come forward; it answers, so no third page
    // is opened and the surface stays where it is.
    const pagesBefore = ctx.pages().length;
    await back.click();
    await expect(playTab).toHaveURL(/\/play\/hex_pong$/);
    expect(ctx.pages().length).toBe(pagesBefore);
    await expect(playTab.getByTestId("play-back-to-chat-note")).toHaveCount(0);

    // And with no chat tab left, the same link is a plain way in again.
    await chatTab.close();
    await expect(playTab.getByTestId("play-back-to-chat")).not.toHaveAttribute(
      "data-surface-path",
      "/chat",
      { timeout: 15_000 },
    );
  } finally {
    await ctx.close();
  }
});

test("a surface copies its own share link, with no chat behind it (K6)", async ({
  browser,
}) => {
  const ctx = await browser.newContext();
  await ctx.grantPermissions(["clipboard-read", "clipboard-write"]);
  const page = await ctx.newPage();

  try {
    const connect = new ConnectPage(page);
    await connect.open();
    await connect.enterNickname(uniqueNickname());
    await connect.registerWithPassword(PASSWORD);
    await new ChatPage(page).waitUntilConnected();

    // A surface in a tab of its own: nothing here has a chat viewport hook,
    // which is exactly why this used to be a readonly field and nothing else.
    await page.goto("/play/hex_pong");
    await page.getByTestId("share-create").click();

    const url = await page.getByTestId("share-url").inputValue();
    expect(url).toContain("/join/");

    await page.getByTestId("share-copy").click();

    const clipboard = await page.evaluate(() => navigator.clipboard.readText());
    expect(clipboard).toBe(url);
  } finally {
    await ctx.close();
  }
});
