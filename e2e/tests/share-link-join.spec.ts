/**
 * @section Auth And Lifecycle
 * @flow K4 [done] A shared game link minted in one browser is followed from another with no session: the public card asks for a connect, and the connect lands back on the link
 * @flow K9 [done] A conference link pasted into a channel draws a live card that counts up on its own when somebody joins the call, with no reload
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Page, expect, test } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { uniqueChannel } from "../helpers/chatUsers";
import {
  closeGroupCallUsers,
  newGroupCallUser,
} from "../helpers/groupCallUsers";

const PASSWORD = "testpass123";

test("a shared link brings a stranger all the way in (K4)", async ({
  browser,
}) => {
  const sharerContext = await browser.newContext();
  const strangerContext = await browser.newContext();
  const sharerTab = await sharerContext.newPage();
  const strangerTab = await strangerContext.newPage();

  try {
    // The sharer registers, opens a game and mints a link.
    const connect = new ConnectPage(sharerTab);
    await connect.open();
    await connect.enterNickname(uniqueNickname());
    await connect.registerWithPassword(PASSWORD);
    await new ChatPage(sharerTab).waitUntilConnected();

    await sharerTab.goto("/play/hex_pong");
    await sharerTab.getByTestId("share-create").click();

    const shareUrl = await sharerTab.getByTestId("share-url").inputValue();
    expect(shareUrl).toContain("/join/");

    // A different browser, no cookie: the public card, and no way in yet.
    const joinPath = new URL(shareUrl).pathname;
    await strangerTab.goto(joinPath);
    await expect(strangerTab.getByTestId("join-card")).toBeVisible();

    // Following it goes to connect carrying where to come back to.
    await strangerTab.getByTestId("join-enter").click();
    await expect(strangerTab).toHaveURL(/\/connect\?return_to=/);

    const strangerConnect = new ConnectPage(strangerTab);
    await strangerConnect.enterNickname(uniqueNickname());
    await strangerConnect.registerWithPassword(PASSWORD);

    // The connect honoured return_to: back on the card, now with a way in.
    await expect(strangerTab).toHaveURL(new RegExp(`${joinPath}$`));
    await strangerTab.getByTestId("join-enter").click();

    await expect(strangerTab).toHaveURL(/\/play\/hex_pong$/);
    await expect(strangerTab.getByTestId("retro-games-window")).toBeVisible();
  } finally {
    await sharerContext.close();
    await strangerContext.close();
  }
});

/**
 * The promise the card exists for: it is the room *now*, not a screenshot of
 * the moment it was pasted. Only a browser can tell the difference — the count
 * has to change with nobody touching the page, which is the one thing a
 * component test cannot say.
 */
test("the card in the conversation counts up on its own (K9)", async ({
  browser,
}) => {
  test.setTimeout(90_000);
  const ana = await newGroupCallUser(browser, "cardana");
  const bob = await newGroupCallUser(browser, "cardbob");
  const channel = uniqueChannel("cardlive");

  try {
    for (const user of [ana, bob]) {
      await user.chat.sendMessage(`/join ${channel}`);
      await user.chat.expectTabVisible(channel);
      await user.chat.switchToTab(channel);
      await expect(user.page.getByTestId("group-call-open")).toBeEnabled();
    }

    // Ana opens the call and mints its link from the conference's own share bar.
    await joinConference(ana.page);
    await ana.page.getByTestId("share-create").click();
    const shareUrl = await ana.page.getByTestId("share-url").inputValue();
    expect(shareUrl).toContain("/join/");

    // Out of the way, so the channel and its composer are reachable again.
    await ana.page
      .getByTestId("group-call-window")
      .locator('[data-window-control="minimize"]')
      .click();
    await expect(ana.page.getByTestId("group-call-window")).toBeHidden();

    await ana.chat.sendMessage(shareUrl);

    // Bob reads the message and gets the room, not the address.
    const card = bob.page.getByTestId("share-message-card").last();
    await expect(card).toBeVisible({ timeout: 15_000 });
    await expect(card).toHaveAttribute("data-share-kind", "call");
    await expect(card).toHaveAttribute("data-share-state", "live");
    await expect(card).toHaveAttribute("data-share-count", "1");

    // Nobody touches Bob's page: the count moves because the room did.
    await joinConference(bob.page);
    await expect(card).toHaveAttribute("data-share-count", "2", {
      timeout: 20_000,
    });

    // And the user list says who is in there, from the same summary.
    await bob.page
      .getByTestId("group-call-window")
      .locator('[data-window-control="minimize"]')
      .click();
    await expect(
      bob.page.getByTestId(`nicklist-in-call-${ana.nick}`),
    ).toBeVisible({ timeout: 15_000 });
  } finally {
    await closeGroupCallUsers([ana, bob]);
  }
});

async function joinConference(page: Page) {
  await page.getByTestId("group-call-open").click();
  await expect(page.getByTestId("group-call-prejoin")).toBeVisible();
  await page.getByTestId("group-call-prejoin-join").click();
  await expect(page.getByTestId("group-call-window")).toBeVisible();
}
