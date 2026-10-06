/**
 * @section O - Chat UI Micro-Journeys
 * @flow O32 [done] On a desktop the composer toolbar offers the microphone; a discarded take sends nothing, a finished one is sent alone — even with a file attached mid-take, which stays pending — and a file attached alone sends without text
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

// Chromium's fake capture device stands in for the microphone; everything
// downstream of it — MediaRecorder, the presigned upload, the message — is real.
test.use({
  permissions: ["microphone"],
  launchOptions: {
    args: [
      "--use-fake-device-for-media-stream",
      "--use-fake-ui-for-media-stream",
      "--autoplay-policy=no-user-gesture-required",
    ],
  },
});

async function signIn(page: Page, prefix: string) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname(prefix));
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return chat;
}

// The attachment button is a label for its upload's input; the recording
// upload has an input of its own beside it.
async function attachFile(page: Page, name: string) {
  const input = await page
    .getByTestId("chat-attachment-button")
    .getAttribute("for");

  await page.locator(`[id="${input}"]`).setInputFiles({
    name,
    mimeType: "text/plain",
    buffer: Buffer.from("just the file"),
  });
}

test.describe("Voice messages on a desktop", () => {
  test("discarding sends nothing; sending sends the recording alone", async ({
    page,
  }) => {
    const chat = await signIn(page, "vod");
    const toolbar = page.getByTestId("chat-input-toolbar");
    const record = toolbar.getByTestId("voice-record");
    const voices = page.getByTestId("message-voice");

    await expect(record).toBeVisible();
    // The conversation is shared with every other spec, so what this one sends
    // is counted from what was already there.
    const before = await voices.count();
    await shot(page.getByTestId("chat-input-form"), "voice-desktop-idle");

    // Escape throws the take away and gives the keyboard back to the microphone.
    await record.click();
    await expect(page.getByTestId("voice-elapsed")).toHaveText(/0:0[1-9]/, {
      timeout: 5_000,
    });
    await expect(chat.chatInput).toBeHidden();
    await shot(page.getByTestId("chat-input-form"), "voice-desktop-recording");
    await page.keyboard.press("Escape");

    await expect(record).toBeVisible();
    await expect(record).toBeFocused();
    await expect(chat.chatInput).toBeVisible();
    await expect(page.getByTestId("chat-voice-pending")).toHaveCount(0);
    await expect(voices).toHaveCount(before);

    await record.click();
    await expect(page.getByTestId("voice-elapsed")).toHaveText(/0:0[1-9]/, {
      timeout: 5_000,
    });
    // A file chosen mid-take re-renders the composer from the server; the
    // take must still stand where the input was, and the file must wait.
    await attachFile(page, "beside-the-take.txt");
    const pending = page.getByTestId("chat-attachment-pending");
    await expect(pending).toContainText("100%", { timeout: 15_000 });
    await expect(page.getByTestId("voice-elapsed")).toBeVisible();
    await expect(chat.chatInput).toBeHidden();
    await expect(chat.chatSendButton).toBeHidden();

    await page.getByTestId("voice-stop").click();

    await expect(voices).toHaveCount(before + 1, { timeout: 15_000 });
    await expect(voices.last()).toHaveAttribute("data-preview-kind", "voice");
    await expect(chat.chatInput).toHaveValue("");
    await expect(pending).toContainText("beside-the-take.txt");
    await shot(page, "voice-desktop-sent");
  });

  // The Send button follows the server's word that a pending attachment is a
  // message on its own, with nothing typed beside it.
  test("a file attached with nothing typed can be sent", async ({ page }) => {
    const chat = await signIn(page, "vof");

    await attachFile(page, "notes.txt");

    const pending = page.getByTestId("chat-attachment-pending");
    await expect(pending).toContainText("100%", { timeout: 15_000 });
    await expect(chat.chatInput).toHaveValue("");
    await expect(chat.chatSendButton).toBeEnabled();

    await chat.chatSendButton.click();

    await expect(pending).toHaveCount(0);
    await expect(
      chat.messageRows.filter({ hasText: "notes.txt" }).last(),
    ).toBeVisible({ timeout: 15_000 });
  });
});
