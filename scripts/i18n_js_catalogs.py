#!/usr/bin/env python3
"""Read and write browser-side i18n catalogs split by locale.

A facade so existing scripts keep importing one name. The implementation lives
in `i18n.catalogs`, and the locale set comes from `i18n.locales`, which reads
config/i18n_locales.exs.
"""

from __future__ import annotations

import sys
from collections import OrderedDict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from i18n.catalogs import (  # noqa: E402,F401
    JS_CATALOG_BARREL as CATALOG_BARREL,
    JS_CATALOG_DIR as CATALOG_DIR,
    import_js_exports,
    js_catalog_path as locale_catalog_path,
    read_js_catalogs as read_catalogs,
    write_js_barrel as write_barrel,
    write_js_catalogs as write_catalogs,
)
from i18n.locales import locale_exports  # noqa: E402

LOCALE_EXPORTS = OrderedDict(locale_exports())
