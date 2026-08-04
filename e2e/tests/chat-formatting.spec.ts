import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { e2eURL } from "../helpers/env";
import { shot } from "../helpers/screenshots";

function uniqueChannel(prefix = "fmt"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function signedInUser(page: import("@playwright/test").Page) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  await connect.open();
  await connect.enterNickname(uniqueNickname());
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();
  return chat;
}

test.describe("Formatting toolbar", () => {
  test("Bold button inserts the IRC bold control code at the cursor (F2)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);

    await chat.chatInput.fill("hello");
    await chat.chatInput.press("End");
    await chat.openFormattingToolbar();
    await chat.formatBoldButton.click();

    await expect(chat.chatInput).toHaveValue("hello\x02");
    await expect(chat.chatInput).toBeFocused();
  });

  test("Markdown mode renders rich messages without breaking search, copy source, or URL catcher", async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const channel = uniqueChannel();
    const marker = Date.now();
    const markdownUrl = e2eURL(`/connect?markdown-visual=${marker}`);
    const codeUrl = `https://code.example/${marker}`;
    const markdownSource =
      `visible target **bold** [target link](${markdownUrl}) ` +
      `\`${codeUrl}\``;

    await chat.sendMessage(`/join ${channel}`);
    await chat.expectTabVisible(channel);

    await chat.openFormattingToolbar();
    await page.getByTestId("composer-format-markdown").click();
    await expect(page.getByTestId("composer-format-selector")).toHaveAttribute(
      "data-active-format",
      "markdown",
    );
    await shot(chat.formattingToolbarPanel, "markdown-toolbar-menu");

    await page.getByTestId("composer-markdown-preview-toggle").click();
    await expect(page.getByTestId("composer-markdown-preview")).toHaveCount(0);
    await chat.chatInput.fill(markdownSource);
    await expect(page.getByTestId("composer-markdown-preview")).toBeVisible();
    await shot(
      page.getByTestId("composer-markdown-preview"),
      "markdown-preview",
    );

    await chat.openFormattingToolbar();
    await page.getByTestId("composer-format-plain").click();
    await expect(page.getByTestId("composer-format-selector")).toHaveAttribute(
      "data-active-format",
      "plain",
    );
    await expect(page.getByTestId("composer-markdown-preview")).toHaveCount(0);
    await page.getByTestId("composer-format-markdown").click();
    await page.getByTestId("composer-markdown-preview-toggle").click();
    await expect(page.getByTestId("composer-markdown-preview")).toBeVisible();

    await chat.chatSendButton.click();
    await chat.expectMessageVisible("visible target bold target link");

    const markdownRow = chat.messageRowByText("visible target");
    await expect(markdownRow.locator("strong")).toContainText("bold");
    await expect(markdownRow.locator("a.chat-link")).toContainText(
      "target link",
    );
    await expect(markdownRow.locator("code")).toContainText(codeUrl);
    await shot(chat.messageList, "timeline-markdown-rendered");

    await chat.openSearchFromEditMenu();
    await chat.searchBarInput.fill("target");
    await expect(chat.searchHighlights).toHaveCount(1);
    await shot(chat.messageList, "search-highlight-skips-link-and-code");

    await chat.openMessageContextMenu("visible target");
    await expect(
      page.getByTestId("context-menu-item-ctx_chat_copy_message_source"),
    ).toBeVisible();
    await shot(chat.chatContextMenu, "copy-source-menu");
    await page.keyboard.press("Escape");

    await chat.openUrlCatcherFromMenu();
    await expect(chat.urlCatcherRowByUrl(markdownUrl)).toBeVisible();
    await expect(chat.urlCatcherRows.filter({ hasText: codeUrl })).toHaveCount(
      0,
    );
    await shot(chat.urlCatcherDialog, "url-catcher-markdown-link");
    await chat.urlCatcherDialog
      .locator('[data-window-control="close"]')
      .click();
    await expect(chat.urlCatcherDialog).toBeHidden();

    await chat.openFormattingToolbar();
    await page.getByTestId("composer-format-irc").click();
    await expect(page.getByTestId("composer-format-selector")).toHaveAttribute(
      "data-active-format",
      "irc",
    );
    await page.keyboard.press("Escape");

    await chat.sendMessage("irc visual \x02bold\x02");
    const ircRow = chat.messageRowByText("irc visual bold");
    await expect(ircRow.locator(".irc-bold")).toContainText("bold");
    await shot(chat.messageList, "timeline-irc-still-renders");
  });
});
