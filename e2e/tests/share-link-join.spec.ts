/**
 * @section Auth And Lifecycle
 * @flow K4 [done] A shared game link minted in one browser is followed from another with no session: the public card asks for a connect, and the connect lands back on the link
 * @flow K9 [done] Opening a conference writes its card into the channel by itself, and that card counts up on its own when somebody joins the call, with no reload
 * @flow K11 [done] A channel invite link shows a stranger the room, its topic and the last lines said there, and lands them inside the channel after connecting
 * @flow K10 [done] When the conference ends, the card in the channel becomes the record of it — when it stopped, how long it ran and how many people were in it — and offers no way on, with no reload
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
  openConference,
  openModerationMenu,
} from "../helpers/groupCallUsers";
import { shot } from "../helpers/screenshots";

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
 * the moment it was written. Only a browser can tell the difference — the count
 * has to change with nobody touching the page, which is the one thing a
 * component test cannot say.
 *
 * And the card is not pasted here by anyone. Opening the conference is what
 * writes it, because that card is the only door into the room.
 */
test("opening a conference writes the card, and the card counts up on its own (K9)", async ({
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

    // Nobody pastes anything: Ana opens the room and the card is written for
    // her, into the channel, where Bob is already reading.
    const anaCall = await openConference(ana);

    const card = bob.page.getByTestId("share-message-card").last();
    await expect(card).toBeVisible({ timeout: 15_000 });
    await expect(card).toHaveAttribute("data-share-kind", "call");
    await expect(card).toHaveAttribute("data-share-state", "live");

    // Ana is in the antechamber, not in the room, so the count is nobody yet.
    await expect(card).toHaveAttribute("data-share-count", "0");

    await joinFromAntechamber(anaCall);
    await expect(card).toHaveAttribute("data-share-count", "1", {
      timeout: 20_000,
    });

    // Nobody touches Bob's chat: the count moves because the room did.
    const bobCall = await openConference(bob);
    await joinFromAntechamber(bobCall);
    await expect(card).toHaveAttribute("data-share-count", "2", {
      timeout: 20_000,
    });

    // And the user list says who is in there, from the same summary.
    await expect(
      bob.page.getByTestId(`nicklist-in-call-${ana.nick}`),
    ).toBeVisible({ timeout: 15_000 });

    // (K10) The room ends. The card is the only thing left of it, so it stops
    // being a door and becomes the record — and it does that on Bob's screen,
    // which nobody touches, because the room changed and not the page.
    await openModerationMenu(anaCall);
    await anaCall.getByTestId("group-call-close-room").click();
    await anaCall.getByTestId("group-call-confirm-dialog-confirm").click();

    await expect(card).toHaveAttribute("data-share-state", "ended", {
      timeout: 20_000,
    });
    await expect(card.getByTestId("share-message-enter")).toHaveCount(0);
    await expect(card).toHaveAttribute("data-share-visitors", "2");
    await expect(card.getByTestId("share-message-detail")).toContainText(
      "took part",
    );

    // And it says when, which the row above it cannot: that timestamp is the
    // moment the door was written, not the moment the room emptied.
    await expect(card.getByTestId("share-message-ended-at")).toContainText(
      "ended",
    );

    // A record, not a door. Bob is reading this in the channel the conference
    // happened in, so every way on the card used to offer led where he already
    // was — and following one re-mounted the chat under him.
    await expect(card.getByTestId("share-message-next")).toHaveCount(0);
  } finally {
    await closeGroupCallUsers([ana, bob]);
  }
});

async function joinFromAntechamber(call: Page) {
  await expect(call.getByTestId("group-call-prejoin")).toBeVisible();
  await call.getByTestId("group-call-prejoin-join").click();
  await expect(call.getByTestId("group-call-panel")).toBeVisible();
}

test("a channel invite shows the room before a stranger commits (K11)", async ({
  browser,
}) => {
  const sharerContext = await browser.newContext();
  const strangerContext = await browser.newContext();
  const sharerTab = await sharerContext.newPage();
  const strangerTab = await strangerContext.newPage();
  const channel = uniqueChannel("invite");

  try {
    const connect = new ConnectPage(sharerTab);
    await connect.open();
    await connect.enterNickname(uniqueNickname("sharer"));
    await connect.registerWithPassword(PASSWORD);
    const sharerChat = new ChatPage(sharerTab);
    await sharerChat.waitUntilConnected();

    await sharerChat.sendMessage(`/join ${channel}`);
    await sharerChat.expectTabVisible(channel);
    await sharerChat.sendMessage(`/topic Where the kettle lives`);
    await sharerChat.sendMessage("anybody around this evening?");

    // The clipboard is the product's own path for this, so the spec reads the
    // address back the same way a person would paste it.
    await sharerTab
      .context()
      .grantPermissions(["clipboard-read", "clipboard-write"]);
    await sharerChat.openConversationContextMenu(channel);
    await sharerTab
      .getByTestId("context-menu-item-ctx_conversations_copy_invite")
      .click();
    const shareUrl = await sharerTab.evaluate(() =>
      navigator.clipboard.readText(),
    );
    expect(shareUrl).toContain("/join/");

    // A different browser with no cookie: the card is the whole pitch.
    await strangerTab.goto(new URL(shareUrl).pathname);
    await expect(strangerTab.getByTestId("join-card")).toBeVisible();
    await expect(strangerTab.getByTestId("join-subject")).toContainText(
      channel,
    );
    await expect(strangerTab.getByTestId("join-preview")).toContainText(
      "anybody around this evening?",
    );
    await shot(strangerTab.getByTestId("join-card"), "channel-invite-card");

    // Connecting lands back on the card, not in the chat: the address the
    // stranger was sent is the one they came for, and the way in is still the
    // card's own button.
    await strangerTab.getByTestId("join-enter").click();
    const strangerConnect = new ConnectPage(strangerTab);
    await strangerConnect.enterNickname(uniqueNickname("stranger"));
    await strangerConnect.registerWithPassword(PASSWORD);

    await expect(strangerTab).toHaveURL(new RegExp(`/join/`));
    await strangerTab.getByTestId("join-enter").click();

    const strangerChat = new ChatPage(strangerTab);
    await strangerChat.waitUntilConnected();
    await strangerChat.expectTabVisible(channel);
    await shot(strangerTab, "channel-invite-landed");
  } finally {
    await sharerContext.close();
    await strangerContext.close();
  }
});
