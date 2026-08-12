/**
 * @section O - Chat UI Micro-Journeys
 * @flow O23 [done] A BBC RSS item renders as a rich Markdown message in the desktop timeline
 * @flow O24 [done] The BBC RSS Markdown preview stays contained at phone width
 *
 * These @flow lines are the source of truth for e2e/TEST_CATALOG.md.
 * Edit them here, then run `make e2e.catalog` to regenerate the index.
 */
import {
  Browser,
  BrowserContext,
  Locator,
  Page,
  test,
  expect,
} from "@playwright/test";
import { ConnectPage, uniqueNickname } from "../pages/ConnectPage";
import { ChatPage } from "../pages/ChatPage";
import { shot } from "../helpers/screenshots";
import { isLocalTarget, localOnlyReason } from "../helpers/env";

type TestUser = {
  chat: ChatPage;
  ctx: BrowserContext;
  page: Page;
};

type ViewportConfig = {
  width: number;
  height: number;
  isMobile?: boolean;
  hasTouch?: boolean;
};

const DESKTOP: ViewportConfig = { width: 1280, height: 720 };
const PHONE: ViewportConfig = {
  width: 375,
  height: 720,
  isMobile: true,
  hasTouch: true,
};

const BBC_RSS_PREVIEW = {
  headline:
    "Video shows Russian drone chasing Ukrainian street vendor in 'human safari' attack",
  articleUrl: "https://www.bbc.co.uk/news/articles/cn4n03xg981o",
  imageUrl:
    "https://ichef.bbci.co.uk/ace/branded_news/1200/cpsprodpb/8528/live/11898c20-9026-11f1-b2ab-0dd01740f9f6.jpg",
  imageAlt: "BBC News preview image",
  description:
    "Ukraine said the video - showing a terrified civilian being hounded by a remotely-controlled drone - amounted to a war crime.",
  markdown: [
    "**BBC News** | Video shows Russian drone chasing Ukrainian street vendor in 'human safari' attack",
    "",
    "![BBC News preview image](<https://ichef.bbci.co.uk/ace/branded_news/1200/cpsprodpb/8528/live/11898c20-9026-11f1-b2ab-0dd01740f9f6.jpg>)",
    "",
    "> Ukraine said the video \\- showing a terrified civilian being hounded by a remotely\\-controlled drone \\- amounted to a war crime\\.",
    "",
    "[Read full story](<https://www.bbc.co.uk/news/articles/cn4n03xg981o>)",
  ].join("\n"),
};

function uniqueChannel(prefix = "rssvis"): string {
  return `#${prefix}${Math.random().toString(36).slice(2, 9)}`;
}

async function newSignedInUser(
  browser: Browser,
  viewport: ViewportConfig,
): Promise<TestUser> {
  const ctx = await browser.newContext({
    viewport: { width: viewport.width, height: viewport.height },
    isMobile: viewport.isMobile ?? false,
    hasTouch: viewport.hasTouch ?? false,
  });
  const page = await ctx.newPage();
  const connect = new ConnectPage(page);
  const chat = new ChatPage(page);

  await connect.open();
  await connect.enterNickname(uniqueNickname("rssvis"));
  await connect.registerWithPassword("pass12345");
  await chat.waitUntilConnected();

  return { chat, ctx, page };
}

async function expectNoDocumentHorizontalOverflow(page: Page) {
  const metrics = await page.evaluate(() => {
    const root = document.documentElement;
    const body = document.body;

    return {
      rootClientWidth: root.clientWidth,
      rootScrollWidth: root.scrollWidth,
      bodyClientWidth: body.clientWidth,
      bodyScrollWidth: body.scrollWidth,
    };
  });

  expect(metrics.rootScrollWidth).toBeLessThanOrEqual(
    metrics.rootClientWidth + 2,
  );
  expect(metrics.bodyScrollWidth).toBeLessThanOrEqual(
    metrics.bodyClientWidth + 2,
  );
}

async function expectNoElementHorizontalOverflow(locator: Locator) {
  const metrics = await locator.evaluate((el) => {
    const htmlEl = el as HTMLElement;

    return {
      clientWidth: htmlEl.clientWidth,
      scrollWidth: htmlEl.scrollWidth,
    };
  });

  expect(metrics.scrollWidth).toBeLessThanOrEqual(metrics.clientWidth + 2);
}

test.describe("RSS link preview visual rendering", () => {
  // The row under test is planted through `/api/e2e/channel-messages`, a route
  // compiled in only when `:e2e_fault_injection?` is set. A deployment answers
  // 404 and the spec measures nothing.
  test.skip(
    !isLocalTarget(),
    localOnlyReason("the preview row is planted through the e2e-only API"),
  );

  async function renderPreview(
    browser: Browser,
    viewport: ViewportConfig,
    shotName: string,
    minImageWidth: number,
    minImageHeight: number,
  ) {
    const user = await newSignedInUser(browser, viewport);
    const channel = uniqueChannel();

    try {
      await user.chat.sendMessage(`/join ${channel}`);
      await user.chat.expectTabVisible(channel);
      await user.chat.expectTabSelected(channel);

      const response = await user.page.request.post(
        "/api/e2e/channel-messages",
        {
          data: {
            channel,
            author: "BBCWireBot",
            content: BBC_RSS_PREVIEW.markdown,
            content_format: "markdown",
            type: "message",
          },
        },
      );
      expect(response.ok()).toBeTruthy();

      const previewRow = user.chat.messageRowByText(BBC_RSS_PREVIEW.headline);
      await expect(previewRow).toBeVisible();
      await expect(previewRow).toHaveAttribute(
        "data-message-format",
        "markdown",
      );
      await expect(
        previewRow.locator('[data-nick="BBCWireBot"]'),
      ).toBeVisible();
      await expect(
        previewRow.getByRole("link", { name: BBC_RSS_PREVIEW.headline }),
      ).toHaveCount(0);
      await expect(
        previewRow.getByRole("link", { name: "Read full story" }),
      ).toHaveAttribute("href", BBC_RSS_PREVIEW.articleUrl);
      await expect(previewRow.locator("blockquote")).toContainText(
        BBC_RSS_PREVIEW.description,
      );

      const image = previewRow.locator("img.chat-markdown-image");
      await expect(image).toBeVisible();
      await expect(image).toHaveAttribute("src", BBC_RSS_PREVIEW.imageUrl);
      await expect(image).toHaveAttribute("alt", BBC_RSS_PREVIEW.imageAlt);
      await expect(image).toHaveAttribute("loading", "lazy");
      await expect(image).toHaveAttribute("decoding", "async");
      await expect(image).toHaveAttribute("referrerpolicy", "no-referrer");
      await expect
        .poll(async () =>
          image.evaluate((img) => {
            const node = img as HTMLImageElement;
            return node.complete && node.naturalWidth > 0;
          }),
        )
        .toBe(true);

      const imageBox = await image.evaluate((img) => {
        const rect = img.getBoundingClientRect();
        const style = window.getComputedStyle(img);

        return {
          width: rect.width,
          height: rect.height,
          display: style.display,
          objectFit: style.objectFit,
        };
      });

      expect(imageBox.display).toBe("block");
      expect(imageBox.objectFit).toBe("cover");
      expect(imageBox.width).toBeGreaterThan(minImageWidth);
      expect(imageBox.height).toBeGreaterThan(minImageHeight);

      await expectNoDocumentHorizontalOverflow(user.page);
      await expectNoElementHorizontalOverflow(user.chat.messageList);
      await expectNoElementHorizontalOverflow(previewRow);
      await shot(previewRow, shotName);
    } finally {
      await user.ctx.close();
    }
  }

  test("renders a BBC RSS item as a rich Markdown message in the desktop timeline", async ({
    browser,
  }) => {
    await renderPreview(
      browser,
      DESKTOP,
      "bbc-rss-rich-markdown-preview-desktop",
      420,
      220,
    );
  });

  test("keeps the BBC RSS Markdown preview contained on phone width", async ({
    browser,
  }) => {
    await renderPreview(
      browser,
      PHONE,
      "bbc-rss-rich-markdown-preview-phone",
      240,
      130,
    );
  });
});
