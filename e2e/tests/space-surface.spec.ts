/**
 * @section SP - Virtual Spaces
 * @flow SP6 [done] A space is entered from the conversation and runs in a tab of its own
 * @flow SP7 [done] A shared space link resolves to a card and then to the space itself
 * @flow SP8 [done] Two people in the same space see each other
 * @flow SP9 [done] Walking into an empty space writes its card into the conversation
 * @flow SP10 [done] The picker remembers the character this browser chose last
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import {
  newSignedInUser,
  closeUsers,
  uniqueChannel,
  TestUser,
} from "../helpers/chatUsers";
import { enterThroughNewCard } from "../helpers/surfaceEntry";

// A compact hash of the canvas pixels — changes when anything redraws.
function canvasSignature(page: Page): Promise<number> {
  return page
    .locator('[data-testid="channel-space-shell"] canvas')
    .evaluate((el: HTMLCanvasElement) => {
      const ctx = el.getContext("2d");
      if (!ctx || !el.width || !el.height) return 0;
      const { data } = ctx.getImageData(0, 0, el.width, el.height);
      let sum = 0;
      for (let i = 0; i < data.length; i += 97)
        sum = (sum + data[i] * ((i % 251) + 1)) % 1_000_003;
      return sum;
    });
}

// The entry in the conversation's toolbar writes the space's card and goes
// nowhere; the card is the door, and following it opens the tab — exactly as a
// conference and a P2P session are entered.
async function enterSpace(user: TestUser, channel: string): Promise<Page> {
  await user.chat.sendMessage(`/join ${channel}`);

  const space = await enterThroughNewCard(user.page, user.ctx, "space-open");

  await expect(space.getByTestId("space-character-select")).toBeVisible();
  return space;
}

async function walkIn(space: Page, avatar: string) {
  await space.getByTestId(`space-avatar-${avatar}`).click();
  await expect(space.getByTestId("space-loading")).toBeHidden({
    timeout: 15_000,
  });
}

test.describe("A space at an address of its own", () => {
  test("runs without the chat around it", async ({ browser }) => {
    const user = await newSignedInUser(browser, "spa");
    try {
      const channel = uniqueChannel("spa");
      const space = await enterSpace(user, channel);

      // The antechamber is the first thing the address renders, and it is the
      // way back to the chat that opened it.
      await expect(space.getByTestId("space-back-to-chat")).toBeVisible();

      // Nobody has walked in yet, so nobody is inside — the members of the
      // channel are not people standing in a room.
      await expect(space.getByTestId("space-roster")).toContainText(
        "Nobody is in here yet",
      );

      // The page already is the space: the only surface link on it is the way
      // back to the chat, never a tab of its own.
      await expect(space.getByTestId("space-back-to-chat")).toBeVisible();
      await expect(space.locator("[data-surface-path]")).toHaveCount(1);

      // Choosing a character is entering.
      await space.getByTestId("space-avatar-monk").click();
      await expect(
        space.locator(
          '[data-testid="channel-space-shell"][data-avatar="monk"]',
        ),
      ).toBeVisible();

      // The world boots and keeps drawing: the loading panel goes away and the
      // canvas has pixels in it.
      await expect(space.getByTestId("space-loading")).toBeHidden({
        timeout: 15_000,
      });
      await expect.poll(() => canvasSignature(space)).not.toBe(0);

      // Filling the screen is a question the map raises, not the antechamber:
      // a maximized window is still inside browser chrome.
      await expect(space.getByTestId("space-fullscreen-toggle")).toBeVisible();

      // Walking works with nothing but this tab: the frame changes after a step.
      const before = await canvasSignature(space);
      await space.locator('[data-space-pad-dir="right"]').click();
      await expect.poll(() => canvasSignature(space)).not.toBe(before);
    } finally {
      await closeUsers([user]);
    }
  });

  // The card is the record of a gathering rather than a way in — the entry in
  // the toolbar is always a door — but it is what tells the conversation that
  // something is happening, and it is the only half a reader ever sees.
  test("walking into an empty space writes its card into the conversation", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, "spc");
    try {
      const channel = uniqueChannel("spc");
      const space = await enterSpace(user, channel);
      await walkIn(space, "hero");

      const card = user.page.getByTestId("share-message-card").first();
      await expect(card).toBeVisible({ timeout: 15_000 });
      await expect(card).toContainText(user.nick);

      // A second walk-in is the same gathering, so it is still one card.
      const second = await user.ctx.newPage();
      await second.goto(space.url());
      await expect(second.getByTestId("space-character-select")).toBeVisible();
      await second.getByTestId("space-avatar-knight").click();

      await expect(user.page.getByTestId("share-message-card")).toHaveCount(1, {
        timeout: 15_000,
      });
    } finally {
      await closeUsers([user]);
    }
  });

  test("the picker remembers the character this browser chose last", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, "spm");
    try {
      const channel = uniqueChannel("spm");
      const space = await enterSpace(user, channel);
      await space.getByTestId("space-avatar-cleric").click();

      // A new visit to the same address, in the same browser: nothing on the
      // server outlives the first one, so the memory has to be the browser's.
      const again = await user.ctx.newPage();
      await again.goto(space.url());

      await expect(
        again.locator(
          '[data-testid="space-avatar-cleric"][aria-pressed="true"]',
        ),
      ).toBeVisible({ timeout: 15_000 });
    } finally {
      await closeUsers([user]);
    }
  });

  test("a shared link resolves to a card and then to the space", async ({
    browser,
  }) => {
    const user = await newSignedInUser(browser, "spl");
    try {
      const channel = uniqueChannel("spl");
      const space = await enterSpace(user, channel);

      await space.getByTestId("share-create").click();
      const shareUrl = await space.getByTestId("share-url").inputValue();
      expect(shareUrl).toContain("/join/");

      // The public card: it names the space and offers the way in.
      // The minted address carries the public host, so a spec follows its path
      // against the server under test rather than the site it names.
      const visitor = await user.ctx.newPage();
      await visitor.goto(new URL(shareUrl).pathname);
      await expect(visitor.getByTestId("join-card")).toBeVisible();
      await expect(visitor.getByTestId("join-enter")).toBeVisible();

      await visitor.getByTestId("join-enter").click();
      await expect(visitor.getByTestId("space-character-select")).toBeVisible();
      await expect(visitor).toHaveURL(/\/space\//);
    } finally {
      await closeUsers([user]);
    }
  });

  test("two people in the same space see each other", async ({ browser }) => {
    const host = await newSignedInUser(browser, "spx");
    const guest = await newSignedInUser(browser, "spy");
    try {
      const channel = uniqueChannel("spx");
      const hostSpace = await enterSpace(host, channel);
      await walkIn(hostSpace, "knight");

      const guestSpace = await enterSpace(guest, channel);
      await expect(guestSpace.getByTestId("space-roster-names")).toContainText(
        host.nick,
      );
      await walkIn(guestSpace, "sorceress");

      // Each one's arrival redraws the other's world.
      await expect
        .poll(() => canvasSignature(hostSpace), { timeout: 15_000 })
        .not.toBe(0);
      await expect
        .poll(() => canvasSignature(guestSpace), { timeout: 15_000 })
        .not.toBe(0);
    } finally {
      await closeUsers([host, guest]);
    }
  });
});
