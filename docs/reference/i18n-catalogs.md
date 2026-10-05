# Padrao de catalogos i18n

RetroHexChat usa Gettext com ingles como idioma fonte e catalogos versionados.
O padrao do projeto e manter os catalogos pequenos por dominio funcional, em
vez de concentrar tudo em `default.po`.

## Locales

Locales ficam registrados em `config/i18n_locales.exs`, com:

- codigo do diretorio Gettext, por exemplo `pt_BR` ou `zh_hans`;
- tag BCP 47 para HTML, por exemplo `pt-BR` ou `zh-Hans`;
- locale Open Graph;
- nome nativo para o seletor de idioma;
- direcao de texto `ltr` ou `rtl`;
- `Plural-Forms` Gettext;
- onda de rollout e status.

O conjunto habilitado sao 14 locales, todos com `status: :enabled` no registro:

| Onda | Locales |
| --- | --- |
| 0 | `en`, `pt_BR` |
| 1 | `es`, `fr`, `de`, `ja`, `zh_hans`, `id` |
| 2 | `ru` |
| 3 | `zh_hant`, `pt_PT`, `it`, `pl`, `nl` |

Nao existe locale planejado fora dessa lista. Adicionar ou remover um idioma e
uma edicao de um arquivo so, `config/i18n_locales.exs` — o Makefile, os catalogos
do browser e os checkers Python derivam dali. Nunca escreva uma lista de locales
em outro lugar.

Todos os locales habilitados sao LTR. O caminho RTL continua no codigo
(`dir={RetroHexChatWeb.I18n.html_dir()}` no elemento `html`), mas hoje nao e
exercitado por nenhum locale; um idioma RTL futuro exige revisao visual dedicada.

## Dominios

`apps/retro_hex_chat`:

- `accounts`, `admin`, `arcade`, `bots`, `channels`, `chat`, `commands`,
  `emoji`, `games`, `group_call`, `help`, `p2p`, `services`
- `default` deve ficar vazio ou conter apenas strings realmente transversais.

`apps/retro_hex_chat_web`:

- `admin`, `chat`, `connect`, `default`, `diagrams`, `dialogs`, `errors`,
  `games`, `group_call`, `landing`, `p2p`, `showcase`, `system`, `ui`
- Ajuda longa fica quebrada em `help`, `help_arcade`, `help_bots`,
  `help_channels`, `help_commands`, `help_features`, `help_games`,
  `help_p2p` e `help_ui`.

Catalogos JavaScript ficam em `apps/retro_hex_chat_web/assets/js/lib/i18n_catalogs`,
um arquivo por locale. `i18n_catalog.js` e apenas o barrel de compatibilidade
que reexporta esses arquivos para o runtime e para os testes.

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
- Escrita em lote **casa por msgid E dominio**, nunca so por msgid. Um script
  que varreu todos os `.po` procurando `%{count} minute` sobrescreveu doze
  entradas de `chat.po` que ja tinham traducao propria: as mesmas palavras em
  ingles, outro catalogo, resposta de outra pessoa. O `tar` previo mais o diff
  de cada `msgstr` foi o que achou — duas vezes ja (uma em `accounts`, uma
  nestas). Limite a escrita aos dominios que o extract realmente tocou.
- Procurar `fuzzy` num `.po` com `grep` acha tambem os `msgid` que falam de
  busca fuzzy. A flag e uma linha `#,` — case por `^#,.*\bfuzzy\b`, ou voce
  vai investigar traducoes que estao corretas.
- `fuzzy` **renderiza**. O Gettext serve uma traducao marcada `fuzzy` como
  qualquer outra, entao ela nao e "quase pronta", e o texto antigo saindo na
  tela com a confianca do texto novo. Medido em 2026-09-01: `repeat window`
  aparecia como "janela limpa", `Sharing a Game` como "Iniciando um jogo solo",
  e o convite P2P em chines carregava `/p2p/ %{token}` — com espaco, link
  morto. Limpar a bandeira e uma decisao por entrada, nunca em lote.

### O terceiro checker, e o buraco que ele fechou

`i18n_po_status` conta entradas **presentes** no `.po`; `i18n.gettext.check`
afirma que o `.pot` esta fresco. Nenhum dos dois pergunta se todo `msgid` do
`.pot` existe em todo `.po` — e uma entrada que nunca foi mergeada nao esta
vazia, ela nao existe. Medido em 2026-09-01 com os dois verdes: **65 `msgid`**
viviam num `.pot` e em nenhum catalogo, e os 13 locales renderizavam tudo em
ingles (`help_bots` 29, `accounts` 9, `help_ui` 8, `dialogs` 6, `commands` 5,
`help` 3, `connect` 3, e mais cinco dominios com 1 cada).

Fechado no mesmo dia: os 65 estao traduzidos a mao e
`scripts/i18n_catalog_completeness_check.exs` entrou no
`make i18n.catalog.check`, que ja esta no `make ci`. A pergunta dele e
presenca, nao conteudo — se a entrada diz algo util e o que os outros dois
checam.

**Armadilha de medicao, cara:** a primeira contagem usou `pt_BR` como sonda e
achou 48. Nove `msgid` de `accounts` existiam em `pt_BR` e faltavam nos outros
doze locales, e tres de `connect` faltavam so no `en` — invisiveis para uma
sonda de um locale so. Conte contra **todos** os locales, que e o que o checker
faz.

## Fluxo

Depois de mudar strings traduziveis:

```sh
make i18n.gettext.extract
make i18n.gettext.merge DOMAINS=landing
make i18n.catalog.check
make i18n.gettext.check
```

`i18n.gettext.extract` segue o fluxo padrao do Gettext e atualiza apenas os
templates `.pot`. `i18n.gettext.merge` chama `mix gettext.merge` arquivo por
arquivo para os dominios selecionados, preservando traducoes e marcando fuzzy
quando o Gettext achar uma correspondencia aproximada. Use `APP=web` ou
`APP=domain` para limitar o app, e `LOCALES=pt_BR,es` para limitar locales.

Para traduzir as entradas novas e fuzzy de um dominio, use os targets: eles
escopam os paths, recusam um `DOMAINS` que nao casa nenhum catalogo e aplicam o
glossario depois da maquina:

```sh
make i18n.venv                                # uma vez: polib, Argos e um modelo por locale
make i18n.translate DOMAINS=landing APP=web
```

Para adicionar uma onda:

```sh
make i18n.locales.add WAVE=2
```

Para adicionar locales especificos:

```sh
make i18n.locales.add LOCALES=es,fr,de
```

Para catalogos JavaScript, rode `scripts/i18n_machine_translate_js.py` apenas
quando a mudanca realmente tocar os catalogos de browser em
`apps/retro_hex_chat_web/assets/js/lib/i18n_catalogs`.

`scripts/i18n_machine_translate_js.py`, `scripts/i18n_apply_translation_overrides.py`,
`scripts/i18n_repair_js_catalog_placeholders.py` e
`scripts/i18n_source_fallback_check.py` usam `scripts/i18n_js_catalogs.py` para
preservar esse layout splitado.

Os scripts protegem placeholders com sentinelas alfanumericas (`XPH0X`), nunca
com tags: os modelos tratam `<ph0></ph0>` como markup e o mutilam. A excecao e
`%{count}` em plurais, traduzido como numero ("1 game", "2 games", "5 games",
escolhidos pela propria regra `Plural-Forms` do locale) e devolvido a
placeholder depois — ver `scripts/i18n/numerals.py`.

Todo script grava catalogos por `catalogs.save_po`, que reescreve so as
entradas alteradas; `po.save()` do polib reflui msgstrs que ninguem tocou e o
`mix gettext.merge` nao desfaz.

Reparos em catalogos existentes:

- `make i18n.repair` — re-traduz entradas inutilizaveis.
- `make i18n.repair.plurals` — plurais curtos `%{count} <substantivo>` com o
  numero depois do substantivo ou com as formas "poucos"/"muitos" colapsadas;
  so aplica o resultado se ele remover um defeito.
- `--msgid "<texto>"` em `i18n_machine_translate_po.py` — re-traduz um msgid
  conhecido como ruim, pelo pipeline, em vez de editar o catalogo a mao.

Depois de qualquer passada, valide o mesmo conjunto de arquivos:

```sh
mix run --no-start scripts/i18n_placeholder_check.exs --fail-on-findings \
  apps/retro_hex_chat_web/priv/gettext/*/LC_MESSAGES/landing.po
make i18n.quality.check
make i18n.catalog.check
```

`make i18n.catalog.check` continua global de proposito: ele e a barreira final
contra qualquer pendencia em locale habilitado. Os comandos anteriores devem ser
escopados ao dominio/feature em trabalho.

`scripts/i18n_apply_translation_overrides.py` e a memoria manual para strings
que a traducao automatica costuma deixar em ingles ou traduzir mal por causa de
placeholders. Sempre que a auditoria de fallback acusar texto humano novo, a
correcao deve entrar ali ou diretamente no catalogo com uma regra equivalente.

Para refatoracoes grandes:

```sh
elixir scripts/i18n_domainize_gettext_calls.exs
elixir scripts/i18n_split_help_domains.exs
make i18n.gettext.rebuild CONFIRM_GLOBAL_REBUILD=1
```

`scripts/i18n_rehydrate_domain_translations.exs` reconstrui os `.po` a partir
dos `.pot` atuais e copia traducoes ja existentes por `msgid`. Isso evita
perder traducoes quando um texto muda apenas de dominio, mas deve ser reservado
para refatoracoes amplas porque reescreve catalogos inteiros.
