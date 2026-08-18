import { afterEach, describe, expect, it } from "vitest";

import {
  REACTION_TTL_MS,
  buildReactionBubble,
  ensureReactionStack,
  reactionEmoji,
  reactionIconNode,
} from "../../../js/lib/group_call/reactions.js";

afterEach(() => {
  document.body.innerHTML = "";
});

describe("reactionEmoji", () => {
  it("maps known reactions and defaults to a heart", () => {
    expect(reactionEmoji("thumbs_up")).toBe("👍");
    expect(reactionEmoji("clap")).toBe("👏");
    expect(reactionEmoji("unknown")).toBe("❤️");
  });
});

describe("ensureReactionStack", () => {
  it("creates the stack once and reuses it", () => {
    const tile = document.createElement("div");
    const first = ensureReactionStack(tile);
    const second = ensureReactionStack(tile);
    expect(first).toBe(second);
    expect(tile.querySelectorAll("[data-group-call-reactions]")).toHaveLength(1);
  });
});

describe("reactionIconNode", () => {
  it("clones the template icon when present", () => {
    const host = document.createElement("div");
    const template = document.createElement("template");
    template.setAttribute("data-group-call-reaction-icon-template", "heart");
    template.innerHTML = '<span class="icon">x</span>';
    host.appendChild(template);

    const node = reactionIconNode(host, "heart");
    expect(node).not.toBeNull();
    expect(node.className).toBe("icon");
  });

  it("is null when the host has no template for the reaction", () => {
    const host = document.createElement("div");
    expect(reactionIconNode(host, "heart")).toBeNull();
    expect(reactionIconNode(null, "heart")).toBeNull();
  });
});

describe("buildReactionBubble", () => {
  it("uses the icon node when given one", () => {
    const icon = document.createElement("span");
    icon.className = "icon";
    const bubble = buildReactionBubble({
      reaction: "heart",
      reactionId: "r1",
      iconNode: icon,
      emoji: "❤️",
    });
    expect(bubble.dataset.reaction).toBe("heart");
    expect(bubble.dataset.reactionId).toBe("r1");
    expect(bubble.querySelector(".icon")).toBe(icon);
    expect(bubble.textContent).toBe("");
  });

  it("falls back to the emoji text when there is no icon", () => {
    const bubble = buildReactionBubble({
      reaction: "clap",
      reactionId: "r2",
      iconNode: null,
      emoji: "👏",
    });
    expect(bubble.textContent).toBe("👏");
  });
});

describe("REACTION_TTL_MS", () => {
  it("is the bubble lifetime", () => {
    expect(REACTION_TTL_MS).toBe(2400);
  });
});
