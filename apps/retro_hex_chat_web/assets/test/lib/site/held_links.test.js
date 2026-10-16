import { describe, expect, it } from "vitest";
import { heldLinkHref, linkFor } from "../../../js/lib/site/held_links.js";

function clickOn(html, selector, overrides = {}) {
  document.body.innerHTML = html;
  const target = document.querySelector(selector);
  return {
    target,
    button: 0,
    defaultPrevented: false,
    metaKey: false,
    ctrlKey: false,
    shiftKey: false,
    altKey: false,
    ...overrides,
  };
}

const PATCH = '<a href="/connect?signup=chat" data-phx-link="patch"><span>Create</span></a>';

describe("heldLinkHref", () => {
  it("holds a patch link clicked while the chat starts", () => {
    expect(heldLinkHref(clickOn(PATCH, "span"), "loading")).toBe("/connect?signup=chat");
    expect(heldLinkHref(clickOn(PATCH, "a"), "idle")).toBe("/connect?signup=chat");
  });

  it("lets it through once the chat is live", () => {
    expect(heldLinkHref(clickOn(PATCH, "a"), "ready")).toBeNull();
  });

  it("lets through a plain link, a new-tab click and a modified click", () => {
    expect(heldLinkHref(clickOn('<a href="/faq">x</a>', "a"), "loading")).toBeNull();
    expect(heldLinkHref(clickOn(PATCH, "a", { ctrlKey: true }), "loading")).toBeNull();
    expect(heldLinkHref(clickOn(PATCH, "a", { button: 1 }), "loading")).toBeNull();
    expect(heldLinkHref(clickOn(PATCH, "a", { defaultPrevented: true }), "loading")).toBeNull();
  });
});

describe("linkFor", () => {
  it("finds the redrawn link for a held address", () => {
    document.body.innerHTML = PATCH;
    expect(linkFor(document, "/connect?signup=chat")).toBe(document.querySelector("a"));
    expect(linkFor(document, "/elsewhere")).toBeNull();
    expect(linkFor(document, null)).toBeNull();
  });
});
