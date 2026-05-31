import { describe, expect, it, beforeEach } from "vitest";

import { currentLocale, jt, normalizeLocale, t } from "../../js/lib/i18n.js";
import { PT_BR } from "../../js/lib/i18n_catalog.js";

describe("i18n runtime", () => {
  beforeEach(() => {
    document.documentElement.removeAttribute("lang");
    document.querySelectorAll('meta[name="locale"]').forEach((el) => el.remove());
  });

  it("normalizes supported locale aliases and falls back to English", () => {
    expect(normalizeLocale("en")).toBe("en");
    expect(normalizeLocale("en-US")).toBe("en");
    expect(normalizeLocale("pt")).toBe("pt_BR");
    expect(normalizeLocale("pt-BR")).toBe("pt_BR");
    expect(normalizeLocale("pt_BR")).toBe("pt_BR");
    expect(normalizeLocale("es")).toBe("en");
    expect(normalizeLocale(null)).toBe("en");
  });

  it("reads the locale from html lang before meta locale", () => {
    const meta = document.createElement("meta");
    meta.setAttribute("name", "locale");
    meta.setAttribute("content", "pt-BR");
    document.head.appendChild(meta);

    expect(currentLocale()).toBe("pt_BR");

    document.documentElement.setAttribute("lang", "en");
    expect(currentLocale()).toBe("en");
  });

  it("returns English msgids for English or missing translations", () => {
    document.documentElement.setAttribute("lang", "en");

    expect(t("Connect")).toBe("Connect");
    expect(t("Unknown %{name}", { name: "token" })).toBe("Unknown token");
  });

  it("translates pt-BR strings and interpolates parameters", () => {
    document.documentElement.setAttribute("lang", "pt-BR");

    expect(t("⚠️ Disconnected — Reconnecting...")).toBe("⚠️ Desconectado — Reconectando...");
    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe("Tipo de arquivo bloqueado: .exe");
  });

  it("supports tagged template translations", () => {
    document.documentElement.setAttribute("lang", "pt-BR");

    expect(jt`File exceeds the ${10} MB limit (${"12 MB"})`).toBe(
      "O arquivo excede o limite de 10 MB (12 MB)",
    );
  });
});

describe("pt-BR JS catalog", () => {
  it("contains critical UI, connection, and game translations", () => {
    expect(PT_BR).toMatchObject({
      Cancel: "Cancelar",
      "New messages": "Novas mensagens",
      "⚠️ Disconnected — Reconnecting...": "⚠️ Desconectado — Reconectando...",
      "✓ Reconnected!": "✓ Reconectado!",
      "Integrity check failed": "Falha na verificação de integridade",
      "Peer disconnected": "Par desconectado",
      "GOAL!": "GOL!",
    });
  });
});
