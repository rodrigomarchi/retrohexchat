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

Para traduzir ou reparar um diff especifico, passe sempre paths explicitos aos
scripts de traducao/reparo. Exemplo:

```sh
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_machine_translate_po.py \
  --locales pt_BR,es,fr \
  apps/retro_hex_chat_web/priv/gettext/*/LC_MESSAGES/landing.po
```

Evite rodar scripts de traducao ou reparo sem paths quando a intencao for
atualizar apenas uma feature ou dominio.

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
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_machine_translate_po.py \
  --locales es,fr,de \
  apps/retro_hex_chat_web/priv/gettext/*/LC_MESSAGES/landing.po
```

Para catalogos JavaScript, rode `scripts/i18n_machine_translate_js.py` apenas
quando a mudanca realmente tocar os catalogos de browser em
`apps/retro_hex_chat_web/assets/js/lib/i18n_catalogs`.

`scripts/i18n_machine_translate_js.py`, `scripts/i18n_apply_translation_overrides.py`,
`scripts/i18n_repair_js_catalog_placeholders.py` e
`scripts/i18n_source_fallback_check.py` usam `scripts/i18n_js_catalogs.py` para
preservar esse layout splitado.

Para lotes grandes, prefira `ARGOS_CHUNK_TYPE=MINISBD` para evitar download de
modelos extras em tempo de execucao. Os scripts protegem placeholders com tags
pareadas, por exemplo `<ph0></ph0>`, porque esse formato e preservado melhor
pelos modelos Argos do que sentinelas soltas.

Para reparos grandes em catalogos existentes, evite uma unica chamada global de
traducao. Ela demora mais, mistura problemas de varios idiomas e pode reutilizar
cache com traducoes que perderam placeholders. Prefira lotes por locale e por
familia de arquivos, validando cada lote antes de seguir:

```sh
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_repair_placeholder_mismatches.py apps/retro_hex_chat_web/priv/gettext/tr/LC_MESSAGES/*.po
rm -f /tmp/retro_hex_chat_i18n_fragment_cache.json
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_machine_translate_po.py \
  --cache /tmp/retro_hex_chat_i18n_fragment_cache.json \
  --locales tr \
  --protected-mode fragment \
  apps/retro_hex_chat_web/priv/gettext/tr/LC_MESSAGES/chat.po \
  apps/retro_hex_chat_web/priv/gettext/tr/LC_MESSAGES/dialogs.po \
  apps/retro_hex_chat_web/priv/gettext/tr/LC_MESSAGES/group_call.po \
  apps/retro_hex_chat_web/priv/gettext/tr/LC_MESSAGES/lobby.po \
  apps/retro_hex_chat_web/priv/gettext/tr/LC_MESSAGES/p2p.po \
  apps/retro_hex_chat_web/priv/gettext/tr/LC_MESSAGES/ui.po
mix run --no-start scripts/i18n_placeholder_check.exs --fail-on-findings apps/retro_hex_chat_web/priv/gettext/tr/LC_MESSAGES/*.po
python3 scripts/i18n_source_fallback_check.py --locales tr --fail-on-findings
```

Quando `zh_hant` entra no lote, instale tambem o conversor OpenCC no ambiente
temporario:

```sh
/tmp/retro_hex_chat_i18n_venv/bin/python -m pip install opencc-python-reimplemented
```

Ordem recomendada para reparo:

1. Rode `i18n_repair_placeholder_mismatches.py` para voltar entradas inseguras
   ao `msgid` fonte.
2. Traduza um locale por vez com `--protected-mode fragment` e cache dedicado.
3. Rode `i18n_placeholder_check.exs` antes de olhar fallback. Fallback em ingles
   e menos grave que uma traducao sem placeholder.
4. Rode `i18n_source_fallback_check.py --locales <locale>` e resolva sobras com
   `scripts/i18n_apply_translation_overrides.py` ou allowlist tecnica explicita.
5. So depois rode `make i18n.catalog.check` e `make i18n.gettext.check`.

Depois da traducao automatica de um dominio especifico, valide o mesmo conjunto
de arquivos que foi traduzido:

```sh
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_repair_placeholder_mismatches.py \
  apps/retro_hex_chat_web/priv/gettext/*/LC_MESSAGES/landing.po
/tmp/retro_hex_chat_i18n_venv/bin/python scripts/i18n_apply_translation_overrides.py \
  --locales pt_BR,es,fr,de,ja,zh_hans,id,ar,ru,hi,ko,tr,vi,bn,ur,zh_hant,pt_PT,it,pl,nl \
  apps/retro_hex_chat_web/priv/gettext/*/LC_MESSAGES/landing.po
mix run --no-start scripts/i18n_placeholder_check.exs --fail-on-findings \
  apps/retro_hex_chat_web/priv/gettext/*/LC_MESSAGES/landing.po
python3 scripts/i18n_source_fallback_check.py \
  --locales pt_BR,es,fr,de,ja,zh_hans,id,ar,ru,hi,ko,tr,vi,bn,ur,zh_hant,pt_PT,it,pl,nl \
  --fail-on-findings \
  apps/retro_hex_chat_web/priv/gettext/*/LC_MESSAGES/landing.po
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
