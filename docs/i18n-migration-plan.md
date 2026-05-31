# Plano de internacionalizacao

Este projeto ja tem `gettext` instalado em `apps/retro_hex_chat_web/mix.exs`,
um backend em `RetroHexChatWeb.Gettext` e catalogo inicial em
`apps/retro_hex_chat_web/priv/gettext`. Hoje, porem, quase toda a superficie
visivel ainda esta em literais de ingles em HEEx, Elixir e JavaScript.

## Referencias oficiais usadas

- Phoenix LiveView: e necessario chamar `Gettext.put_locale/2` no `mount/3` ou
  em um `on_mount` comum para escolher o locale usado na renderizacao.
  https://hexdocs.pm/phoenix_live_view/gettext.html
- Gettext: trocar texto hardcoded por `gettext("...")`; o proprio texto em
  ingles vira `msgid`; usar `ngettext` para plurais e interpolacao `%{name}`.
  https://hexdocs.pm/gettext/Gettext.html
- Gettext extract/check: `mix gettext.extract --merge` atualiza POT/PO e
  `mix gettext.extract --check-up-to-date` valida catalogos no CI. Neste
  umbrella, rode esses comandos no app web ou use os alvos Makefile abaixo.
  https://hexdocs.pm/gettext/Mix.Tasks.Gettext.Extract.html
- Gettext merge: `mix gettext.merge priv/gettext --locale <locale>` sincroniza
  novos POTs com os POs de cada idioma, marcando fuzzy quando precisa revisao.
  https://hexdocs.pm/gettext/Mix.Tasks.Gettext.Merge.html
- Phoenix routes: apps que usam i18n podem prefixar rotas por locale via
  `path_prefixes`, se a decisao de produto for locale na URL.
  https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html
- GNU gettext: `xgettext` tambem tem suporte a JavaScript, mas no Phoenix deste
  repo a trilha principal deve continuar sendo catalogos PO via Gettext.
  https://www.gnu.org/software/gettext/manual/html_node/JavaScript.html

## Decisoes propostas

1. Manter Gettext como sistema canonico de traducao.
2. Usar ingles como idioma fonte e fallback.
3. Preferir `gettext`, `ngettext`, `pgettext` e `dgettext` com strings
   literais, porque isso preserva a extracao automatica.
4. Usar interpolacao Gettext, por exemplo
   `gettext("Hello, %{name}", name: name)`, em vez de interpolar com
   `"Hello, #{name}"`.
5. Adicionar `use Gettext, backend: RetroHexChatWeb.Gettext` ao macro
   `RetroHexChatWeb.Component`, porque a maior parte dos componentes UI usa
   esse entrypoint e hoje nao recebe os macros de traducao.
6. Padronizar LiveViews para passarem por `RetroHexChatWeb, :live_view` ou
   adicionarem o mesmo hook de locale quando precisam usar `Phoenix.LiveView`
   diretamente.
7. Comecar com locale em sessao, com fallback por `Accept-Language`; adicionar
   prefixo de URL depois somente se SEO/links por idioma forem requisitos.
8. Separar dominios de catalogo por area funcional. O padrao atual esta em
   `docs/i18n-catalogs.md`; `default` deve ficar pequeno e ajuda longa deve ser
   quebrada em subdominios.
9. Para strings em JavaScript, escolher uma das duas trilhas por caso:
   renderizar textos traduzidos em `data-*`/attrs vindos do HEEx quando a string
   pertence a um hook DOM; ou carregar um pequeno dicionario `window.__RHC_I18N__`
   para modulos JS que precisam criar UI sem roundtrip.
10. Para mensagens geradas no app de dominio (`apps/retro_hex_chat`), evitar
    traduzir em processos sem locale. Opcoes: retornar codigos/params para o web
    traduzir, ou introduzir um backend Gettext compartilhado e passar locale
    explicitamente para comandos.

## Plano de execucao

### Fase 0 - Baseline auditavel

- Rodar `elixir scripts/i18n_audit.exs --format markdown --limit 0` e salvar o
  resultado como snapshot de migracao.
- Classificar achados por area: conexao/login, chat shell, dialogos, ajuda,
  p2p/jogos, comandos/backend e JavaScript.
- Criar allowlist somente para strings que comprovadamente nao sao UI:
  nomes de eventos, ids, comandos IRC, CSS, logs, protocolos e dados tecnicos.

### Fase 1 - Infra de locale

- Configurar locale default (`en`) e lista suportada.
- Criar plug para escolher locale por sessao, usuario ou `Accept-Language`.
- Criar `on_mount` para restaurar `Gettext.put_locale(RetroHexChatWeb.Gettext, locale)`
  em todas as LiveViews.
- Adicionar seletor de idioma discreto no shell/app ou tela de conexao.
- Garantir que mudanca de locale remonte LiveViews quando necessario.

### Fase 2 - Extracao HEEx/Elixir

- Adicionar Gettext ao `RetroHexChatWeb.Component`.
- Converter textos visiveis em HEEx: texto de botoes, labels, placeholders,
  `title`, `aria-label`, legendas, estados vazios, dialogos e toasts.
- Converter strings em codigo Elixir que aparecem para usuarios: flashes,
  mensagens de erro, labels de estado, respostas de sessao, textos de cards.
- Trocar plurais manuais por `ngettext`.
- Usar `pgettext` quando o mesmo termo tiver contexto ambiguo, por exemplo
  `File` substantivo versus acao.

### Fase 3 - Ajuda, comandos e backend

- Migrar `controllers/help_content/*.html.heex` para dominio `help`.
- Para comandos de chat, decidir se a traducao fica no web layer ou no app de
  dominio. Nao misturar as duas abordagens sem contrato claro.
- Criar testes para respostas de comandos que dependem de locale.

### Fase 4 - JavaScript

- Para hooks que so exibem textos em elementos ja renderizados, passar strings
  traduzidas por atributos `data-*`.
- Para modulos que criam DOM do zero (toast, menus, p2p/media), adicionar helper
  JS `t(key, fallback, params)` alimentado pelo layout.
- Manter fallback em ingles no JS para degradacao segura.
- Auditar jogos/canvas separadamente, porque parte dos textos pode estar em
  sprites, canvas ou nomes proprios.

### Fase 5 - Catalogos e CI

- Rodar `make i18n.gettext.rebuild` depois de cada lote.
- Criar POs para os idiomas alvo com
  `cd apps/retro_hex_chat_web && mix gettext.merge priv/gettext --locale <locale>`.
- Adicionar ao CI:
  - `make i18n.gettext.check`
  - `make i18n.catalog.check`
  - `elixir scripts/i18n_audit.exs --fail-on-findings`
- Bloquear merge quando houver novos literais traduziveis fora de Gettext ou
  catalogos desatualizados.

## Criterio de conclusao

A atividade pode ser considerada pronta quando:

- `elixir scripts/i18n_audit.exs --fail-on-findings` retorna zero achados high
  e medium fora da allowlist revisada.
- `make i18n.gettext.check` passa.
- `make i18n.catalog.check` passa, garantindo `pt_BR` sem vazio/fuzzy e cada
  `.po` dentro do limite de legibilidade.
- Cada idioma alvo tem `default.po`, `errors.po` e os dominios adicionais usados
  sem `msgstr ""` obrigatorio e sem `fuzzy` pendente.
- Fluxos principais foram validados em pelo menos dois locales: conexao,
  entrada no chat, dialogos principais, busca, notificacoes/toasts, p2p/jogos e
  ajuda.
- Strings tecnicas intencionalmente nao traduzidas estao documentadas na
  allowlist com justificativa.
