# Padrao de catalogos i18n

RetroHexChat usa Gettext com ingles como idioma fonte e catalogos versionados.
O padrao do projeto e manter os catalogos pequenos por dominio funcional, em
vez de concentrar tudo em `default.po`.

## Locales

Locales ficam registrados em `config/i18n_locales.exs`, com:

- codigo do diretorio Gettext, por exemplo `pt_BR` ou `zh_Hans`;
- tag BCP 47 para HTML, por exemplo `pt-BR` ou `zh-Hans`;
- locale Open Graph;
- nome nativo para o seletor de idioma;
- direcao de texto `ltr` ou `rtl`;
- `Plural-Forms` Gettext;
- onda de rollout e status.

Onda 0 esta em producao desde a primeira fase: `en`, `pt_BR`.

Onda 1 esta habilitada: `es`, `fr`, `de`, `ja`, `zh_Hans`, `id`.

Ondas planejadas:

- Onda 2: `ar`, `ru`, `hi`, `ko`, `tr`, `vi`.
- Onda 3: `bn`, `ur`, `zh_Hant`, `pt_PT`, `it`, `pl`, `nl`.

Idiomas RTL (`ar`, `ur`) devem ser habilitados somente depois de revisao visual,
pois o layout usa `dir={RetroHexChatWeb.I18n.html_dir()}` no elemento `html`.

## Dominios

`apps/retro_hex_chat`:

- `accounts`, `admin`, `arcade`, `bots`, `channels`, `chat`, `commands`,
  `emoji`, `games`, `help`, `p2p`, `services`
- `default` deve ficar vazio ou conter apenas strings realmente transversais.

`apps/retro_hex_chat_web`:

- `admin`, `chat`, `connect`, `default`, `diagrams`, `dialogs`, `errors`,
  `games`, `landing`, `p2p`, `showcase`, `system`, `ui`
- Ajuda longa fica quebrada em `help`, `help_arcade`, `help_bots`,
  `help_channels`, `help_commands`, `help_features`, `help_games`,
  `help_p2p` e `help_ui`.

## Regras

- Codigo novo deve usar `dgettext/2`, `dngettext/4` ou `dpgettext/3` com o
  dominio certo. Use `gettext/1` so quando a string pertence de fato ao
  `default`.
- `msgid` continua em ingles e deve ser literal para manter a extracao
  automatica.
- Interpolacao deve usar placeholders Gettext, por exemplo
  `dgettext("chat", "Hello, %{name}", name: name)`.
- Arquivo `.po` acima de 12.000 linhas e regressao: crie ou refine um dominio.
- locales habilitados nao podem ter `msgstr ""`, `fuzzy` pendente ou perda de
  placeholders Gettext.
- locales habilitados tambem nao podem manter fallback em ingles quando a string
  com placeholder e claramente texto de usuario. Formatos tecnicos, placares,
  URLs, comandos e envelopes de servico ficam documentados na allowlist de
  `scripts/i18n_source_fallback_check.py`.
- Traducao automatica e aceita como rascunho funcional, mas revisao humana ainda
  e necessaria para terminologia, tom e nomes de recursos.

## Fluxo

Depois de mudar strings traduziveis:

```sh
make i18n.gettext.rebuild
make i18n.catalog.check
make i18n.gettext.check
```

Para adicionar uma onda:

```sh
make i18n.locales.add WAVE=2
```

Para adicionar locales especificos:

```sh
make i18n.locales.add LOCALES=es,fr,de
```

Para preencher catalogos com traducao automatica draft, use um ambiente Python
temporario com Argos Translate e Polib:

```sh
python -m venv /tmp/retro_hex_chat_i18n_venv
/tmp/retro_hex_chat_i18n_venv/bin/python -m pip install argostranslate polib
/tmp/retro_hex_chat_i18n_venv/bin/python - <<'PY'
from argostranslate import package
wanted = {"es", "fr", "de"}
package.update_package_index()
for pkg in package.get_available_packages():
    if pkg.from_code == "en" and pkg.to_code in wanted:
        package.install_from_path(pkg.download())
PY
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_machine_translate_po.py --locales es,fr,de
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_machine_translate_js.py --locales es,fr,de
```

Depois da traducao automatica:

```sh
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_repair_placeholder_mismatches.py
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_apply_translation_overrides.py --locales pt_BR,es,fr,de,ja,zh_Hans,id
elixir scripts/i18n_normalize_po_headers.exs
make i18n.placeholder.check
make i18n.source-fallback.check
make i18n.catalog.check
```

`scripts/i18n_apply_translation_overrides.py` e a memoria manual para strings
que a traducao automatica costuma deixar em ingles ou traduzir mal por causa de
placeholders. Sempre que a auditoria de fallback acusar texto humano novo, a
correcao deve entrar ali ou diretamente no catalogo com uma regra equivalente.

Para refatoracoes grandes:

```sh
elixir scripts/i18n_domainize_gettext_calls.exs
elixir scripts/i18n_split_help_domains.exs
make i18n.gettext.rebuild
```

`scripts/i18n_rehydrate_domain_translations.exs` reconstrui os `.po` a partir
dos `.pot` atuais e copia traducoes ja existentes por `msgid`. Isso evita
perder traducoes quando um texto muda apenas de dominio.
