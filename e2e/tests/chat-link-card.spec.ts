/**
 * @section O - Chat UI Micro-Journeys
 * @flow O25 [done] A pasted link grows the RSS card under the message, live and again after a reload
 * @flow O26 [done] A card landing decorates its message in place, without reordering the conversation
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { Page, test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { e2eURL } from "../helpers/env";
import { shot } from "../helpers/screenshots";

function uniqueChannel(prefix = "card"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: Page, prefix = "card") {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname(prefix);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, nick, password: "pass12345" };
}

test.describe("Link card", () => {
  // The defect this covers: the preview used to be a span the client wrote next
  // to the link, so nothing recreated it when the history was read back. The
  // card has to be there on arrival *and* still be there after a reload — the
  // second half is the part that was never asserted.
  test("appears under the message that carried the link, and survives a reload (O25)", async ({
    page,
  }) => {
    const { chat } = await signedInUser(page);
    const channel = uniqueChannel();
    const url = e2eURL(`/connect?card=${Date.now()}`);

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.sendMessage(`olha isso ${url}`);
    await chat.expectMessageVisible(url);

    const row = chat.messageRowByText(url);
    const card = row.locator(".chat-link-card");

    // Live: the scrape lands after the message, and the row it belongs to is
    // re-streamed rather than left bare until the reader reloads.
    await expect(card).toBeVisible({ timeout: 30_000 });
    await expect(card).toContainText("RetroHexChat");
    await expect(
      card.getByRole("link", { name: /read full story/i }),
    ).toHaveAttribute("href", url);
    await shot(chat.messageList, "link card in the conversation");

    // Reload: nothing of the first session survives except the database, so a
    // card that is still here was rebuilt from the archive.
    await page.reload();

    await chat.waitUntilConnected();
    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);
    await chat.expectMessageVisible(url);

    await expect(
      chat.messageRowByText(url).locator(".chat-link-card"),
    ).toContainText("RetroHexChat", { timeout: 15_000 });
  });

  // A card that arrives seconds after its message must decorate that message
  // where it already is. `stream_insert` on a row the stream already holds
  // updates it in place; if that ever became an append, the conversation would
  // reorder itself under the reader whenever a scrape landed.
  test("does not move the message it decorates (O26)", async ({ page }) => {
    const { chat } = await signedInUser(page, "ord");
    const channel = uniqueChannel("ord");
    const url = e2eURL(`/connect?order=${Date.now()}`);

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.sendMessage(`link aqui ${url}`);
    await chat.sendMessage("depois um");
    await chat.sendMessage("depois dois");
    await chat.expectMessageVisible("depois dois");

    await expect(
      chat.messageRowByText(url).locator(".chat-link-card"),
    ).toBeVisible({ timeout: 30_000 });

    const rows = await chat.messageRows.allInnerTexts();
    expect(rows[0]).toContain(url);
    expect(rows[rows.length - 1]).toContain("depois dois");
  });

  // A message that is plain conversation with no link is not decorated at all.
  test("leaves a message with no link alone (O25)", async ({ page }) => {
    const { chat } = await signedInUser(page, "nocard");
    const channel = uniqueChannel("nocard");

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.sendMessage("uma mensagem sem link nenhum");
    await chat.expectMessageVisible("uma mensagem sem link nenhum");

    await expect(
      chat
        .messageRowByText("uma mensagem sem link nenhum")
        .locator(".chat-link-card"),
    ).toHaveCount(0);
  });
});
