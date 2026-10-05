/**
 * @section PW - Public Pages, Landing, And Showcase
 * @flow PW20 [done] A channel's public archive is reachable, indexable, and disappears when the founder switches it off (features P1)
 * @flow PW21 [done] The founder switches the archive with /cs archive on|off, and another member of the room sees the notice (features P1)
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

test("a channel opens its archive, and closing it takes the pages down (PW20)", async ({
  page,
  context,
}) => {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname("arc");
  const channel = `#arch${Math.random().toString(36).slice(2, 8)}`;
  const slug = channel.slice(1);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  await chat.sendMessage(`/join ${channel}`);
  await chat.expectTabVisible(channel);
  await chat.sendMessage(`/cs register ${channel}`);

  // Nothing is published until the founder says so, and a reader gets a 404
  // rather than anything that confirms the channel exists.
  const reader = await context.newPage();
  const closed = await reader.goto(`/archive/${slug}`);
  expect(closed?.status()).toBe(404);

  await chat.sendMessage("said before the switch, and never published");

  await chat.openChannelCentralFromMenu();
  await chat.switchChannelCentralToTab("registration");

  await page.getByTestId("cc-archive-toggle").click();
  await expect(page.getByTestId("cc-archive-toggle")).toBeChecked();
  await shot(page, "archive-switch-on");

  await chat.sendMessage("said after the switch, and published");

  const open = await reader.goto(`/archive/${slug}`);
  expect(open?.status()).toBe(200);
  await expect(reader.getByTestId("archive-days")).toBeVisible();
  await shot(reader, "archive-index");

  await reader.getByTestId("archive-days").getByRole("link").first().click();
  await expect(reader.getByTestId("archive-lines")).toContainText(
    "said after the switch, and published",
  );
  // The ethical half, seen from outside.
  await expect(reader.getByTestId("archive-lines")).not.toContainText(
    "said before the switch",
  );
  await shot(reader, "archive-day");

  // Switching it off takes the pages down.
  await page.getByTestId("cc-archive-toggle").click();
  await expect(page.getByTestId("cc-archive-toggle")).not.toBeChecked();

  const gone = await reader.goto(`/archive/${slug}`);
  expect(gone?.status()).toBe(404);
});

test("the founder switches the archive from the command line, and the room is told (PW21)", async ({
  page,
  browser,
}) => {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);
  const nick = uniqueNickname("arcmd");
  const channel = `#arcmd${Math.random().toString(36).slice(2, 8)}`;
  const slug = channel.slice(1);

  await connect.open();
  await connect.enterNickname(nick);
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  await chat.sendMessage(`/join ${channel}`);
  await chat.expectTabVisible(channel);
  await chat.sendMessage(`/cs register ${channel}`);

  // Somebody else in the room: the notice is for them, not for the founder.
  const otherContext = await browser.newContext();
  try {
    const otherPage = await otherContext.newPage();
    const otherConnect = new ConnectPage(otherPage);
    const otherChat = new ChatPage(otherPage);
    await otherConnect.open();
    await otherConnect.enterNickname(uniqueNickname("arcrd"));
    await otherConnect.registerWithPassword("pass12345");
    await otherChat.waitUntilConnected();
    await otherChat.sendMessage(`/join ${channel}`);
    await otherChat.expectTabVisible(channel);

    await chat.sendMessage("/cs archive on");
    await expect(
      page.getByText(`The public archive of ${channel} is on`).first(),
    ).toBeVisible();
    await expect(
      otherPage
        .getByText(`${nick} opened this channel's public archive`)
        .first(),
    ).toBeVisible();

    await chat.sendMessage("published because the command said so");

    const reader = await otherContext.newPage();
    const day = new Date().toISOString().slice(0, 10);
    const open = await reader.goto(`/archive/${slug}/${day}`);
    expect(open?.status()).toBe(200);
    await expect(reader.getByTestId("archive-lines")).toContainText(
      "published because the command said so",
    );
    // One short day is one page: no pager to walk.
    await expect(reader.getByTestId("archive-pager")).toHaveCount(0);
    await shot(reader, "archive-day-from-command");

    await chat.sendMessage("/cs archive off");
    await expect(
      page.getByText(`The public archive of ${channel} is off`).first(),
    ).toBeVisible();
    await expect(
      otherPage
        .getByText(`${nick} closed this channel's public archive`)
        .first(),
    ).toBeVisible();

    const gone = await reader.goto(`/archive/${slug}/${day}`);
    expect(gone?.status()).toBe(404);
  } finally {
    await otherContext.close();
  }
});
