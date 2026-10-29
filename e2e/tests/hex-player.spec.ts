/**
 * @section O - Chat UI Micro-Journeys
 * @flow O35 [done] A sound attached to a message plays in the Hex player: Play, Pause where it was, the position slider, Stop back at the start — never the browser's own controls
 * @flow O36 [done] A video attached to a message plays on the Hex player's screen, with a key to fill the screen, and comes back to the start when it ends
 * @flow O37 [done] Only one thing plays at a time: starting a second sound pauses the first
 * @flow O39 [done] A voice message recorded in the browser — a file with no length of its own — plays and moves through the length the server measured
 * @flow O38 [done] On a phone the Hex player fits the conversation's width with every key reachable
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test, expect, Page, Locator } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

// The recording test needs Chromium's fake microphone, and launch options
// can only be set for the whole file.
test.use({
  launchOptions: {
    args: [
      "--use-fake-device-for-media-stream",
      "--use-fake-ui-for-media-stream",
      "--autoplay-policy=no-user-gesture-required",
    ],
  },
});

// Three seconds of a test pattern with a tone, VP8 + Opus (ffmpeg testsrc).
const CLIP = readFileSync(
  join(__dirname, "..", "fixtures", "hex-player-clip.webm"),
);

// `seconds` of a 440 Hz tone, as a 16-bit mono WAV.
function tone(seconds: number): Buffer {
  const rate = 8_000;
  const samples = rate * seconds;
  const buffer = Buffer.alloc(44 + samples * 2);
  buffer.write("RIFF", 0);
  buffer.writeUInt32LE(36 + samples * 2, 4);
  buffer.write("WAVEfmt ", 8);
  buffer.writeUInt32LE(16, 16);
  buffer.writeUInt16LE(1, 20);
  buffer.writeUInt16LE(1, 22);
  buffer.writeUInt32LE(rate, 24);
  buffer.writeUInt32LE(rate * 2, 28);
  buffer.writeUInt16LE(2, 32);
  buffer.writeUInt16LE(16, 34);
  buffer.write("data", 36);
  buffer.writeUInt32LE(samples * 2, 40);
  for (let i = 0; i < samples; i++) {
    const value = Math.round(Math.sin((2 * Math.PI * 440 * i) / rate) * 12_000);
    buffer.writeInt16LE(value, 44 + i * 2);
  }
  return buffer;
}

async function signIn(page: Page, prefix: string) {
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname(prefix));
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return chat;
}

// Sends `file` with `message` beside it, and returns the player in its line.
async function sendFile(
  page: Page,
  chat: ChatPage,
  file: { name: string; mimeType: string; buffer: Buffer },
  message: string,
): Promise<Locator> {
  const fileInput = page.locator(
    '#composer-region input[type="file"][name="attachments"]',
  );
  const pending = page.getByTestId("chat-attachment-pending");

  await expect(async () => {
    await fileInput.setInputFiles([]);
    await fileInput.setInputFiles(file);
    await expect(pending).toContainText("100%", { timeout: 3_000 });
  }).toPass({ timeout: 15_000 });

  await chat.chatInput.fill(message);
  await chat.chatSendButton.click();
  await chat.expectMessageVisible(message);

  const player = chat.messageRowByText(message).getByTestId("hex-player");
  await expect(player).toBeVisible();
  return player;
}

const elapsed = (player: Locator) =>
  player.locator("[data-player-field='elapsed']");

test.describe("Hex player", () => {
  test("plays, pauses, seeks and stops a sound", async ({ page }) => {
    const chat = await signIn(page, "hps");
    const player = await sendFile(
      page,
      chat,
      { name: "tone.wav", mimeType: "audio/wav", buffer: tone(4) },
      `a tone ${Date.now()}`,
    );

    // The device, not the browser's controls.
    await expect(player.locator("audio")).not.toHaveAttribute("controls", /.*/);
    await expect(player).toHaveAttribute("data-player-state", "stopped");
    await expect(player.locator("[data-player-field='length']")).toHaveText(
      "0:04",
    );
    await shot(player, "hex-player-sound-stopped");

    await player.getByTestId("hex-player-play").click();
    await expect(player).toHaveAttribute("data-player-state", "playing");
    await expect(player.getByTestId("hex-player-pause")).toBeVisible();
    await expect(player.getByTestId("hex-player-play")).toBeHidden();
    await expect(elapsed(player)).toHaveText("0:01", { timeout: 5_000 });
    await shot(player, "hex-player-sound-playing");

    await player.getByTestId("hex-player-pause").click();
    await expect(player).toHaveAttribute("data-player-state", "paused");
    await expect(elapsed(player)).not.toHaveText("0:00");
    await shot(player, "hex-player-sound-paused");

    await player.getByTestId("hex-player-seek").fill("750");
    await expect(elapsed(player)).toHaveText("0:03");

    await player.getByTestId("hex-player-mute").click();
    await expect(player.getByTestId("hex-player-mute")).toHaveAttribute(
      "aria-pressed",
      "true",
    );

    await player.getByTestId("hex-player-stop").click();
    await expect(player).toHaveAttribute("data-player-state", "stopped");
    await expect(elapsed(player)).toHaveText("0:00");
  });

  test("plays a video on its screen until it ends", async ({ page }) => {
    const chat = await signIn(page, "hpv");
    const player = await sendFile(
      page,
      chat,
      { name: "clip.webm", mimeType: "video/webm", buffer: CLIP },
      `a clip ${Date.now()}`,
    );

    // Recorded voices arrive as audio/webm; this one is a video and gets a screen.
    await expect(player.locator("video")).toHaveCount(1);
    await expect(player.getByTestId("hex-player-fullscreen")).toBeVisible();
    await expect(player.locator("[data-player-field='length']")).toHaveText(
      "0:03",
      { timeout: 5_000 },
    );
    await shot(player, "hex-player-video-stopped");

    await player.getByTestId("hex-player-play").click();
    await expect(player).toHaveAttribute("data-player-state", "playing");
    await expect(elapsed(player)).toHaveText("0:01", { timeout: 5_000 });
    await shot(player, "hex-player-video-playing");

    // It ends by itself and comes back to the start.
    await expect(player).toHaveAttribute("data-player-state", "stopped", {
      timeout: 10_000,
    });
    await expect(elapsed(player)).toHaveText("0:00");
  });

  test("starting a second sound pauses the first", async ({ page }) => {
    const chat = await signIn(page, "hpx");
    const first = await sendFile(
      page,
      chat,
      { name: "first.wav", mimeType: "audio/wav", buffer: tone(6) },
      `the first ${Date.now()}`,
    );
    const second = await sendFile(
      page,
      chat,
      { name: "second.wav", mimeType: "audio/wav", buffer: tone(6) },
      `the second ${Date.now()}`,
    );

    await first.getByTestId("hex-player-play").click();
    await expect(first).toHaveAttribute("data-player-state", "playing");
    await expect(elapsed(first)).toHaveText("0:01", { timeout: 5_000 });

    await second.getByTestId("hex-player-play").click();
    await expect(second).toHaveAttribute("data-player-state", "playing");
    await expect(first).toHaveAttribute("data-player-state", "paused");
  });
});

test.describe("Hex player on a phone", () => {
  test.use({
    viewport: { width: 375, height: 720 },
    isMobile: true,
    hasTouch: true,
  });

  test("fits the conversation with every key reachable", async ({ page }) => {
    const chat = await signIn(page, "hpp");
    const player = await sendFile(
      page,
      chat,
      { name: "clip.webm", mimeType: "video/webm", buffer: CLIP },
      `a phone clip ${Date.now()}`,
    );

    const box = await player.boundingBox();
    expect(box).not.toBeNull();
    expect(box!.x).toBeGreaterThanOrEqual(0);
    expect(box!.x + box!.width).toBeLessThanOrEqual(375);
    for (const key of [
      "hex-player-play",
      "hex-player-stop",
      "hex-player-mute",
      "hex-player-fullscreen",
    ]) {
      await expect(player.getByTestId(key)).toBeInViewport();
    }
    await shot(page, "hex-player-phone");

    await player.getByTestId("hex-player-play").tap();
    await expect(player).toHaveAttribute("data-player-state", "playing");
  });
});

test.describe("Hex player with a recorded voice message", () => {
  // A real MediaRecorder file, which carries no length of its own.
  test.use({ permissions: ["microphone"] });

  test("plays it and moves through it by the length the server measured", async ({
    page,
  }) => {
    await signIn(page, "hpr");
    const voices = page.getByTestId("message-voice");
    const before = await voices.count();

    await page
      .getByTestId("chat-input-toolbar")
      .getByTestId("voice-record")
      .click();
    await expect(page.getByTestId("voice-elapsed")).toHaveText(/0:0[3-9]/, {
      timeout: 8_000,
    });
    await page.getByTestId("voice-stop").click();
    await expect(voices).toHaveCount(before + 1, { timeout: 15_000 });

    const player = voices.last().getByTestId("hex-player");
    const length = player.getByTestId("message-voice-duration");
    await expect(length).toHaveText(/0:0[3-9]/);
    await shot(player, "hex-player-voice-stopped");

    await player.getByTestId("hex-player-play").click();
    await expect(player).toHaveAttribute("data-player-state", "playing");
    await player.getByTestId("hex-player-pause").click();
    await expect(player).toHaveAttribute("data-player-state", "paused");

    await player.getByTestId("hex-player-seek").fill("900");
    await expect(elapsed(player)).not.toHaveText("0:00");
    await expect(player.getByTestId("hex-player-seek")).toHaveValue("900");
    await shot(player, "hex-player-voice-moved");

    await player.getByTestId("hex-player-play").click();
    await expect(player).toHaveAttribute("data-player-state", "playing");
  });
});
