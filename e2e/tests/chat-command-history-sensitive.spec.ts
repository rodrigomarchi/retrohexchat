/**
 * @section Q - Catalog, Help, Parser, And Command Surface
 * @flow Q9 [done] Sensitive command names/args cannot be recalled from command history (features P1)
 * @flow Q10 [done] Recent-command autocomplete ranks safe commands without leaking sensitive commands (features P2)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, Page, test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

async function signedInUser(page: Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(uniqueNickname("qhist"));
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();
  return chat;
}

/**
 * Everything the history will hand back, walked one Ctrl+ArrowUp at a time.
 *
 * The history lives on the server now, so there is no browser key to read. What
 * a user can actually reach is what matters anyway: if a sensitive command
 * cannot be recalled into the input, it did not leak, whatever is stored where.
 * The walk stops when the input stops changing — that is the end of history.
 */
async function historyRecall(chat: ChatPage, steps = 12): Promise<string[]> {
  const seen: string[] = [];
  await chat.chatInput.click();

  for (let i = 0; i < steps; i += 1) {
    await chat.chatInput.press("Control+ArrowUp");
    const value = await chat.chatInput.inputValue();
    if (seen.length > 0 && value === seen[seen.length - 1]) break;
    seen.push(value);
  }

  return seen;
}

/**
 * The entries listed under the dropdown's "Recent" heading.
 *
 * The dropdown is one flat list where a bare string is a section heading, so
 * "which section is this item in?" is only answerable by walking it in order.
 * The distinction matters: a sensitive command may legitimately appear under
 * "Commands" — it exists — and still must never be ranked as recently used.
 */
async function recentSectionItems(chat: ChatPage): Promise<string[]> {
  return chat.autocompleteDropdown.evaluate((root) => {
    const names: string[] = [];
    let inRecent = false;

    for (const child of Array.from(root.children)) {
      const isHeading = !child.hasAttribute("phx-click");
      if (isHeading) {
        inRecent = (child.textContent || "").trim().toLowerCase() === "recent";
        continue;
      }
      if (inRecent) {
        const name = child.querySelector("span")?.textContent?.trim();
        if (name) names.push(name);
      }
    }

    return names;
  });
}

test.describe("Sensitive command history and recent command ranking", () => {
  test("sensitive command names and args are omitted from command history (Q9)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const secret = `secret-${Date.now()}`;

    await chat.sendMessage("/help");
    await chat.expectMessageVisible("Available commands:");

    await chat.sendMessage(`/msg NickServ identify ${secret}`);
    await chat.sendMessage(`/perform add /ns identify ${secret}`);
    await chat.sendMessage(`/alias add qauth /ns identify ${secret}`);

    const recalled = await historyRecall(chat);

    // The safe command is reachable — without this the refusals below would
    // hold just as well over an empty history, and prove nothing.
    expect(recalled).toContain("/help");
    expect(recalled.join("\n")).not.toContain(secret);
    expect(recalled.join("\n")).not.toContain("NickServ identify");
    expect(recalled.join("\n")).not.toContain("/perform add /ns identify");
    expect(recalled.join("\n")).not.toContain("/alias add qauth");
  });

  test("recent command autocomplete ranks safe commands and does not leak sensitive commands (Q10)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const secret = `recent-secret-${Date.now()}`;

    await chat.sendMessage("/help");
    await chat.expectMessageVisible("Available commands:");

    await chat.sendMessage("/away ranking-check");
    await chat.expectMessageVisible("You are now away: ranking-check");

    await chat.sendMessage(`/ns identify ${secret}`);
    await chat.expectMessageVisible("[NickServ]");

    await chat.chatInput.click();
    await chat.chatInput.pressSequentially("/a");
    await expect(chat.autocompleteDropdown).toBeVisible();
    await expect(chat.autocompleteDropdown).toContainText("Recent");

    const firstItem = chat.autocompleteDropdown
      .locator('[data-testid^="autocomplete-item-"]')
      .first();
    await expect(firstItem).toContainText("/away");
    await expect(chat.autocompleteDropdown).not.toContainText(secret);

    // Read the Recent section the same way the refusal below reads it, so that
    // refusal cannot pass by the section coming back empty.
    expect(await recentSectionItems(chat)).toContain("/away");

    // The sensitive command was used just as recently, and must not be ranked
    // as recent at all. /ns is still a real command, so it may legitimately
    // appear under "Commands" — only the "Recent" section is the leak.
    await chat.chatInput.fill("");
    await chat.chatInput.pressSequentially("/n");
    await expect(chat.autocompleteDropdown).toBeVisible();
    expect(await recentSectionItems(chat)).not.toContain("/ns");
  });
});
