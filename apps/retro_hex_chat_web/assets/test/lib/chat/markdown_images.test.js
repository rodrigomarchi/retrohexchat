import { afterEach, describe, expect, it, vi } from "vitest";

import { createMarkdownImageRevealer } from "../../../js/lib/chat/markdown_images.js";

function tick() {
  return new Promise((resolve) => setTimeout(resolve, 0));
}

function setImageReadiness(img, { complete, naturalWidth }) {
  Object.defineProperty(img, "complete", {
    value: complete,
    configurable: true,
  });
  Object.defineProperty(img, "naturalWidth", {
    value: naturalWidth,
    configurable: true,
  });
}

function appendImage(root, options = {}) {
  const shell = document.createElement("span");
  shell.className = "chat-markdown-image-shell";
  shell.dataset.imageState = "loading";

  const img = document.createElement("img");
  img.className = "chat-markdown-image";
  img.src = options.src || "https://example.test/card.png";
  setImageReadiness(img, {
    complete: options.complete ?? false,
    naturalWidth: options.naturalWidth ?? 0,
  });
  if (options.decode) img.decode = options.decode;

  shell.appendChild(img);
  root.appendChild(shell);

  return { shell, img };
}

afterEach(() => {
  document.body.innerHTML = "";
});

describe("createMarkdownImageRevealer", () => {
  it("reveals an image after load and decode", async () => {
    const decode = vi.fn(() => Promise.resolve());
    const { shell, img } = appendImage(document.body, { decode });
    const controller = createMarkdownImageRevealer(document.body);

    controller.mount();
    expect(shell.dataset.imageState).toBe("loading");

    setImageReadiness(img, { complete: true, naturalWidth: 320 });
    img.dispatchEvent(new Event("load"));
    await tick();

    expect(decode).toHaveBeenCalled();
    expect(shell.dataset.imageState).toBe("loaded");
    expect(img.dataset.imageState).toBe("loaded");
    controller.destroy();
  });

  it("reveals a cached complete image during mount", async () => {
    const decode = vi.fn(() => Promise.resolve());
    const { shell, img } = appendImage(document.body, {
      complete: true,
      naturalWidth: 320,
      decode,
    });
    const controller = createMarkdownImageRevealer(document.body);

    controller.mount();
    await tick();

    expect(decode).toHaveBeenCalled();
    expect(shell.dataset.imageState).toBe("loaded");
    expect(img.dataset.imageState).toBe("loaded");
    controller.destroy();
  });

  it("marks a failed image so the placeholder does not spin forever", () => {
    const { shell, img } = appendImage(document.body);
    const controller = createMarkdownImageRevealer(document.body);

    controller.mount();
    img.dispatchEvent(new Event("error"));

    expect(shell.dataset.imageState).toBe("failed");
    expect(img.dataset.imageState).toBe("failed");
    controller.destroy();
  });

  it("tracks images added after mount on reconcile", async () => {
    const controller = createMarkdownImageRevealer(document.body);
    controller.mount();

    const { shell } = appendImage(document.body, {
      complete: true,
      naturalWidth: 320,
      decode: () => Promise.resolve(),
    });
    controller.reconcile();
    await tick();

    expect(shell.dataset.imageState).toBe("loaded");
    controller.destroy();
  });
});
