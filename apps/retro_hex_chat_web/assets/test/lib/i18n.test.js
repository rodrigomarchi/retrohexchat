import { describe, expect, it, beforeEach } from "vitest";

import { currentLocale, jt, normalizeLocale, t } from "../../js/lib/i18n.js";
import {
  AR,
  BN,
  DE,
  ES,
  FR,
  HI,
  ID,
  IT,
  JA,
  KO,
  NL,
  PL,
  PT_BR,
  PT_PT,
  RU,
  TR,
  UR,
  VI,
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
    expect(normalizeLocale("zh-CN")).toBe("zh_Hans");
    expect(normalizeLocale("zh-TW")).toBe("zh_Hant");
    expect(normalizeLocale("zh-HK")).toBe("zh_Hant");
    expect(normalizeLocale("id-ID")).toBe("id");
    expect(normalizeLocale("ar-SA")).toBe("ar");
    expect(normalizeLocale("bn-BD")).toBe("bn");
    expect(normalizeLocale("bn-IN")).toBe("bn");
    expect(normalizeLocale("ru-RU")).toBe("ru");
    expect(normalizeLocale("hi-IN")).toBe("hi");
    expect(normalizeLocale("ko-KR")).toBe("ko");
    expect(normalizeLocale("tr-TR")).toBe("tr");
    expect(normalizeLocale("ur-PK")).toBe("ur");
    expect(normalizeLocale("ur-IN")).toBe("ur");
    expect(normalizeLocale("vi-VN")).toBe("vi");
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

  it("translates pt-PT strings and interpolates parameters", () => {
    document.documentElement.setAttribute("lang", "pt-PT");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe(
      "Tipo de ficheiro bloqueado: .exe",
    );
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("JOGADOR 1 VENCE!");
  });

  it("supports tagged template translations", () => {
    document.documentElement.setAttribute("lang", "pt-BR");

    expect(jt`File exceeds the ${10} MB limit (${"12 MB"})`).toBe(
      "O arquivo excede o limite de 10 MB (12 MB)",
    );
  });

  it("translates Bengali strings and interpolates parameters", () => {
    document.documentElement.setAttribute("lang", "bn-BD");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe(
      "অবরুদ্ধ ফাইলের ধরন: .exe",
    );
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("খেলোয়াড় 1 জিতেছে!");
  });

  it("translates Urdu strings and interpolates parameters", () => {
    document.documentElement.setAttribute("lang", "ur-PK");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe(
      "مسدود فائل کی قسم: .exe",
    );
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("کھلاڑی 1 جیت گیا!");
  });

  it("translates Traditional Chinese strings and interpolates parameters", () => {
    document.documentElement.setAttribute("lang", "zh-TW");

    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("玩家 1 獲勝！");
  });

  it("translates Italian strings and interpolates parameters", () => {
    document.documentElement.setAttribute("lang", "it-IT");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe(
      "Tipo di file bloccato: .exe",
    );
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("GIOCATORE 1 VINCE!");
  });

  it("translates Polish strings and interpolates parameters", () => {
    document.documentElement.setAttribute("lang", "pl-PL");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe(
      "Zablokowany typ pliku: .exe",
    );
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("GRACZ 1 WYGRYWA!");
  });

  it("translates Dutch strings and interpolates parameters", () => {
    document.documentElement.setAttribute("lang", "nl-BE");

    expect(t("Blocked file type: %{0}", { 0: ".exe" })).toBe(
      "Geblokkeerd bestandstype: .exe",
    );
    expect(t("PLAYER %{0} WINS!", { 0: "1" })).toBe("SPELER 1 WINT!");
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

describe("expanded JS catalogs", () => {
  it("preserves interpolation placeholders in every locale", () => {
    const catalogs = [
      AR,
      BN,
      DE,
      ES,
      FR,
      HI,
      ID,
      IT,
      JA,
      KO,
      NL,
      PL,
      PT_BR,
      PT_PT,
      RU,
      TR,
      UR,
      VI,
      ZH_HANS,
      ZH_HANT,
    ];
    const placeholders = (message) => new Set(message.match(/%\{[A-Za-z0-9_]+\}/g) || []);

    for (const catalog of catalogs) {
      for (const [source, translated] of Object.entries(catalog)) {
        expect(placeholders(translated), source).toEqual(placeholders(source));
        expect(translated, source).not.toMatch(/XPH\d+X/i);
      }
    }
  });
});
