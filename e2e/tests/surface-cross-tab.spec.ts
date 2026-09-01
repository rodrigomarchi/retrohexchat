/**
 * @section Auth And Lifecycle
 * @flow K5 [done] A surface open beside the chat offers to go back to the tab that exists instead of opening a second chat, and says so when no tab answers
 * @flow K6 [done] Copy on a surface's share bar puts the address on the clipboard with no chat tab involved
 * @flow K7 [done] Opening the conference you are already in at its own address takes the seat rather than adding one: the other participant still sees a single row for you, and the room still counts two
 * @flow K8 [done] With the conference open at its own address and not in the chat's window, the chat's status bar says the call is in another tab and is a way over to it
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
    // The note stays hidden while a tab is answering. Asserted on the element
    // rather than on its absence: this used to be `toHaveCount(0)`, which was
    // true because nothing rendered a note at all, and so could never fail.
    await expect(playTab.getByTestId("play-back-to-chat-note")).toHaveAttribute(
      "data-visible",
      "false",
    );

    // Now the half that only degrading covers: the tab exists — the server still
    // says so, so the link keeps the "go back" shape — but its answer never
    // arrives. That is the permanent state of a chat tab in another browser
    // profile, on another monitor, or on the laptop in the other room, because
    // `BroadcastChannel` crosses none of those. Reproduced by dropping the grant
    // on its way out of the chat tab, which is the same silence from the
    // surface's side.
    await chatTab.evaluate(() => {
      const original = BroadcastChannel.prototype.postMessage;
      BroadcastChannel.prototype.postMessage = function (message) {
        if (message && message.type === "surface:focused") return;
        return original.call(this, message);
      };
    });
    await back.click();
    await expect(playTab.getByTestId("play-back-to-chat-note")).toHaveAttribute(
      "data-visible",
      "true",
      { timeout: 15_000 },
    );
    // Still here, and still one tab: saying so is the whole point, and opening a
    // second chat instead would be the takeover this link exists to avoid.
    await expect(playTab).toHaveURL(/\/play\/hex_pong$/);
    expect(ctx.pages().length).toBe(pagesBefore);
    await shot(playTab, "surface-back-to-chat-no-answer");

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

/**
 * Wave 6 §1.3 asked for this one and it was never written: the tab link changes
 * shape for a room you are already in, and the reason it does is that a second
 * seat is what would happen otherwise. Only the second half is a promise about
 * the domain, and only a browser can make the two tabs real — the seat is keyed
 * on the person, and two Playwright contexts would be two people.
 */
test("opening the conference you are in at its own address does not add a second participant (K7)", async ({
  browser,
}) => {
  test.setTimeout(90_000);
  const alice = await newGroupCallUser(browser, "xtca");
  const bob = await newGroupCallUser(browser, "xtcb");
  const channel = uniqueChannel("xtabcall");

  try {
    for (const user of [alice, bob]) {
      await user.chat.sendMessage(`/join ${channel}`);
      await user.chat.expectTabVisible(channel);
      await user.chat.switchToTab(channel);
      await expect(user.page.getByTestId("group-call-open")).toBeEnabled();
    }

    await joinConference(alice.page);
    await joinConference(bob.page);
    await expect(bob.page.getByTestId("group-call-window")).toBeVisible();

    await openPeople(bob.page);
    await expect(participantRows(bob.page, alice.nick)).toHaveCount(1);
    await expect(participantRows(bob.page)).toHaveCount(2);

    // The badge lives on the channel toolbar, under a maximized conference
    // window. Getting the window out of the way first is not the test being
    // careful — the badge is only reachable in that state, which is also the
    // only state in which somebody would be looking for it.
    await bob.page
      .getByTestId("group-call-window")
      .locator('[data-window-control="minimize"]')
      .click();
    await expect(bob.page.getByTestId("group-call-window")).toBeHidden();

    // The room's own address, taken from the control that offers it rather
    // than assembled here: the badge is the only place that knows the current
    // room token, and a second spelling of that would drift.
    await bob.page.getByTestId("group-call-channel-popover-toggle").click();
    const tabLink = bob.page.getByTestId("group-call-channel-popover-tab");
    await expect(tabLink).toBeVisible();
    const callPath = await tabLink.getAttribute("href");
    expect(callPath).toMatch(/^\/call\//);

    // Being in the room is not having its address open: nobody has a `/call`
    // tab yet, so the link is still the plain "open" shape. The shape tracks
    // the open set, not the seat.
    await expect(tabLink).toHaveAttribute("data-surface-open", "false");

    // Follow it anyway — middle-click, a bookmark, or the fallback after no
    // tab answers all land here, and that path must not cost a seat.
    const aliceSecondTab = await alice.ctx.newPage();
    await aliceSecondTab.goto(callPath as string);
    await expect(aliceSecondTab.getByTestId("group-call-window")).toBeVisible({
      timeout: 20_000,
    });
    // Inside, not in the antechamber: the tab rehydrated into the seat this
    // person already holds, which is what makes the count below a claim about
    // the room rather than about a page that never joined anything. Verified by
    // breaking it once — with `GroupCall.active_participant/2` stubbed to nil
    // the tab lands in the antechamber here, which is the state one `Join call`
    // away from the second seat this whole shape exists to avoid.
    await expect(aliceSecondTab.getByTestId("group-call-panel")).toBeVisible();
    await expect(aliceSecondTab.getByTestId("group-call-prejoin")).toHaveCount(
      0,
    );

    // Bob is the witness: one Alice, two people in the room. Polled, because
    // the seat moving is a round trip and a duplicate row would appear before
    // it settled rather than after.
    await bob.page.getByTestId("status-bar-group-call").click();
    await expect(bob.page.getByTestId("group-call-window")).toBeVisible();
    await openPeople(bob.page);
    await expect
      .poll(() => participantRows(bob.page, alice.nick).count(), {
        timeout: 15_000,
      })
      .toBe(1);
    await expect(participantRows(bob.page)).toHaveCount(2);
    await shot(bob.page, "surface-second-tab-keeps-one-seat");
  } finally {
    await closeGroupCallUsers([alice, bob]);
  }
});

async function joinConference(page: Page) {
  await page.getByTestId("group-call-open").click();
  await expect(page.getByTestId("group-call-prejoin")).toBeVisible();
  await page.getByTestId("group-call-prejoin-join").click();
  await expect(page.getByTestId("group-call-window")).toBeVisible();
}

async function openPeople(page: Page) {
  await page.getByTestId("group-call-section-people").click();
  await expect(page.getByTestId("group-call-participants")).toBeVisible();
}

function participantRows(page: Page, nickname?: string) {
  const rows = page.locator("[data-group-call-participant]");
  return nickname ? rows.filter({ hasText: nickname }) : rows;
}

/**
 * The status zone's third shape (wave 6 §1.2). Everything the chat draws about
 * a call comes from the embedded surface's assign, so with the call in a tab of
 * its own the chat used to say nothing at all — the one case where "there is a
 * call and you are in it" was invisible on the screen you were looking at.
 */
test("the chat's status bar says the call is in another tab (K8)", async ({
  browser,
}) => {
  test.setTimeout(90_000);
  const alice = await newGroupCallUser(browser, "xtsa");
  const bob = await newGroupCallUser(browser, "xtsb");
  const channel = uniqueChannel("xtabstatus");

  try {
    for (const user of [alice, bob]) {
      await user.chat.sendMessage(`/join ${channel}`);
      await user.chat.expectTabVisible(channel);
      await user.chat.switchToTab(channel);
      await expect(user.page.getByTestId("group-call-open")).toBeEnabled();
    }

    // Bob opens the call; Alice never opens the window, so her chat has no
    // conference assign to draw from — only the read-model and the open set.
    await joinConference(bob.page);
    await expect(bob.page.getByTestId("group-call-window")).toBeVisible();

    await expect(alice.page.getByTestId("status-bar-group-call")).toHaveCount(
      0,
    );

    await alice.page.getByTestId("group-call-channel-popover-toggle").click();
    const tabLink = alice.page.getByTestId("group-call-channel-popover-tab");
    const callPath = await tabLink.getAttribute("href");
    expect(callPath).toMatch(/^\/call\//);

    const callTab = await alice.ctx.newPage();
    await callTab.goto(callPath as string);
    await expect(callTab.getByTestId("group-call-prejoin")).toBeVisible({
      timeout: 20_000,
    });

    // The chat learns from the registry, not from the tab, so the zone appears
    // without Alice touching her chat again.
    const zone = alice.page.getByTestId("status-bar-group-call");
    await expect(zone).toBeVisible({ timeout: 15_000 });
    await expect(zone).toContainText(channel);
    await expect(zone).toContainText("another tab");
    await expect(zone).toHaveAttribute("data-surface-path", callPath as string);

    // A way over, not a control: there is no Leave for a call this window is
    // not holding.
    await expect(
      alice.page.getByTestId("status-bar-group-call-stop"),
    ).toHaveCount(0);
    await shot(alice.page, "surface-status-bar-call-elsewhere");

    // And it goes when the tab does.
    await callTab.close();
    await expect(zone).toHaveCount(0, { timeout: 15_000 });
  } finally {
    await closeGroupCallUsers([alice, bob]);
  }
});
