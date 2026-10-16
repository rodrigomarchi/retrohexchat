import { describe, expect, it, vi } from "vitest";
import {
  WELCOME_KEY,
  enteringChat,
  leftHome,
  rememberWelcomed,
  welcomeAction,
  welcomedBefore,
} from "../../../js/lib/site/welcome.js";

function storage(initial = {}) {
  const data = { ...initial };
  return {
    data,
    getItem: (key) => (key in data ? data[key] : null),
    setItem: (key, value) => {
      data[key] = value;
    },
  };
}

function target(matches) {
  return { closest: (selector) => (matches.some((m) => selector.includes(m)) ? {} : null) };
}

describe("welcome", () => {
  it("remembers a welcomed visitor and recognizes them", () => {
    const store = storage();
    expect(welcomedBefore(store)).toBe(false);

    rememberWelcomed(store);

    expect(store.data[WELCOME_KEY]).toBe("1");
    expect(welcomedBefore(store)).toBe(true);
  });

  it("treats storage that refuses as a first visit, without throwing", () => {
    const refusing = {
      getItem: vi.fn(() => {
        throw new Error("SecurityError");
      }),
      setItem: vi.fn(() => {
        throw new Error("QuotaExceededError");
      }),
    };

    expect(welcomedBefore(refusing)).toBe(false);
    expect(() => rememberWelcomed(refusing)).not.toThrow();
  });

  it("counts entering the chat and the Welcome's own window controls as acting on it", () => {
    expect(welcomeAction(target(["data-welcome-enter"]))).toBe(true);
    expect(welcomeAction(target(['[data-document-page="home"] [data-window-control]']))).toBe(true);
    expect(welcomeAction(target([]))).toBe(false);
    expect(welcomeAction(null)).toBe(false);
  });

  it("tells entering the chat apart from asking for an account", () => {
    expect(enteringChat(target(['[data-welcome-enter="chat"]']))).toBe(true);
    expect(enteringChat(target(['[data-welcome-enter="sign-up"]']))).toBe(false);
    expect(enteringChat(null)).toBe(false);
  });

  it("counts leaving the home, in any language, as having seen it", () => {
    const home = ["/", "/pt-BR"];

    expect(leftHome("/features", home)).toBe(true);
    expect(leftHome("http://x.test/c/lobby", home)).toBe(true);
    expect(leftHome("/", home)).toBe(false);
    expect(leftHome("/pt-BR/", home)).toBe(false);
    expect(leftHome(undefined, home)).toBe(false);
  });
});
