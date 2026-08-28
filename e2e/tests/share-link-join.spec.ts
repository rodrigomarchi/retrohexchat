/**
 * @section Auth And Lifecycle
 * @flow K4 [done] A shared game link minted in one browser is followed from another with no session: the public card asks for a connect, and the connect lands back on the link
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { expect, test } from "@playwright/test";
import { ChatPage } from "../pages/ChatPage";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";

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
