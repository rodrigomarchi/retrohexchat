/**
 * @section O - Chat UI Micro-Journeys
 * @flow O20 [done] An uploaded image renders as an inline thumbnail with an authorized download
 * @flow O21 [done] Non-inline uploads render as safe file cards carrying path metadata
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import { test, expect, Page } from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";

const SAMPLE_IMAGE_WIDTH = 160;
const SAMPLE_IMAGE = bitmapFixture(SAMPLE_IMAGE_WIDTH, 90);

function bitmapFixture(width: number, height: number): Buffer {
  const rowSize = Math.ceil((width * 3) / 4) * 4;
  const pixelBytes = rowSize * height;
  const buffer = Buffer.alloc(54 + pixelBytes);

  buffer.write("BM", 0, "ascii");
  buffer.writeUInt32LE(buffer.length, 2);
  buffer.writeUInt32LE(54, 10);
  buffer.writeUInt32LE(40, 14);
  buffer.writeInt32LE(width, 18);
  buffer.writeInt32LE(height, 22);
  buffer.writeUInt16LE(1, 26);
  buffer.writeUInt16LE(24, 28);
  buffer.writeUInt32LE(pixelBytes, 34);

  for (let y = 0; y < height; y += 1) {
    const row = 54 + (height - 1 - y) * rowSize;

    for (let x = 0; x < width; x += 1) {
      const offset = row + x * 3;
      buffer[offset] = x % 2 === 0 ? 220 : 40;
      buffer[offset + 1] = y % 2 === 0 ? 70 : 180;
      buffer[offset + 2] = 30 + x * 25;
    }
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

async function uploadComposerFile(
  page: Page,
  file: { name: string; mimeType: string; buffer: Buffer },
) {
  const fileInput = page.locator('#composer-region input[type="file"]');
  await expect(fileInput).toHaveCount(1);
  const pending = page.getByTestId("chat-attachment-pending");

  await expect(async () => {
    const uploadResponsePromise = page.waitForResponse(
      (response) =>
        response.url().includes("localhost:3900/retrohexchat-uploads/") &&
        response.request().method() === "PUT",
      { timeout: 3_000 },
    );

    await fileInput.setInputFiles([]);
    await fileInput.setInputFiles(file);

    const uploadResponse = await uploadResponsePromise;
    expect(uploadResponse.ok()).toBeTruthy();
    await expect(pending).toContainText(file.name, { timeout: 1_000 });
    await expect(pending).toContainText("100%", { timeout: 1_000 });
  }).toPass({ timeout: 15_000 });
}

test.describe("Chat attachments", () => {
  test("renders an uploaded image as an inline thumbnail with authorized download", async ({
    page,
  }) => {
    const chat = await signIn(page, "img");
    const fileName = `composer-image-${Date.now()}.bmp`;
    const message = `message with attachment ${Date.now()}`;

    await uploadComposerFile(page, {
      name: fileName,
      mimeType: "image/bmp",
      buffer: SAMPLE_IMAGE,
    });

    await chat.chatInput.fill(message);
    await expect(chat.chatSendButton).toBeEnabled();
    await chat.chatSendButton.click();

    await chat.expectMessageVisible(message);

    const row = chat.messageRowByText(message);
    const attachment = row.getByTestId("message-attachment");
    await expect(attachment).toContainText(fileName);
    await expect(attachment).toHaveAttribute("data-preview-kind", "image");

    const image = attachment.getByTestId("message-attachment-image-preview");
    await expect(image).toBeVisible();
    await expect(image).toHaveAttribute(
      "src",
      /\/chat\/attachments\/\d+\/preview$/,
    );
    await expect(image).toHaveJSProperty("naturalWidth", SAMPLE_IMAGE_WIDTH);
    await shot(row, "image-attachment-thumbnail");

    const href = await attachment.getAttribute("href");
    expect(href).toMatch(/^\/chat\/attachments\/\d+$/);

    const download = await page.request.get(href!);
    expect(download.status()).toBe(200);
    expect(Buffer.compare(await download.body(), SAMPLE_IMAGE)).toBe(0);
  });

  test("renders non-inline files as safe file cards with path metadata", async ({
    page,
  }) => {
    const chat = await signIn(page, "att");
    const fileName = `composer-upload-${Date.now()}.txt`;
    const fileBody = `composer upload payload ${Date.now()}`;
    const message = `message with text attachment ${Date.now()}`;

    await uploadComposerFile(page, {
      name: fileName,
      mimeType: "text/plain",
      buffer: Buffer.from(fileBody),
    });

    await chat.chatInput.fill(message);
    await expect(chat.chatSendButton).toBeEnabled();
    await chat.chatSendButton.click();

    await chat.expectMessageVisible(message);

    const row = chat.messageRowByText(message);
    const attachment = row.getByTestId("message-attachment");
    await expect(attachment).toHaveAttribute("data-preview-kind", "text");
    await expect(
      attachment.getByTestId("message-attachment-download"),
    ).toContainText(fileName);
    await expect(
      attachment.getByTestId("message-attachment-path"),
    ).toContainText("/chat/channels");
    await shot(row, "text-attachment-card");

    const href = await attachment
      .getByTestId("message-attachment-download")
      .getAttribute("href");
    expect(href).toMatch(/^\/chat\/attachments\/\d+$/);

    const download = await page.request.get(href!);
    expect(download.status()).toBe(200);
    expect(await download.text()).toBe(fileBody);
  });
});
