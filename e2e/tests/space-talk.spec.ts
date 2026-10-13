/**
 * @section SP - Virtual Spaces
 * @flow SP11 [done] A line typed in a channel's space is said in the channel and pops up over the speaker for everyone in the space
 * @flow SP12 [done] Enter puts the cursor in the space's say line, Esc gives the keyboard back to the map, and typing never walks
 * @flow SP13 [done] A line typed in a private space goes to the other person's private chat
 * @flow SP14 [done] Change character swaps the character inside a running space, for everyone, without leaving it
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
import { buildCharacter, enterAs, Look, recipeOf } from "../helpers/characters";
import { shot } from "../helpers/screenshots";

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

// The loading veil is only there once the map is: waiting for it to be hidden
// before the map exists passes at once, and the next step would close a tab
// that never joined.
async function walkIn(space: Page, avatar: Look | string) {
  await enterAs(space, avatar);
  await expect(space.getByTestId("channel-space-shell")).toBeVisible({
    timeout: 15_000,
  });
  await expect(space.getByTestId("space-loading")).toBeHidden({
    timeout: 15_000,
  });
}

async function say(space: Page, text: string) {
  const line = space.getByTestId("space-say-input");
  await line.click();
  await line.fill(text);
  await line.press("Enter");
  await expect(line).toHaveValue("");
}

test.describe("Talking in a space", () => {
  test("a line said in the space lands in the channel and over the speaker (SP11)", async ({
    browser,
  }) => {
    const host: TestUser = await newSignedInUser(browser, "stk");
    const guest: TestUser = await newSignedInUser(browser, "stg");
    try {
      const channel = uniqueChannel("stk");
      await host.chat.sendMessage(`/join ${channel}`);
      await guest.chat.sendMessage(`/join ${channel}`);

      const hostSpace = await host.chat.openSpace();
      await walkIn(hostSpace, "ranger");
      // The second one in follows the first one's address, as SP9 does: one
      // gathering, one card.
      const guestSpace = await guest.ctx.newPage();
      await guestSpace.goto(hostSpace.url());
      await walkIn(guestSpace, "mage");

      await say(hostSpace, "party at the lamp in five");

      // In the conversation, for somebody who never opened the map.
      await guest.chat.expectMessageVisible("party at the lamp in five");
      // And over the speaker, for everybody standing in the space.
      await expect(guestSpace.getByTestId("space-said")).toHaveText(
        `${host.nick}: party at the lamp in five`,
      );
      await expect(hostSpace.getByTestId("space-said")).toHaveText(
        `${host.nick}: party at the lamp in five`,
      );
      await shot(guestSpace, "bubble-over-the-speaker");

      // A line typed in the chat pops up in the space the same way.
      await guest.chat.sendMessage("on my way");
      await expect(hostSpace.getByTestId("space-said")).toHaveText(
        `${guest.nick}: on my way`,
      );

      // /me is understood; any other command is turned back, kept in the line.
      await say(hostSpace, "/me lights the lamp");
      await guest.chat.expectMessageVisible("lights the lamp");

      const line = hostSpace.getByTestId("space-say-input");
      await line.fill("/part");
      await line.press("Enter");
      await expect(hostSpace.getByTestId("space-say-error")).toContainText(
        "/me",
      );
      await expect(line).toHaveValue("/part");
      await shot(hostSpace, "refused-line-stays-with-reason");

      // A long line wraps into a bubble of a few lines rather than running
      // off the map.
      await say(
        hostSpace,
        "kestrel I made you a playlist and it is four hours long and every song is about knights",
      );
      await shot(guestSpace, "long-line-wraps");
    } finally {
      await closeUsers([host, guest]);
    }
  });

  test("Enter and Esc hand the keyboard between the line and the map (SP12)", async ({
    browser,
  }) => {
    const user: TestUser = await newSignedInUser(browser, "skb");
    try {
      const channel = uniqueChannel("skb");
      await user.chat.sendMessage(`/join ${channel}`);
      const space = await user.chat.openSpace();
      await walkIn(space, "monk");
      await expect.poll(() => canvasSignature(space)).not.toBe(0);

      const line = space.getByTestId("space-say-input");
      await expect(line).not.toBeFocused();

      // Enter, anywhere on the map, puts the cursor in the line.
      await space.keyboard.press("Enter");
      await expect(line).toBeFocused();

      // While the cursor is there, WASD is letters, not steps.
      await space.keyboard.type("wasd");
      await expect(line).toHaveValue("wasd");

      // Esc hands the keyboard back, and the same key walks again.
      await space.keyboard.press("Escape");
      await expect(line).not.toBeFocused();
      const before = await canvasSignature(space);
      await space.keyboard.down("d");
      await space.waitForTimeout(400);
      await space.keyboard.up("d");
      await expect.poll(() => canvasSignature(space)).not.toBe(before);
      await expect(line).toHaveValue("wasd");
    } finally {
      await closeUsers([user]);
    }
  });

  test("a line said in a private space goes to the other person (SP13)", async ({
    browser,
  }) => {
    const alice: TestUser = await newSignedInUser(browser, "spa");
    const bob: TestUser = await newSignedInUser(browser, "spb");
    try {
      await alice.chat.sendMessage(`/msg ${bob.nick} hey`);
      await alice.page.getByTestId(`pm-${bob.nick}`).click();
      await expect(
        alice.page.getByPlaceholder(new RegExp(`Message to ${bob.nick}`)),
      ).toBeVisible();

      const space = await alice.chat.openSpace();
      await walkIn(space, "bard");

      await expect(space.getByTestId("space-say-input")).toHaveAttribute(
        "placeholder",
        new RegExp(bob.nick),
      );
      await say(space, "meet me by the DeLorean");

      await bob.page.getByTestId(`pm-${alice.nick}`).click();
      await bob.chat.expectMessageVisible("meet me by the DeLorean");
      await expect(space.getByTestId("space-said")).toHaveText(
        `${alice.nick}: meet me by the DeLorean`,
      );
    } finally {
      await closeUsers([alice, bob]);
    }
  });

  test("Change character swaps it inside the running space (SP14)", async ({
    browser,
  }) => {
    const host: TestUser = await newSignedInUser(browser, "sch");
    const guest: TestUser = await newSignedInUser(browser, "scg");
    try {
      const channel = uniqueChannel("sch");
      await host.chat.sendMessage(`/join ${channel}`);
      await guest.chat.sendMessage(`/join ${channel}`);

      const space = await host.chat.openSpace();
      await walkIn(space, "wanderer");

      await space.getByTestId("space-change-character").click();
      const creator = space.getByTestId("space-character-creator");
      await expect(creator).toBeVisible();
      await expect(creator).toContainText("Change character");
      // It opens on the character being worn.
      await expect(space.getByTestId("space-creator-preview")).toHaveAttribute(
        "data-recipe",
        recipeOf("wanderer"),
      );
      await shot(space, "change-character-over-the-map");
      // The map keeps running underneath: this is not the door.
      await expect(space.getByTestId("channel-space-shell")).toBeAttached();
      await buildCharacter(space, "sailor");
      await space.getByTestId("space-creator-apply").click();
      await expect(creator).toBeHidden();
      // No reload: the loading veil never comes back.
      await expect(space.getByTestId("space-loading")).toBeHidden();
      await expect(space.getByTestId("channel-space-shell")).toHaveAttribute(
        "data-avatar",
        recipeOf("sailor"),
      );
      await space.waitForTimeout(800);
      await shot(space, "changed-to-sailor");

      // The new character is remembered for the nickname, so the chat draws it.
      await host.chat.sendMessage("new look");
      await expect(
        guest.page
          .locator(`img.rh-portrait[data-avatar="${recipeOf("sailor")}"]`)
          .first(),
      ).toBeVisible({ timeout: 10_000 });

      // And the creator, opened again, starts on it.
      await space.getByTestId("space-change-character").click();
      await expect(space.getByTestId("space-creator-preview")).toHaveAttribute(
        "data-recipe",
        recipeOf("sailor"),
      );
      // Cancelling keeps what is worn, even after trying something else on.
      await space.getByTestId("space-creator-tab-hair").click();
      await space.getByTestId("space-creator-option-hair-0").click();
      await expect(
        space.getByTestId("space-creator-preview"),
      ).not.toHaveAttribute("data-recipe", recipeOf("sailor"));
      await space.getByTestId("space-change-cancel").click();
      await expect(creator).toBeHidden();
      await expect(space.getByTestId("channel-space-shell")).toHaveAttribute(
        "data-avatar",
        recipeOf("sailor"),
      );
    } finally {
      await closeUsers([host, guest]);
    }
  });
});
