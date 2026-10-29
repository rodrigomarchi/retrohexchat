/**
 * @section O - Chat UI Micro-Journeys
 * @flow O34 [done] One conversation holding every kind of line — runs of one speaker, a mention, /me, a reply, emoji alone, photos, a reaction, an edit and a delete — read on a desktop and on a phone
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import {
  Browser,
  BrowserContext,
  devices,
  expect,
  Page,
  test,
} from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { e2eBaseURL } from "../helpers/env";
import { shot } from "../helpers/screenshots";

const DESKTOP = { viewport: { width: 1280, height: 720 } };
const PIXEL_5 = devices["Pixel 5"];
const PHONE = {
  viewport: PIXEL_5.viewport,
  userAgent: PIXEL_5.userAgent,
  deviceScaleFactor: PIXEL_5.deviceScaleFactor,
  isMobile: PIXEL_5.isMobile,
  hasTouch: PIXEL_5.hasTouch,
};

type TestUser = { chat: ChatPage; ctx: BrowserContext; nick: string };

async function newUser(
  browser: Browser,
  prefix: string,
  profile: typeof DESKTOP | typeof PHONE,
): Promise<TestUser> {
  const ctx = await browser.newContext({ ...profile, baseURL: e2eBaseURL() });
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, ctx, nick };
}

async function join(user: TestUser, channel: string) {
  await user.chat.sendMessage(`/join ${channel}`);
  await user.chat.expectTabVisible(channel);
  await user.chat.switchToTab(channel);
}

function bitmap(width: number, height: number, tint: number): Buffer {
  const rowSize = Math.ceil((width * 3) / 4) * 4;
  const buffer = Buffer.alloc(54 + rowSize * height);

  buffer.write("BM", 0, "ascii");
  buffer.writeUInt32LE(buffer.length, 2);
  buffer.writeUInt32LE(54, 10);
  buffer.writeUInt32LE(40, 14);
  buffer.writeInt32LE(width, 18);
  buffer.writeInt32LE(height, 22);
  buffer.writeUInt16LE(1, 26);
  buffer.writeUInt16LE(24, 28);
  buffer.writeUInt32LE(rowSize * height, 34);

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const offset = 54 + y * rowSize + x * 3;
      buffer[offset] = (x * 3 + tint) % 255;
      buffer[offset + 1] = (y * 4 + tint) % 255;
      buffer[offset + 2] = 120 + ((x + y) % 2) * 80;
    }
  }

  return buffer;
}

async function sendPhoto(
  page: Page,
  chat: ChatPage,
  name: string,
  text: string,
  tint: number,
) {
  const input = page.locator(
    '#composer-region input[type="file"][name="attachments"]',
  );
  const pending = page.getByTestId("chat-attachment-pending");

  await expect(async () => {
    const uploaded = page.waitForResponse(
      (response) =>
        response.url().includes("/retrohexchat-uploads/") &&
        response.request().method() === "PUT",
      { timeout: 3_000 },
    );
    await input.setInputFiles([]);
    await input.setInputFiles({
      name,
      mimeType: "image/bmp",
      buffer: bitmap(160, 120, tint),
    });
    expect((await uploaded).ok()).toBeTruthy();
    await expect(pending).toContainText("100%", { timeout: 1_000 });
  }).toPass({ timeout: 15_000 });

  await chat.chatInput.fill(text);
  await chat.chatSendButton.click();
  await chat.expectMessageVisible(text);
}

const LAUGH = "\u{1F602}";

test.describe("Message layout", () => {
  test("every kind of line, read on a desktop and on a phone (O34)", async ({
    browser,
  }) => {
    test.setTimeout(120_000);
    const channel = `#layout${Math.random().toString(36).slice(2, 8)}`;
    const marker = Date.now().toString(36);
    const ana = await newUser(browser, "ana", DESKTOP);
    const bob = await newUser(browser, "bob", DESKTOP);
    const cid = await newUser(browser, "cid", PHONE);

    try {
      await join(ana, channel);
      await join(bob, channel);
      await join(cid, channel);
      await bob.chat.expectNickInList(cid.nick);

      // A run of one speaker.
      const first = `first line from bob ${marker}`;
      const second = `and a second one right after ${marker}`;
      await bob.chat.sendMessage(first);
      await bob.chat.sendMessage(second);

      // Somebody else, naming the reader.
      const mention = `${bob.nick}: are you the owner here? ${marker}`;
      await ana.chat.expectMessageVisible(second);
      await ana.chat.sendMessage(mention);
      await ana.chat.sendMessage(`/me waves at everyone ${marker}`);

      // A reply.
      await bob.chat.expectMessageVisible(mention);
      await bob.chat.openMessageContextMenu(mention);
      await bob.chat.contextReplyMenuItem.click();
      const reply = `yes, what do you need? ${marker}`;
      await bob.chat.sendMessage(reply);

      // Emoji alone, then two photos in a row.
      await ana.chat.expectMessageVisible(reply);
      await ana.chat.sendMessage("\u{1F643}");
      const photoA = `night city ${marker}`;
      const photoB = `and another ${marker}`;
      await sendPhoto(
        ana.chat.page,
        ana.chat,
        `city-${marker}.bmp`,
        photoA,
        10,
      );
      await sendPhoto(
        ana.chat.page,
        ana.chat,
        `more-${marker}.bmp`,
        photoB,
        90,
      );

      // A reaction, an edit and a delete.
      await bob.chat.expectMessageVisible(photoB);
      await bob.chat.reactTo(photoA, LAUGH);
      await expect(bob.chat.messageReaction(photoA, LAUGH)).toBeVisible();

      const toEdit = `this line has a typo ${marker}`;
      const edited = `this line was fixed ${marker}`;
      await bob.chat.sendMessage(toEdit);
      await bob.chat.expectMessageVisible(toEdit);
      await bob.chat.chatInput.press("ArrowUp");
      await expect(bob.chat.chatInput).toHaveValue(toEdit);
      await bob.chat.chatInput.fill(edited);
      await bob.chat.chatInput.press("Enter");
      await expect(
        bob.chat.messageRowByText(edited).getByTestId("edited-tag"),
      ).toBeVisible();

      const toDelete = `this line goes away ${marker}`;
      await bob.chat.sendMessage(toDelete);
      await bob.chat.expectMessageVisible(toDelete);
      await bob.chat.openMessageContextMenu(toDelete);
      await bob.chat.contextDeleteMenuItem.click();
      await bob.chat.deleteConfirmButton.click();
      await expect(
        bob.chat.messageList.getByTestId("deleted-message"),
      ).toBeVisible();

      const last = `that is all for now ${marker}`;
      await bob.chat.sendMessage(last);
      await cid.chat.expectMessageVisible(last);
      await ana.chat.expectMessageVisible(last);

      // Printed on continuous paper: a run shares one header and one band,
      // the reader's own runs are marked, and the day opens the page.
      const rowOf = (text: string) =>
        bob.chat.messageRowByText(text).locator(".chat-message__row").first();
      await expect(rowOf(first)).not.toHaveAttribute("data-continuation");
      await expect(rowOf(second)).toHaveAttribute("data-continuation", "true");
      await expect(rowOf(second)).toHaveAttribute(
        "data-band",
        (await rowOf(first).getAttribute("data-band"))!,
      );
      await expect(rowOf(mention)).not.toHaveAttribute(
        "data-band",
        (await rowOf(first).getAttribute("data-band"))!,
      );
      await expect(bob.chat.messageRowByText(first)).toHaveAttribute(
        "data-own",
        "true",
      );
      await expect(
        bob.chat.messageList.getByTestId("day-break").first(),
      ).toBeVisible();
      await expect(
        bob.chat.messageList.locator('[data-message-kind="user"]'),
      ).toHaveCount(0);

      // The reader's desktop, then the phone of somebody who only watched.
      await bob.chat.page.mouse.move(0, 0);
      await shot(bob.chat.page, "desktop-window");
      await shot(bob.chat.messageList, "desktop-conversation");

      await cid.chat.scrollMessagesToBottom();
      await shot(cid.chat.page, "phone-bottom");
      await cid.chat.messageRowByText(first).scrollIntoViewIfNeeded();
      await shot(cid.chat.page, "phone-top");
    } finally {
      await Promise.all([ana.ctx.close(), bob.ctx.close(), cid.ctx.close()]);
    }
  });

  // Live rooms are all one day; three days of paper, perforations between
  // them, come from the component catalogue.
  for (const [name, profile] of [
    ["desktop", DESKTOP],
    ["phone", PHONE],
  ] as const) {
    test(`three days of paper on a ${name} (O34)`, async ({ browser }) => {
      const ctx = await browser.newContext({
        ...profile,
        baseURL: e2eBaseURL(),
      });
      const page = await ctx.newPage();

      try {
        await page.goto("/showcase/chat-message");
        // A phone opens the catalogue's navigator over the page.
        const navigator = page.getByTestId("showcase-navigator-window");
        if (name === "phone") {
          await navigator.locator('[data-window-control="close"]').click();
          await expect(navigator).toBeHidden();
        }
        const paper = page.getByTestId("showcase-paper");
        await expect(paper.getByTestId("day-break")).toHaveCount(3);
        await paper.scrollIntoViewIfNeeded();
        await shot(paper, `${name}-three-days`);
      } finally {
        await ctx.close();
      }
    });
  }
});
