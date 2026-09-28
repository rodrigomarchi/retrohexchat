/**
 * @section MB - Mobile & Touch
 * @flow MB11 [done] A voice message is recorded from the phone composer, attached, sent, and plays in the row
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

// A microphone that is always there and always says the same thing: Chromium's
// fake capture device. Recording is the one part of this journey no unit test
// can stand in for — the browser has to hand over a real MediaRecorder blob and
// the presigned upload has to accept it — so the device is faked and everything
// downstream of it is real.
test.use({
  viewport: { width: 375, height: 720 },
  isMobile: true,
  hasTouch: true,
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

test.describe("Voice messages on a phone", () => {
  test("records from the composer, attaches, sends, and plays in the row", async ({
    page,
  }) => {
    const chat = await signIn(page, "voi");
    const message = `heard this one ${Date.now()}`;

    const strip = page.getByTestId("voice-recorder");
    const record = page.getByTestId("voice-record");

    // The strip is rendered hidden and the client shows it only where recording
    // is possible, so "visible" is the assertion that the controller ran and
    // found a microphone.
    await expect(strip).toBeVisible();
    await expect(record).toBeVisible();
    await shot(strip, "voice-strip-idle");

    const uploadResponse = page.waitForResponse(
      (response) =>
        response.url().includes("/retrohexchat-uploads/") &&
        response.request().method() === "PUT",
      { timeout: 15_000 },
    );

    await record.click();

    const elapsed = page.getByTestId("voice-elapsed");
    await expect(elapsed).toBeVisible();
    await expect(elapsed).toHaveText(/0:0[1-9]/, { timeout: 5_000 });
    await shot(strip, "voice-strip-recording");

    await page.getByTestId("voice-stop").click();

    expect((await uploadResponse).ok()).toBeTruthy();

    const pending = page.getByTestId("chat-attachment-pending");
    await expect(pending).toContainText(/voice-\d{8}-\d{6}\./);
    await expect(pending).toContainText("100%");

    // The strip comes back to the microphone: the take is over and the
    // recording is waiting with any other attachment.
    await expect(record).toBeVisible();
    await shot(page, "voice-recording-pending-on-the-phone");

    await chat.chatInput.fill(message);
    await chat.chatSendButton.click();
    await chat.expectMessageVisible(message);

    const row = chat.messageRowByText(message);
    const voice = row.getByTestId("message-voice");
    await expect(voice).toBeVisible();
    await expect(voice).toHaveAttribute("data-preview-kind", "voice");
    await expect(row.getByTestId("message-voice-duration")).toHaveText(
      /0:0[0-9]/,
    );

    const player = voice.getByTestId("message-attachment-audio-preview");
    await expect(player).toHaveAttribute(
      "src",
      /\/chat\/attachments\/\d+\/preview$/,
    );

    // A recording says it is a recording, never the timestamp the browser named
    // the file with.
    await expect(voice).not.toContainText("voice-2");
    await shot(row, "voice-message-row");
  });
});
