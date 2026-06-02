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
} from "./i18n_catalog.js";

const CATALOGS = {
  ar: AR,
  bn: BN,
  de: DE,
  es: ES,
  fr: FR,
  hi: HI,
  id: ID,
  it: IT,
  ja: JA,
  ko: KO,
  nl: NL,
  pl: PL,
  pt_BR: PT_BR,
  pt_PT: PT_PT,
  ru: RU,
  tr: TR,
  ur: UR,
  vi: VI,
  zh_hans: ZH_HANS,
  zh_hant: ZH_HANT,
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

  if (value === "pt_pt") return "pt_PT";
  if (value === "pt" || value === "pt_br") return "pt_BR";
  if (value === "ar" || value.startsWith("ar_")) return "ar";
  if (value === "bn" || value.startsWith("bn_")) return "bn";
  if (value === "es" || value.startsWith("es_")) return "es";
  if (value === "fr" || value.startsWith("fr_")) return "fr";
  if (value === "de" || value.startsWith("de_")) return "de";
  if (value === "hi" || value.startsWith("hi_")) return "hi";
  if (value === "it" || value.startsWith("it_")) return "it";
  if (value === "ja" || value.startsWith("ja_")) return "ja";
  if (value === "ko" || value.startsWith("ko_")) return "ko";
  if (value === "nl" || value.startsWith("nl_")) return "nl";
  if (value === "pl" || value.startsWith("pl_")) return "pl";
  if (value === "ru" || value.startsWith("ru_")) return "ru";
  if (value === "tr" || value.startsWith("tr_")) return "tr";
  if (value === "ur" || value.startsWith("ur_")) return "ur";
  if (value === "vi" || value.startsWith("vi_")) return "vi";
  if (value === "id" || value === "in" || value.startsWith("id_") || value.startsWith("in_")) {
    return "id";
  }
  if (value === "zh_hant" || value === "zh_tw" || value === "zh_hk" || value === "zh_mo") {
    return "zh_hant";
  }
  if (value === "zh" || value === "zh_hans" || value === "zh_cn" || value === "zh_sg") {
    return "zh_hans";
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
