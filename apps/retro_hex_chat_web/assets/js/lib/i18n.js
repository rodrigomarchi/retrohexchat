const CATALOGS = {
  en: {},
};

const CATALOG_LOADERS = {
  ar: () => import("./i18n_catalogs/ar.js").then((module) => module.AR),
  bn: () => import("./i18n_catalogs/bn.js").then((module) => module.BN),
  de: () => import("./i18n_catalogs/de.js").then((module) => module.DE),
  es: () => import("./i18n_catalogs/es.js").then((module) => module.ES),
  fr: () => import("./i18n_catalogs/fr.js").then((module) => module.FR),
  hi: () => import("./i18n_catalogs/hi.js").then((module) => module.HI),
  id: () => import("./i18n_catalogs/id.js").then((module) => module.ID),
  it: () => import("./i18n_catalogs/it.js").then((module) => module.IT),
  ja: () => import("./i18n_catalogs/ja.js").then((module) => module.JA),
  ko: () => import("./i18n_catalogs/ko.js").then((module) => module.KO),
  nl: () => import("./i18n_catalogs/nl.js").then((module) => module.NL),
  pl: () => import("./i18n_catalogs/pl.js").then((module) => module.PL),
  pt_BR: () => import("./i18n_catalogs/pt_BR.js").then((module) => module.PT_BR),
  pt_PT: () => import("./i18n_catalogs/pt_PT.js").then((module) => module.PT_PT),
  ru: () => import("./i18n_catalogs/ru.js").then((module) => module.RU),
  tr: () => import("./i18n_catalogs/tr.js").then((module) => module.TR),
  ur: () => import("./i18n_catalogs/ur.js").then((module) => module.UR),
  vi: () => import("./i18n_catalogs/vi.js").then((module) => module.VI),
  zh_hans: () => import("./i18n_catalogs/zh_hans.js").then((module) => module.ZH_HANS),
  zh_hant: () => import("./i18n_catalogs/zh_hant.js").then((module) => module.ZH_HANT),
};

const CATALOG_PROMISES = {};

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

export async function loadCatalog(locale = currentLocale()) {
  const normalized = normalizeLocale(locale);
  const loader = CATALOG_LOADERS[normalized];

  if (CATALOGS[normalized]) return CATALOGS[normalized];
  if (!loader) return CATALOGS.en;

  if (!CATALOG_PROMISES[normalized]) {
    CATALOG_PROMISES[normalized] = loader()
      .then((catalog) => {
        CATALOGS[normalized] = catalog || {};
        return CATALOGS[normalized];
      })
      .catch(() => {
        CATALOGS[normalized] = {};
        return CATALOGS[normalized];
      });
  }

  return CATALOG_PROMISES[normalized];
}

export function loadCurrentLocaleCatalog() {
  return loadCatalog(currentLocale());
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
