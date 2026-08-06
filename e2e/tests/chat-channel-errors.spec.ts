/**
 * @section H - Channels, Server Messages, Local Window State
 * @flow H1 [done] `/join room` without `#` shows validation error (features P0)
 * @flow H2 [done] Joining over channel limit shows max-channel error without losing tab (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";

function uniqueChannel(prefix = "limit"): string {
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

test.describe("Channel command errors", () => {
  test("/join room without # shows a validation error and keeps the active tab (H1)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const marker = `lobby-marker-${Date.now()}`;

    await chat.switchToTab("#lobby");
    await chat.sendMessage(marker);
    await chat.expectMessageVisible(marker);

    await chat.sendMessage("/join missinghash");

    await chat.expectMessageVisible(
      "Invalid channel name. Channel names must start with #",
    );
    await chat.expectMessageVisible(marker);
    await chat.expectTabHidden("missinghash");
  });

  test("joining more than the allowed channel count shows an error and keeps the active tab (H2)", async ({
    page,
  }) => {
    const chat = await signedInUser(page);
    const overflowChannel = uniqueChannel("overflow");
    const marker = `limit-marker-${Date.now()}`;

    for (let i = 0; i < 9; i += 1) {
      const channel = uniqueChannel(`limit${i}`);
      await chat.sendMessage(`/join ${channel}`);
      await chat.expectTabVisible(channel);
    }

    await chat.switchToTab("#lobby");
    await chat.sendMessage(marker);
    await chat.expectMessageVisible(marker);

    await chat.sendMessage(`/join ${overflowChannel}`);

    await chat.expectMessageVisible("Maximum channel limit reached (10)");
    await chat.expectMessageVisible(marker);
    await chat.expectTabHidden(overflowChannel);
  });
});
