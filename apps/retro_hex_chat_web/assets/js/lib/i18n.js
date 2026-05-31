import { DE, ES, FR, ID, JA, PT_BR, ZH_HANS } from "./i18n_catalog.js";

const CATALOGS = {
  de: DE,
  es: ES,
  fr: FR,
  id: ID,
  ja: JA,
  pt_BR: PT_BR,
  zh_Hans: ZH_HANS,
};

export function currentLocale() {
  if (typeof document === "undefined") return "en";

  const lang =
    document.documentElement?.getAttribute("lang") ||
    document.querySelector('meta[name="locale"]')?.content ||
    "en";

  return normalizeLocale(lang);
}

export function normalizeLocale(locale) {
  const value = String(locale || "")
    .trim()
    .replace("-", "_")
    .toLowerCase();

  if (value === "pt" || value === "pt_br") return "pt_BR";
  if (value === "es" || value.startsWith("es_")) return "es";
  if (value === "fr" || value.startsWith("fr_")) return "fr";
  if (value === "de" || value.startsWith("de_")) return "de";
  if (value === "ja" || value.startsWith("ja_")) return "ja";
  if (value === "id" || value === "in" || value.startsWith("id_") || value.startsWith("in_")) {
    return "id";
  }
  if (value === "zh" || value === "zh_hans" || value === "zh_cn" || value === "zh_sg") {
    return "zh_Hans";
  }
  return "en";
}

export function t(message, params = {}) {
  const catalog = CATALOGS[currentLocale()] || {};
  const translated = catalog[message] || message;
  return interpolate(translated, params);
}

export function jt(strings, ...values) {
  const message = strings.reduce((acc, part, index) => {
    if (index >= values.length) return acc + part;
    return `${acc}${part}%{${index}}`;
  }, "");

  const params = Object.fromEntries(values.map((value, index) => [String(index), value]));
  return t(message, params);
}

function interpolate(message, params) {
  return message.replace(/%\{([^}]+)\}/g, (match, key) =>
    Object.prototype.hasOwnProperty.call(params, key) ? String(params[key]) : match,
  );
}
