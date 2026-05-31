# Padrao de catalogos i18n

RetroHexChat usa Gettext com ingles como idioma fonte e catalogos `en` e
`pt_BR` versionados. O padrao do projeto e manter os catalogos pequenos por
dominio funcional, em vez de concentrar tudo em `default.po`.

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
- `pt_BR` nao pode ter `msgstr ""` nem `fuzzy` pendente.

## Fluxo

Depois de mudar strings traduziveis:

```sh
make i18n.gettext.rebuild
make i18n.catalog.check
make i18n.gettext.check
```

Para refatoracoes grandes:

```sh
elixir scripts/i18n_domainize_gettext_calls.exs
elixir scripts/i18n_split_help_domains.exs
make i18n.gettext.rebuild
```

`scripts/i18n_rehydrate_domain_translations.exs` reconstrui os `.po` a partir
dos `.pot` atuais e copia traducoes ja existentes por `msgid`. Isso evita
perder traducoes quando um texto muda apenas de dominio.
