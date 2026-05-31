import { PT_BR } from "./i18n_catalog.js";

const CATALOGS = {
  pt_BR: PT_BR,
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
