import { describe, expect, it, beforeEach } from "vitest";

import { currentLocale, jt, loadCatalog, normalizeLocale, t } from "../../js/lib/i18n.js";
import {
  DE,
  ES,
  FR,
  ID,
  IT,
  JA,
  NL,
  PL,
  PT_BR,
  PT_PT,
  RU,
  ZH_HANS,
  ZH_HANT,
} from "../../js/lib/i18n_catalog.js";

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
    expect(normalizeLocale("pt-PT")).toBe("pt_PT");
    expect(normalizeLocale("es-MX")).toBe("es");
    expect(normalizeLocale("fr-CA")).toBe("fr");
    expect(normalizeLocale("de-AT")).toBe("de");
    expect(normalizeLocale("it-IT")).toBe("it");
    expect(normalizeLocale("ja-JP")).toBe("ja");
    expect(normalizeLocale("nl-BE")).toBe("nl");
    expect(normalizeLocale("pl-PL")).toBe("pl");
    expect(normalizeLocale("zh-CN")).toBe("zh_hans");
    expect(normalizeLocale("zh-TW")).toBe("zh_hant");
    expect(normalizeLocale("zh-HK")).toBe("zh_hant");
    expect(normalizeLocale("id-ID")).toBe("id");
    expect(normalizeLocale("ru-RU")).toBe("ru");
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

  it("translates pt-BR strings and interpolates parameters", async () => {
    document.documentElement.setAttribute("lang", "pt-BR");
    await loadCatalog("pt-BR");

    expect(t("⚠️ Disconnected — Reconnecting...")).toBe("⚠️ Desconectado — Reconectando...");
    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe("Tipo de arquivo bloqueado: .exe");
  });

  it("translates pt-PT strings and interpolates parameters", async () => {
    document.documentElement.setAttribute("lang", "pt-PT");
    await loadCatalog("pt-PT");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe("Tipo de ficheiro bloqueado: .exe");
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("JOGADOR 1 VENCE!");
  });

  it("supports tagged template translations", async () => {
    document.documentElement.setAttribute("lang", "pt-BR");
    await loadCatalog("pt-BR");

    expect(jt`File exceeds the ${10} MB limit (${"12 MB"})`).toBe(
      "O arquivo excede o limite de 10 MB (12 MB)",
    );
  });

  it("translates Russian strings and interpolates parameters", async () => {
    document.documentElement.setAttribute("lang", "ru-RU");
    await loadCatalog("ru-RU");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe("Заблокированный тип файла: .exe");
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("ИГРОК 1 ПОБЕЖДАЕТ!");
  });

  it("translates Italian strings and interpolates parameters", async () => {
    document.documentElement.setAttribute("lang", "it-IT");
    await loadCatalog("it-IT");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe("Tipo di file bloccato: .exe");
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("GIOCATORE 1 VINCE!");
  });

  it("translates Traditional Chinese strings and interpolates parameters", async () => {
    document.documentElement.setAttribute("lang", "zh-TW");
    await loadCatalog("zh-TW");

    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("玩家 1 獲勝！");
  });

  it("translates Polish strings and interpolates parameters", async () => {
    document.documentElement.setAttribute("lang", "pl-PL");
    await loadCatalog("pl-PL");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe("Zablokowany typ pliku: .exe");
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("GRACZ 1 WYGRYWA!");
  });

  it("translates Dutch strings and interpolates parameters", async () => {
    document.documentElement.setAttribute("lang", "nl-BE");
    await loadCatalog("nl-BE");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe("Geblokkeerd bestandstype: .exe");
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("SPELER 1 WINT!");
  });
});

describe("pt-BR JS catalog", () => {
  it("contains critical UI, connection, and game translations", () => {
    expect(PT_BR).toMatchObject({
      Cancel: "Cancelar",
      "⚠️ Disconnected — Reconnecting...": "⚠️ Desconectado — Reconectando...",
      "✓ Reconnected!": "✓ Reconectado!",
      "Integrity check failed": "Falha na verificação de integridade",
      "Peer disconnected": "Par desconectado",
      "GOAL!": "GOL!",
    });
  });
});

describe("expanded JS catalogs", () => {
  it("preserves interpolation placeholders in every locale", () => {
    const catalogs = [DE, ES, FR, ID, IT, JA, NL, PL, PT_BR, PT_PT, RU, ZH_HANS, ZH_HANT];
    const placeholders = (message) => new Set(message.match(/%\{[A-Za-z0-9_]+\}/g) || []);

    for (const catalog of catalogs) {
      for (const [source, translated] of Object.entries(catalog)) {
        expect(placeholders(translated), source).toEqual(placeholders(source));
        expect(translated, source).not.toMatch(/XPH\d+X/i);
      }
    }
  });
});
