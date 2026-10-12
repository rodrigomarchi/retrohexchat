import { describe, it, expect, vi } from "vitest";

import { renderPanel } from "../../../../js/lib/space/construct/panels.js";

function shell() {
  const root = document.createElement("div");
  root.innerHTML = `
    <div data-space-modal></div>
    <template data-space-panel-template
      data-title-sign="Sign" data-title-board="Board" data-title-screen="Screen" data-title-arcade="Arcade"
      data-empty-sign="Nothing written." data-empty-board="Nothing here." data-empty-screen="No pictures."
      data-topic="Topic" data-pinned="Pinned" data-posted-by="Posted by %{name}" data-opens-in-tab="New tab.">
      <div>
        <span data-space-panel-icon="sign" hidden></span>
        <span data-space-panel-icon="board" hidden></span>
        <span data-space-panel-icon="arcade" hidden></span>
        <p data-space-panel-title></p>
        <div data-space-panel-body></div>
        <form data-space-panel-sign hidden><input data-space-panel-input /></form>
        <p data-space-panel-status></p>
        <button data-space-panel-close></button>
      </div>
    </template>`;
  document.body.appendChild(root);
  return { root, host: root.querySelector("[data-space-modal]") };
}

const ports = () => ({ save: vi.fn(), close: vi.fn(), refusal: vi.fn(() => "Not yours.") });

describe("renderPanel", () => {
  it("leaves a modal it does not draw to the caller", () => {
    const { root, host } = shell();
    expect(renderPanel(root, host, { kind: "confirm" }, ports())).toBe(false);
    expect(host.childNodes).toHaveLength(0);
  });

  it("shows a board's topic and pinned lines, or says it is empty", () => {
    const { root, host } = shell();
    renderPanel(
      root,
      host,
      { kind: "board", topic: "Movie night", pins: [{ author: "ana", text: "Bring snacks" }] },
      ports(),
    );
    expect(host.querySelector("[data-space-panel-title]").textContent).toBe("Board");
    expect(host.textContent).toContain("Movie night");
    expect(host.textContent).toContain("ana: Bring snacks");

    renderPanel(root, host, { kind: "board", topic: null, pins: [] }, ports());
    expect(host.textContent).toContain("Nothing here.");
  });

  it("shows the newest picture with who posted it", () => {
    const { root, host } = shell();
    renderPanel(
      root,
      host,
      {
        kind: "screen",
        image: { url: "/chat/attachments/7/preview", name: "cat.png", author: "bob" },
      },
      ports(),
    );
    const img = host.querySelector("img");
    expect(img.getAttribute("src")).toBe("/chat/attachments/7/preview");
    expect(img.alt).toBe("cat.png");
    expect(host.textContent).toContain("Posted by bob");
  });

  it("lists an arcade's games as links that open a new tab", () => {
    const { root, host } = shell();
    renderPanel(
      root,
      host,
      {
        kind: "arcade",
        games: [{ id: "doom", name: "Doom", tagline: "Rip", url: "/play/arcade/doom" }],
      },
      ports(),
    );
    const link = host.querySelector("a");
    expect(link.getAttribute("href")).toBe("/play/arcade/doom");
    expect(link.target).toBe("_blank");
    expect(link.rel).toBe("noopener");
  });

  it("lets whoever may write on a sign save it, and says why a save is refused", () => {
    const { root, host } = shell();
    const p = ports();
    renderPanel(root, host, { kind: "sign", item_id: "s1", text: "Hi", can_edit: true }, p);

    const input = host.querySelector("[data-space-panel-input]");
    expect(host.querySelector("form").hidden).toBe(false);
    expect(input.value).toBe("Hi");
    expect(document.activeElement).toBe(input);

    // Enter stays in the field: the say bar below the map must not get it.
    const outside = vi.fn();
    window.addEventListener("keydown", outside);
    input.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
    window.removeEventListener("keydown", outside);
    expect(outside).not.toHaveBeenCalled();

    input.value = "Welcome";
    host.querySelector("form").dispatchEvent(new Event("submit", { cancelable: true }));
    expect(p.save).toHaveBeenCalledWith("Welcome", expect.any(Object));

    p.save.mock.calls[0][1].error("not_allowed");
    expect(host.querySelector("[data-space-panel-status]").textContent).toBe("Not yours.");
    p.save.mock.calls[0][1].ok();
    expect(p.close).toHaveBeenCalledOnce();
  });

  it("shows a sign read-only to anybody else", () => {
    const { root, host } = shell();
    renderPanel(root, host, { kind: "sign", item_id: "s1", text: null, can_edit: false }, ports());
    expect(host.querySelector("form").hidden).toBe(true);
    expect(host.textContent).toContain("Nothing written.");
    host.querySelector("[data-space-panel-close]").click();
  });

  it("shows the icon of the piece it is, and only that one", () => {
    const { root, host } = shell();
    renderPanel(root, host, { kind: "board", topic: "x", pins: [] }, ports());
    expect(host.querySelector('[data-space-panel-icon="board"]').hidden).toBe(false);
    expect(host.querySelector('[data-space-panel-icon="sign"]').hidden).toBe(true);
    expect(host.dataset.kind).toBe("board");
  });

  it("puts each pinned author's portrait beside their line, when they chose one", () => {
    const { root, host } = shell();
    renderPanel(
      root,
      host,
      {
        kind: "board",
        topic: null,
        pins: [
          { author: "ana", text: "Snacks", avatar: "knight" },
          { author: "bo", text: "Drinks", avatar: null },
          { author: "cy", text: "Odd", avatar: "x y" },
        ],
      },
      ports(),
    );
    const rows = host.querySelectorAll(".space-panel-byline");
    expect(rows).toHaveLength(3);
    expect(rows[0].querySelector(".rh-portrait--knight")).not.toBeNull();
    expect(rows[1].querySelector(".rh-portrait")).toBeNull();
    // Only a roster id becomes a class.
    expect(rows[2].querySelector(".rh-portrait")).toBeNull();
    expect(rows[0].textContent).toBe("ana: Snacks");
  });

  it("shelves an arcade's games with their covers, lazily, and an initial for one without", () => {
    const { root, host } = shell();
    renderPanel(
      root,
      host,
      {
        kind: "arcade",
        games: [
          { id: "doom", name: "Doom", tagline: "Rip", url: "/a/doom", cover: "/img/doom.webp" },
          { id: "pong", name: "Pong", tagline: "Pong", url: "/a/pong", cover: null },
        ],
      },
      ports(),
    );
    const img = host.querySelector('[data-testid="space-panel-game-doom"] img');
    expect(img.getAttribute("src")).toBe("/img/doom.webp");
    expect(img.getAttribute("loading")).toBe("lazy");
    expect(img.alt).toBe("");
    const blank = host.querySelector(
      '[data-testid="space-panel-game-pong"] .space-panel-cover--blank',
    );
    expect(blank.textContent).toBe("P");
  });

  it("gives a cartridge whose cover does not load its initial instead", () => {
    const { root, host } = shell();
    renderPanel(
      root,
      host,
      { kind: "arcade", games: [{ id: "x", name: "Xenon", url: "/x", cover: "/missing.webp" }] },
      ports(),
    );
    host.querySelector("img.space-panel-cover").dispatchEvent(new Event("error"));
    expect(host.querySelector(".space-panel-cover--blank").textContent).toBe("X");
  });

  it("shows the portrait of whoever posted the picture on a screen", () => {
    const { root, host } = shell();
    renderPanel(
      root,
      host,
      { kind: "screen", image: { url: "/p.png", name: "p.png", author: "ana", avatar: "monk" } },
      ports(),
    );
    expect(host.querySelector(".space-panel-byline .rh-portrait--monk")).not.toBeNull();
    expect(host.textContent).toContain("Posted by ana");
  });
});
