/**
 * @section MB - Mobile & Touch
 * @flow MB11 [done] A voice message is recorded from the microphone in the phone composer's single toolbar row and sent on its own, keeping the typed draft
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
  test("records from the toolbar and sends the recording on its own", async ({
    page,
  }) => {
    const chat = await signIn(page, "voi");
    const draft = `still typing ${Date.now()}`;

    const form = page.getByTestId("chat-input-form");
    const record = page.getByTestId("voice-record");

    // The microphone is a toolbar button in the input's own row: the composer
    // is one line on a phone, not a second strip under it.
    await expect(record).toBeVisible();
    const formBox = await form.boundingBox();
    const recordBox = await record.boundingBox();
    const inputBox = await chat.chatInput.boundingBox();
    expect(recordBox!.y).toBeGreaterThanOrEqual(formBox!.y);
    expect(recordBox!.y + recordBox!.height).toBeLessThanOrEqual(
      formBox!.y + formBox!.height,
    );
    expect(Math.abs(recordBox!.y - inputBox!.y)).toBeLessThan(inputBox!.height);
    await shot(form, "voice-phone-idle");

    await chat.chatInput.fill(draft);

    const uploadResponse = page.waitForResponse(
      (response) =>
        response.url().includes("/retrohexchat-uploads/") &&
        response.request().method() === "PUT",
      { timeout: 15_000 },
    );

    await record.click();

    // While the take runs it stands where the input was.
    const elapsed = page.getByTestId("voice-elapsed");
    await expect(elapsed).toBeVisible();
    await expect(chat.chatInput).toBeHidden();
    await expect(chat.chatSendButton).toBeHidden();
    await expect(elapsed).toHaveText(/0:0[1-9]/, { timeout: 5_000 });
    await shot(form, "voice-phone-recording");

    await page.getByTestId("voice-stop").click();

    expect((await uploadResponse).ok()).toBeTruthy();

    // Nothing waits to be attached: the recording became a message by itself.
    const voice = page.getByTestId("message-voice").last();
    await expect(voice).toBeVisible({ timeout: 15_000 });
    await expect(voice).toHaveAttribute("data-preview-kind", "voice");
    await expect(page.getByTestId("chat-attachment-pending")).toHaveCount(0);
    await expect(page.getByTestId("chat-voice-pending")).toHaveCount(0);

    // The draft is still in the input, and it was not sent with the recording.
    await expect(record).toBeVisible();
    await expect(chat.chatInput).toBeVisible();
    await expect(chat.chatInput).toHaveValue(draft);
    await expect(chat.messageRows.filter({ hasText: draft })).toHaveCount(0);

    const row = chat.messageRows.filter({ has: voice }).last();
    await expect(row.getByTestId("message-voice-duration")).toHaveText(
      /0:0[0-9]/,
    );
    await expect(
      voice.getByTestId("message-attachment-audio-preview"),
    ).toHaveAttribute("src", /\/chat\/attachments\/\d+\/preview$/);

    // A recording says it is a recording, never the timestamp the browser named
    // the file with.
    await expect(voice).not.toContainText("voice-2");
    await shot(page, "voice-phone-sent");
  });
});
